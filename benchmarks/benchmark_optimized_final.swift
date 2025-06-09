#!/usr/bin/env swift

import Foundation

// Benchmark tool with caching for production-ready performance
class PerformanceBenchmark {
    private var startTimes: [String: Date] = [:]
    private var measurements: [String: TimeInterval] = [:]
    
    func start(_ label: String) {
        startTimes[label] = Date()
    }
    
    func end(_ label: String) {
        guard let startTime = startTimes[label] else { return }
        let duration = Date().timeIntervalSince(startTime)
        measurements[label] = duration
        startTimes.removeValue(forKey: label)
    }
    
    func printReport() -> TimeInterval {
        print("\n📊 Performance Benchmark Report")
        print(String(repeating: "=", count: 50))
        
        var total: TimeInterval = 0
        for (label, duration) in measurements.sorted(by: { $0.key < $1.key }) {
            let labelPadded = label.padding(toLength: 25, withPad: " ", startingAt: 0)
            print("\(labelPadded): \(String(format: "%7.3f", duration))s")
            total += duration
        }
        
        print(String(repeating: "-", count: 50))
        let totalLabel = "TOTAL".padding(toLength: 25, withPad: " ", startingAt: 0)
        print("\(totalLabel): \(String(format: "%7.3f", total))s")
        print(String(repeating: "=", count: 50))
        
        return total
    }
}

// Cache structure
struct CachedFileData: Codable {
    let modificationDate: Date
    let entries: [CachedEntry]
}

struct CachedEntry: Codable {
    let date: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreateTokens: Int
    let cacheReadTokens: Int
}

// Cache manager
class CacheManager {
    private let cacheDir: URL
    
    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        cacheDir = homeDir.appendingPathComponent(".claude_usage_cache")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
    
    func cacheKey(for filePath: String) -> String {
        return filePath.replacingOccurrences(of: "/", with: "_")
    }
    
    func getCachedData(for filePath: String) -> CachedFileData? {
        let key = cacheKey(for: filePath)
        let cacheFile = cacheDir.appendingPathComponent(key)
        
        guard let data = try? Data(contentsOf: cacheFile),
              let cached = try? JSONDecoder().decode(CachedFileData.self, from: data) else {
            return nil
        }
        
        // Check if file has been modified
        if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
           let modDate = attrs[.modificationDate] as? Date,
           modDate == cached.modificationDate {
            return cached
        }
        
        return nil
    }
    
    func setCachedData(_ data: CachedFileData, for filePath: String) {
        let key = cacheKey(for: filePath)
        let cacheFile = cacheDir.appendingPathComponent(key)
        
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: cacheFile)
        }
    }
}

// Fast date extraction
func extractDate(_ dateStr: String) -> String {
    return String(dateStr.prefix(10))
}

// Get today's date
let todayDate = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone.current
    return formatter.string(from: Date())
}()

// Get current month
let currentMonth = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM"
    formatter.timeZone = TimeZone.current
    return formatter.string(from: Date())
}()

// Process file with caching
func processFileWithCache(_ filePath: String, cacheManager: CacheManager) -> [CachedEntry] {
    // Check cache first
    if let cached = cacheManager.getCachedData(for: filePath) {
        return cached.entries
    }
    
    // Parse file if not cached
    var entries: [CachedEntry] = []
    
    guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
        return entries
    }
    
    content.enumerateLines { line, _ in
        if let data = line.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let timestamp = json["timestamp"] as? String {
            
            let date = extractDate(timestamp)
            var inputTokens = 0
            var outputTokens = 0
            var cacheCreateTokens = 0
            var cacheReadTokens = 0
            
            if let message = json["message"] as? [String: Any],
               let usage = message["usage"] as? [String: Any] {
                inputTokens = usage["input_tokens"] as? Int ?? 0
                outputTokens = usage["output_tokens"] as? Int ?? 0
                cacheCreateTokens = usage["cache_creation_input_tokens"] as? Int ?? 0
                cacheReadTokens = usage["cache_read_input_tokens"] as? Int ?? 0
            }
            
            entries.append(CachedEntry(
                date: date,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheCreateTokens: cacheCreateTokens,
                cacheReadTokens: cacheReadTokens
            ))
        }
    }
    
    // Cache the parsed data
    if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
       let modDate = attrs[.modificationDate] as? Date {
        let cachedData = CachedFileData(modificationDate: modDate, entries: entries)
        cacheManager.setCachedData(cachedData, for: filePath)
    }
    
    return entries
}

// Memory tracking
func getMemoryUsage() -> Double {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_,
                     task_flavor_t(MACH_TASK_BASIC_INFO),
                     $0,
                     &count)
        }
    }
    
    return result == KERN_SUCCESS ? Double(info.resident_size) / 1024.0 / 1024.0 : 0
}

// Test data info
func getTestDataInfo() -> (fileCount: Int, totalSize: Int64) {
    let claudePath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects")
        .path
    
    var fileCount = 0
    var totalSize: Int64 = 0
    
    if let enumerator = FileManager.default.enumerator(atPath: claudePath) {
        while let file = enumerator.nextObject() as? String {
            if file.hasSuffix(".jsonl") {
                fileCount += 1
                let fullPath = "\(claudePath)/\(file)"
                if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                   let size = attrs[.size] as? Int64 {
                    totalSize += size
                }
            }
        }
    }
    
    return (fileCount, totalSize)
}

// Run benchmark
let benchmark = PerformanceBenchmark()
let memoryStart = getMemoryUsage()
let cacheManager = CacheManager()

print("🚀 Swift CLI Performance Benchmark (Final - With Caching)")
print("=========================================================")

// Get test data info
benchmark.start("0. Get test data info")
let (fileCount, totalSize) = getTestDataInfo()
benchmark.end("0. Get test data info")

print("📁 Test data: \(fileCount) files, \(totalSize / 1024 / 1024) MB")
print("💾 Initial memory: \(String(format: "%.1f", memoryStart)) MB")
print("📅 Today's date: \(todayDate)")
print("💽 Cache enabled: YES")

// 1. File discovery
benchmark.start("1. File discovery")
let claudePath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".claude/projects")
    .path

var jsonlFiles: [String] = []
if let enumerator = FileManager.default.enumerator(atPath: claudePath) {
    while let file = enumerator.nextObject() as? String {
        if file.hasSuffix(".jsonl") {
            jsonlFiles.append("\(claudePath)/\(file)")
        }
    }
}

// Sort by modification date
jsonlFiles.sort { file1, file2 in
    let attrs1 = try? FileManager.default.attributesOfItem(atPath: file1)
    let attrs2 = try? FileManager.default.attributesOfItem(atPath: file2)
    let date1 = attrs1?[.modificationDate] as? Date ?? Date.distantPast
    let date2 = attrs2?[.modificationDate] as? Date ?? Date.distantPast
    return date1 > date2
}

benchmark.end("1. File discovery")
print("✅ Found \(jsonlFiles.count) JSONL files")

// 2. Process files with cache
benchmark.start("2. Process with cache")

var todayTokens = (input: 0, output: 0, cacheCreate: 0, cacheRead: 0)
var monthlyTokens = (input: 0, output: 0, cacheCreate: 0, cacheRead: 0)
var todayEntryCount = 0
var monthlyEntryCount = 0
var filesProcessed = 0
var cacheHits = 0

// Process only recent files (last 60 days)
let cutoffDate = Date().addingTimeInterval(-60 * 24 * 60 * 60)

for file in jsonlFiles {
    // Skip very old files
    if let attrs = try? FileManager.default.attributesOfItem(atPath: file),
       let modDate = attrs[.modificationDate] as? Date,
       modDate < cutoffDate {
        break
    }
    
    // Check if cached
    let wasCached = cacheManager.getCachedData(for: file) != nil
    if wasCached {
        cacheHits += 1
    }
    
    let entries = processFileWithCache(file, cacheManager: cacheManager)
    
    for entry in entries {
        // Today's data
        if entry.date == todayDate {
            todayTokens.input += entry.inputTokens
            todayTokens.output += entry.outputTokens
            todayTokens.cacheCreate += entry.cacheCreateTokens
            todayTokens.cacheRead += entry.cacheReadTokens
            todayEntryCount += 1
        }
        
        // Monthly data
        if entry.date.hasPrefix(currentMonth) {
            monthlyTokens.input += entry.inputTokens
            monthlyTokens.output += entry.outputTokens
            monthlyTokens.cacheCreate += entry.cacheCreateTokens
            monthlyTokens.cacheRead += entry.cacheReadTokens
            monthlyEntryCount += 1
        }
    }
    
    filesProcessed += 1
}

benchmark.end("2. Process with cache")
print("✅ Processed \(filesProcessed) files (\(cacheHits) from cache)")

print("\n📈 Today's usage (\(todayDate)):")
print("   Input: \(todayTokens.input)")
print("   Output: \(todayTokens.output)")
print("   Cache Create: \(todayTokens.cacheCreate)")
print("   Cache Read: \(todayTokens.cacheRead)")
print("   Total: \(todayTokens.input + todayTokens.output + todayTokens.cacheCreate + todayTokens.cacheRead)")
print("   Entries: \(todayEntryCount)")

print("\n📊 This month's usage (\(currentMonth)):")
print("   Input: \(monthlyTokens.input)")
print("   Output: \(monthlyTokens.output)")
print("   Cache Create: \(monthlyTokens.cacheCreate)")
print("   Cache Read: \(monthlyTokens.cacheRead)")
print("   Total: \(monthlyTokens.input + monthlyTokens.output + monthlyTokens.cacheCreate + monthlyTokens.cacheRead)")
print("   Entries: \(monthlyEntryCount)")

// Memory usage
let memoryEnd = getMemoryUsage()
print("\n💾 Memory usage:")
print("   Peak: \(String(format: "%.1f", memoryEnd)) MB")
print("   Increase: \(String(format: "%.1f", memoryEnd - memoryStart)) MB")

// Print report
let totalTime = benchmark.printReport()

// Comparison
print("\n🏁 Speed comparison:")
print("   Final version: ~\(String(format: "%.1f", totalTime))s")
print("   ccusage: ~2.0s")
print("   Speed ratio: \(String(format: "%.1fx", totalTime / 2.0))")
print("   Cache hit rate: \(String(format: "%.1f", Double(cacheHits) / Double(filesProcessed) * 100))%")

if totalTime < 2.5 {
    print("\n🎉 SUCCESS! Achieved near-ccusage performance!")
    print("✨ Ready to integrate into the main app!")
} else {
    print("\n⚡ Performance is good! Cache will improve on subsequent runs.")
}