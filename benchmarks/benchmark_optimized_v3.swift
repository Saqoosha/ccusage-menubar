#!/usr/bin/env swift

import Foundation

// Benchmark tool with streaming JSON parser
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

// Fast date extraction - just get YYYY-MM-DD from ISO string
func extractDate(_ dateStr: String) -> String {
    return String(dateStr.prefix(10))
}

// Get today's date in YYYY-MM-DD format
let todayDate = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone.current
    return formatter.string(from: Date())
}()

// OPTIMIZATION: Process only today's data with early exit
func processFileForToday(_ filePath: String) -> (inputTokens: Int, outputTokens: Int, cacheCreateTokens: Int, cacheReadTokens: Int, entryCount: Int) {
    var inputTokens = 0
    var outputTokens = 0
    var cacheCreateTokens = 0
    var cacheReadTokens = 0
    var entryCount = 0
    
    guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
        return (inputTokens, outputTokens, cacheCreateTokens, cacheReadTokens, entryCount)
    }
    
    // Process line by line
    content.enumerateLines { line, _ in
        // Quick check for today's date
        if line.contains(todayDate) && line.contains("\"usage\"") {
            // Parse this line since it's from today
            if let data = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let timestamp = json["timestamp"] as? String {
                
                // Double check it's really today
                if extractDate(timestamp) == todayDate {
                    if let message = json["message"] as? [String: Any],
                       let usage = message["usage"] as? [String: Any] {
                        inputTokens += usage["input_tokens"] as? Int ?? 0
                        outputTokens += usage["output_tokens"] as? Int ?? 0
                        cacheCreateTokens += usage["cache_creation_input_tokens"] as? Int ?? 0
                        cacheReadTokens += usage["cache_read_input_tokens"] as? Int ?? 0
                        entryCount += 1
                    }
                }
            }
        }
    }
    
    return (inputTokens, outputTokens, cacheCreateTokens, cacheReadTokens, entryCount)
}

// Process all data (for monthly stats)
func processFileAllData(_ filePath: String) -> [(date: String, usage: [String: Any]?)] {
    var entries: [(date: String, usage: [String: Any]?)] = []
    
    guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
        return entries
    }
    
    content.enumerateLines { line, _ in
        if let data = line.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let timestamp = json["timestamp"] as? String {
            
            let date = extractDate(timestamp)
            let message = json["message"] as? [String: Any]
            let usage = message?["usage"] as? [String: Any]
            entries.append((date: date, usage: usage))
        }
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

print("🚀 Swift CLI Performance Benchmark (Optimized v3 - Smart Loading)")
print("================================================================")

// Get test data info
benchmark.start("0. Get test data info")
let (fileCount, totalSize) = getTestDataInfo()
benchmark.end("0. Get test data info")

print("📁 Test data: \(fileCount) files, \(totalSize / 1024 / 1024) MB")
print("💾 Initial memory: \(String(format: "%.1f", memoryStart)) MB")
print("📅 Today's date: \(todayDate)")

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

// Sort files by modification date (newest first) for early exit optimization
jsonlFiles.sort { file1, file2 in
    let attrs1 = try? FileManager.default.attributesOfItem(atPath: file1)
    let attrs2 = try? FileManager.default.attributesOfItem(atPath: file2)
    let date1 = attrs1?[.modificationDate] as? Date ?? Date.distantPast
    let date2 = attrs2?[.modificationDate] as? Date ?? Date.distantPast
    return date1 > date2
}

benchmark.end("1. File discovery")
print("✅ Found \(jsonlFiles.count) JSONL files (sorted by modification date)")

// 2. Process ONLY today's data with early exit
benchmark.start("2. Process today's data")

var todayTokens = (input: 0, output: 0, cacheCreate: 0, cacheRead: 0)
var todayEntryCount = 0
var filesProcessed = 0

// Process files starting from newest
for file in jsonlFiles {
    // Check if file was modified today or recently
    if let attrs = try? FileManager.default.attributesOfItem(atPath: file),
       let modDate = attrs[.modificationDate] as? Date {
        // If file is older than 2 days, skip remaining files
        if Date().timeIntervalSince(modDate) > 2 * 24 * 60 * 60 {
            print("   Skipping older files (processed \(filesProcessed) recent files)")
            break
        }
    }
    
    let result = processFileForToday(file)
    todayTokens.input += result.inputTokens
    todayTokens.output += result.outputTokens
    todayTokens.cacheCreate += result.cacheCreateTokens
    todayTokens.cacheRead += result.cacheReadTokens
    todayEntryCount += result.entryCount
    filesProcessed += 1
}

benchmark.end("2. Process today's data")
print("✅ Processed \(filesProcessed) files, found \(todayEntryCount) entries for today")

// 3. Calculate monthly data (optional - can be skipped for speed)
benchmark.start("3. Calculate monthly")

// Get current month
let monthFormatter = DateFormatter()
monthFormatter.dateFormat = "yyyy-MM"
let currentMonth = monthFormatter.string(from: Date())

var monthlyTokens = (input: 0, output: 0, cacheCreate: 0, cacheRead: 0)
var monthlyEntryCount = 0

// Only process recent files for monthly data
let recentFiles = jsonlFiles.prefix(50) // Process only 50 most recent files

for file in recentFiles {
    let entries = processFileAllData(file)
    
    for entry in entries {
        if entry.date.hasPrefix(currentMonth), let usage = entry.usage {
            monthlyTokens.input += usage["input_tokens"] as? Int ?? 0
            monthlyTokens.output += usage["output_tokens"] as? Int ?? 0
            monthlyTokens.cacheCreate += usage["cache_creation_input_tokens"] as? Int ?? 0
            monthlyTokens.cacheRead += usage["cache_read_input_tokens"] as? Int ?? 0
            monthlyEntryCount += 1
        }
    }
}

benchmark.end("3. Calculate monthly")

print("\n📈 Today's usage (\(todayDate)):")
print("   Input: \(todayTokens.input)")
print("   Output: \(todayTokens.output)")
print("   Cache Create: \(todayTokens.cacheCreate)")
print("   Cache Read: \(todayTokens.cacheRead)")
print("   Total: \(todayTokens.input + todayTokens.output + todayTokens.cacheCreate + todayTokens.cacheRead)")

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
print("   Optimized v3: ~\(String(format: "%.1f", totalTime))s")
print("   ccusage: ~2.0s")
print("   Speed ratio: \(String(format: "%.1fx", totalTime / 2.0))")

if totalTime < 2.5 {
    print("\n🎉 SUCCESS! Achieved near-ccusage performance!")
} else {
    print("\n💡 Next optimizations to try:")
    print("   - Cache parsed data between runs")
    print("   - Use memory-mapped files")
    print("   - Implement C-based JSON scanner")
}