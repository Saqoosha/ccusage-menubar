#!/usr/bin/env swift

import Foundation

// Benchmark tool with parallel processing optimization
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

// OPTIMIZATION 1: Faster date formatting (kept from v1)
func formatDateOptimized(_ dateStr: String) -> String {
    if dateStr.count >= 10 {
        return String(dateStr.prefix(10))
    }
    
    // Fallback for weird formats
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    guard let date = formatter.date(from: dateStr) else {
        return String(dateStr.prefix(10))
    }
    
    let calendar = Calendar.current
    let year = calendar.component(.year, from: date)
    let month = calendar.component(.month, from: date)
    let day = calendar.component(.day, from: date)
    
    return String(format: "%04d-%02d-%02d", year, month, day)
}

// OPTIMIZATION 2: Lightweight JSON parser for specific fields
struct UsageEntry {
    let date: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreateTokens: Int
    let cacheReadTokens: Int
}

func parseJSONLine(_ line: String) -> UsageEntry? {
    // Quick check if line likely has usage data
    if !line.contains("\"usage\"") {
        return nil
    }
    
    // Extract timestamp using string manipulation (faster than full JSON parse)
    guard let timestampStart = line.range(of: "\"timestamp\":\"")?.upperBound,
          let timestampEnd = line[timestampStart...].range(of: "\"")?.lowerBound else {
        return nil
    }
    let timestamp = String(line[timestampStart..<timestampEnd])
    let date = formatDateOptimized(timestamp)
    
    // Extract usage tokens using regex or string search
    func extractTokenValue(_ key: String) -> Int {
        if let keyRange = line.range(of: "\"\(key)\":"),
           let start = line[keyRange.upperBound...].firstIndex(where: { $0.isNumber || $0 == "-" }) {
            var end = start
            while end < line.endIndex && (line[end].isNumber || line[end] == "-") {
                end = line.index(after: end)
            }
            return Int(line[start..<end]) ?? 0
        }
        return 0
    }
    
    let inputTokens = extractTokenValue("input_tokens")
    let outputTokens = extractTokenValue("output_tokens")
    let cacheCreateTokens = extractTokenValue("cache_creation_input_tokens")
    let cacheReadTokens = extractTokenValue("cache_read_input_tokens")
    
    return UsageEntry(
        date: date,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        cacheCreateTokens: cacheCreateTokens,
        cacheReadTokens: cacheReadTokens
    )
}

// OPTIMIZATION 3: Process file in chunks
func processFileOptimized(_ filePath: String) async -> [UsageEntry] {
    var entries: [UsageEntry] = []
    
    guard let fileHandle = FileHandle(forReadingAtPath: filePath) else {
        return entries
    }
    
    defer { fileHandle.closeFile() }
    
    // Read file in chunks for better memory usage
    let chunkSize = 65536 // 64KB chunks
    var buffer = Data()
    
    while true {
        let chunk = autoreleasepool { () -> Data in
            return fileHandle.readData(ofLength: chunkSize)
        }
        
        if chunk.isEmpty {
            break
        }
        
        buffer.append(chunk)
        
        // Process complete lines
        if let string = String(data: buffer, encoding: .utf8) {
            let lines = string.split(separator: "\n", omittingEmptySubsequences: true)
            
            // Keep last incomplete line in buffer
            if !chunk.isEmpty && !string.hasSuffix("\n") && lines.count > 0 {
                let lastLine = lines.last!
                buffer = lastLine.data(using: .utf8) ?? Data()
                
                // Process all complete lines
                for i in 0..<(lines.count - 1) {
                    if let entry = parseJSONLine(String(lines[i])) {
                        entries.append(entry)
                    }
                }
            } else {
                buffer = Data()
                
                // Process all lines
                for line in lines {
                    if let entry = parseJSONLine(String(line)) {
                        entries.append(entry)
                    }
                }
            }
        }
    }
    
    // Process any remaining data
    if !buffer.isEmpty, let string = String(data: buffer, encoding: .utf8) {
        if let entry = parseJSONLine(string) {
            entries.append(entry)
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

print("🚀 Swift CLI Performance Benchmark (Optimized v2 - Parallel)")
print("===========================================================")

// Get test data info
benchmark.start("0. Get test data info")
let (fileCount, totalSize) = getTestDataInfo()
benchmark.end("0. Get test data info")

print("📁 Test data: \(fileCount) files, \(totalSize / 1024 / 1024) MB")
print("💾 Initial memory: \(String(format: "%.1f", memoryStart)) MB")

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
benchmark.end("1. File discovery")
print("✅ Found \(jsonlFiles.count) JSONL files")

// 2. Parse all files in PARALLEL with lightweight parser
benchmark.start("2. Parallel parse")

// Use async/await with TaskGroup for parallel processing
let allEntries = await withTaskGroup(of: [UsageEntry].self) { group in
    var results: [UsageEntry] = []
    
    // Process files in batches to avoid overwhelming the system
    let batchSize = 10
    for i in stride(from: 0, to: jsonlFiles.count, by: batchSize) {
        let batch = Array(jsonlFiles[i..<min(i + batchSize, jsonlFiles.count)])
        
        for file in batch {
            group.addTask {
                await processFileOptimized(file)
            }
        }
        
        // Collect results from this batch
        for await entries in group {
            results.append(contentsOf: entries)
        }
    }
    
    return results
}

benchmark.end("2. Parallel parse")
print("✅ Parsed \(allEntries.count) entries")

// 3. Group by date
benchmark.start("3. Group by date")
var groupedByDate: [String: [UsageEntry]] = [:]

for entry in allEntries {
    if groupedByDate[entry.date] == nil {
        groupedByDate[entry.date] = []
    }
    groupedByDate[entry.date]?.append(entry)
}
benchmark.end("3. Group by date")
print("✅ Grouped into \(groupedByDate.count) dates")

// 4. Calculate today's usage
benchmark.start("4. Calculate today's usage")
let targetDate = formatDateOptimized(Date().description)
var tokens = (input: 0, output: 0, cacheCreate: 0, cacheRead: 0)

if let todayEntries = groupedByDate[targetDate] {
    for entry in todayEntries {
        tokens.input += entry.inputTokens
        tokens.output += entry.outputTokens
        tokens.cacheCreate += entry.cacheCreateTokens
        tokens.cacheRead += entry.cacheReadTokens
    }
}
benchmark.end("4. Calculate today's usage")

print("\n📈 Today's usage (\(targetDate)):")
print("   Input: \(tokens.input)")
print("   Output: \(tokens.output)")
print("   Cache Create: \(tokens.cacheCreate)")
print("   Cache Read: \(tokens.cacheRead)")
print("   Total: \(tokens.input + tokens.output + tokens.cacheCreate + tokens.cacheRead)")

// Memory usage
let memoryEnd = getMemoryUsage()
print("\n💾 Memory usage:")
print("   Peak: \(String(format: "%.1f", memoryEnd)) MB")
print("   Increase: \(String(format: "%.1f", memoryEnd - memoryStart)) MB")

// Print report
let totalTime = benchmark.printReport()

// Comparison
print("\n🏁 Speed comparison:")
print("   Optimized v2: ~\(String(format: "%.1f", totalTime))s")
print("   Optimized v1: ~6.5s")
print("   Original: ~14.7s")
print("   ccusage: ~2.0s")

let improvementFromV1 = ((6.5 - totalTime) / 6.5) * 100
let improvementFromOriginal = ((14.7 - totalTime) / 14.7) * 100
print("   Improvement from v1: \(String(format: "%.1f", improvementFromV1))%")
print("   Total improvement: \(String(format: "%.1f", improvementFromOriginal))%")
print("   Still slower than ccusage: \(String(format: "%.1fx", totalTime / 2.0))")