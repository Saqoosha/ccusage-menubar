#!/usr/bin/env swift

import Foundation

// Ultra-fast benchmark with multiple optimization strategies
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

// STRATEGY 1: Ultra-lightweight regex-based parser
func parseWithRegex(_ content: String, targetDate: String) -> (Int, Int, Int, Int, Int) {
    var inputTokens = 0
    var outputTokens = 0
    var cacheCreateTokens = 0
    var cacheReadTokens = 0
    var count = 0
    
    // Pre-filter lines containing target date
    let lines = content.split(separator: "\n").filter { $0.contains(targetDate) }
    
    // Pre-compile regex patterns
    let inputRegex = try? NSRegularExpression(pattern: "\"input_tokens\":(\\d+)")
    let outputRegex = try? NSRegularExpression(pattern: "\"output_tokens\":(\\d+)")
    let cacheCreateRegex = try? NSRegularExpression(pattern: "\"cache_creation_input_tokens\":(\\d+)")
    let cacheReadRegex = try? NSRegularExpression(pattern: "\"cache_read_input_tokens\":(\\d+)")
    
    for line in lines {
        let lineStr = String(line)
        let range = NSRange(lineStr.startIndex..., in: lineStr)
        var hasUsage = false
        
        if let match = inputRegex?.firstMatch(in: lineStr, range: range),
           let valueRange = Range(match.range(at: 1), in: lineStr),
           let value = Int(lineStr[valueRange]) {
            inputTokens += value
            hasUsage = true
        }
        
        if let match = outputRegex?.firstMatch(in: lineStr, range: range),
           let valueRange = Range(match.range(at: 1), in: lineStr),
           let value = Int(lineStr[valueRange]) {
            outputTokens += value
            hasUsage = true
        }
        
        if let match = cacheCreateRegex?.firstMatch(in: lineStr, range: range),
           let valueRange = Range(match.range(at: 1), in: lineStr),
           let value = Int(lineStr[valueRange]) {
            cacheCreateTokens += value
            hasUsage = true
        }
        
        if let match = cacheReadRegex?.firstMatch(in: lineStr, range: range),
           let valueRange = Range(match.range(at: 1), in: lineStr),
           let value = Int(lineStr[valueRange]) {
            cacheReadTokens += value
            hasUsage = true
        }
        
        if hasUsage { count += 1 }
    }
    
    return (inputTokens, outputTokens, cacheCreateTokens, cacheReadTokens, count)
}

// STRATEGY 2: Memory-mapped file reading
func processWithMemoryMap(_ filePath: String, targetDate: String) -> (Int, Int, Int, Int, Int) {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath), options: .mappedIfSafe),
          let content = String(data: data, encoding: .utf8) else {
        return (0, 0, 0, 0, 0)
    }
    
    return parseWithRegex(content, targetDate: targetDate)
}

// STRATEGY 3: Parallel chunk processing with Dispatch
func processInParallelChunks(_ files: [String], targetDate: String) -> (Int, Int, Int, Int, Int) {
    let queue = DispatchQueue.global(qos: .userInitiated)
    let group = DispatchGroup()
    
    var totalTokens = (input: 0, output: 0, cacheCreate: 0, cacheRead: 0, count: 0)
    let lock = NSLock()
    
    // Process files in parallel chunks
    let chunkSize = max(1, files.count / ProcessInfo.processInfo.activeProcessorCount)
    
    for chunk in files.chunked(into: chunkSize) {
        group.enter()
        queue.async {
            var chunkTokens = (input: 0, output: 0, cacheCreate: 0, cacheRead: 0, count: 0)
            
            for file in chunk {
                let result = processWithMemoryMap(file, targetDate: targetDate)
                chunkTokens.input += result.0
                chunkTokens.output += result.1
                chunkTokens.cacheCreate += result.2
                chunkTokens.cacheRead += result.3
                chunkTokens.count += result.4
            }
            
            lock.lock()
            totalTokens.input += chunkTokens.input
            totalTokens.output += chunkTokens.output
            totalTokens.cacheCreate += chunkTokens.cacheCreate
            totalTokens.cacheRead += chunkTokens.cacheRead
            totalTokens.count += chunkTokens.count
            lock.unlock()
            
            group.leave()
        }
    }
    
    group.wait()
    return totalTokens
}

// STRATEGY 4: Index-based approach (create index on first run)
struct FileIndex: Codable {
    let filePath: String
    let dates: Set<String>
    let modificationDate: Date
}

class IndexManager {
    static let indexPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude_usage_index.json")
    
    static func loadIndex() -> [FileIndex]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: indexPath.path)),
              let index = try? JSONDecoder().decode([FileIndex].self, from: data) else {
            return nil
        }
        return index
    }
    
    static func saveIndex(_ index: [FileIndex]) {
        if let data = try? JSONEncoder().encode(index) {
            try? data.write(to: URL(fileURLWithPath: indexPath.path))
        }
    }
    
    static func buildIndex(for files: [String]) -> [FileIndex] {
        var index: [FileIndex] = []
        
        for file in files {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: file),
               let modDate = attrs[.modificationDate] as? Date,
               let content = try? String(contentsOfFile: file, encoding: .utf8) {
                
                // Extract all dates in this file
                var dates = Set<String>()
                content.enumerateLines { line, _ in
                    if let range = line.range(of: "\"timestamp\":\"") {
                        let dateStart = line.index(range.upperBound, offsetBy: 0)
                        let dateEnd = line.index(dateStart, offsetBy: 10)
                        if dateEnd <= line.endIndex {
                            dates.insert(String(line[dateStart..<dateEnd]))
                        }
                    }
                }
                
                index.append(FileIndex(filePath: file, dates: dates, modificationDate: modDate))
            }
        }
        
        return index
    }
}

// Array chunking extension
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
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

// Get today's date
let todayDate = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone.current
    return formatter.string(from: Date())
}()

// Run benchmark
let benchmark = PerformanceBenchmark()
let memoryStart = getMemoryUsage()

print("🚀 Swift CLI Ultra-Fast Benchmark")
print("==================================")
print("📅 Today's date: \(todayDate)")
print("💾 Initial memory: \(String(format: "%.1f", memoryStart)) MB")
print("🖥️  CPU cores: \(ProcessInfo.processInfo.activeProcessorCount)")

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

// 2. Try index-based approach first
benchmark.start("2. Index check/build")
var filesToProcess = jsonlFiles

if let existingIndex = IndexManager.loadIndex() {
    print("   Found existing index")
    // Filter files that contain today's date
    filesToProcess = existingIndex
        .filter { $0.dates.contains(todayDate) }
        .map { $0.filePath }
    print("   Files with today's data: \(filesToProcess.count)")
} else {
    print("   Building index (one-time cost)...")
    let index = IndexManager.buildIndex(for: jsonlFiles)
    IndexManager.saveIndex(index)
    filesToProcess = index
        .filter { $0.dates.contains(todayDate) }
        .map { $0.filePath }
}
benchmark.end("2. Index check/build")

// 3. Process files in parallel with regex
benchmark.start("3. Parallel regex parse")
let result = processInParallelChunks(filesToProcess, targetDate: todayDate)
benchmark.end("3. Parallel regex parse")

print("\n📈 Today's usage (\(todayDate)):")
print("   Input: \(result.0)")
print("   Output: \(result.1)")
print("   Cache Create: \(result.2)")
print("   Cache Read: \(result.3)")
print("   Total: \(result.0 + result.1 + result.2 + result.3)")
print("   Entries: \(result.4)")

// Memory usage
let memoryEnd = getMemoryUsage()
print("\n💾 Memory usage:")
print("   Peak: \(String(format: "%.1f", memoryEnd)) MB")
print("   Increase: \(String(format: "%.1f", memoryEnd - memoryStart)) MB")

// Print report
let totalTime = benchmark.printReport()

// Comparison
print("\n🏁 Speed comparison:")
print("   Ultra-fast v1: ~\(String(format: "%.1f", totalTime))s")
print("   Previous best: ~4.4s")
print("   ccusage: ~2.0s")

if totalTime < 2.0 {
    print("\n🎉 BREAKTHROUGH! Faster than ccusage on first run!")
} else {
    print("\n💡 Strategies used:")
    print("   - File index to skip irrelevant files")
    print("   - Memory-mapped file reading")
    print("   - Parallel processing with \(ProcessInfo.processInfo.activeProcessorCount) cores")
    print("   - Regex-based parsing (no JSON overhead)")
}