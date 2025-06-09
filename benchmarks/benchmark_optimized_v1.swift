#!/usr/bin/env swift

import Foundation

// Benchmark tool with optimizations
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

// OPTIMIZATION 1: Faster date formatting
// Instead of parsing full ISO8601 date, just extract YYYY-MM-DD from string
func formatDateOptimized(_ dateStr: String) -> String {
    // Most timestamps are like "2024-01-01T12:34:56.789Z"
    // We just need first 10 characters
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

print("🚀 Swift CLI Performance Benchmark (Optimized v1)")
print("=================================================")

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

// 2. Parse all files with optimized date extraction
benchmark.start("2. Parse + format dates")
var allEntries: [(date: String, usage: [String: Any]?)] = []
var parseErrors = 0

for (index, file) in jsonlFiles.enumerated() {
    if index % 1000 == 0 {
        print("   Processing file \(index)/\(jsonlFiles.count)...")
    }
    
    autoreleasepool {
        if let content = try? String(contentsOfFile: file, encoding: .utf8) {
            let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
            
            for line in lines {
                if let data = line.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let timestamp = json["timestamp"] as? String {
                    
                    // OPTIMIZATION: Format date immediately during parsing
                    let date = formatDateOptimized(timestamp)
                    let message = json["message"] as? [String: Any]
                    let usage = message?["usage"] as? [String: Any]
                    allEntries.append((date: date, usage: usage))
                } else {
                    parseErrors += 1
                }
            }
        }
    }
}
benchmark.end("2. Parse + format dates")
print("✅ Parsed \(allEntries.count) entries (\(parseErrors) errors)")

// 3. Group by date (no separate formatting step needed!)
benchmark.start("3. Group by date")
var groupedByDate: [String: [(date: String, usage: [String: Any]?)]] = [:]

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
        if let usage = entry.usage {
            tokens.input += usage["input_tokens"] as? Int ?? 0
            tokens.output += usage["output_tokens"] as? Int ?? 0
            tokens.cacheCreate += usage["cache_creation_input_tokens"] as? Int ?? 0
            tokens.cacheRead += usage["cache_read_input_tokens"] as? Int ?? 0
        }
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
print("   Optimized v1: ~\(String(format: "%.1f", totalTime))s")
print("   Original: ~14.7s")
print("   ccusage: ~2.0s")

let improvement = ((14.7 - totalTime) / 14.7) * 100
print("   Improvement: \(String(format: "%.1f", improvement))%")
print("   Still slower than ccusage: \(String(format: "%.1fx", totalTime / 2.0))")