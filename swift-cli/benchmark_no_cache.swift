#!/usr/bin/env swift

import Foundation

// Benchmark without any caching - pure performance comparison
class PerformanceBenchmark {
    private var startTimes: [String: Date] = [:]
    var measurements: [String: TimeInterval] = [:]
    
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

// Get today's date
let todayDate = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone.current
    return formatter.string(from: Date())
}()

// METHOD 1: Original slow method with full JSON parsing
func method1_fullJSON(_ files: [String]) -> (Int, Int, Int, Int, Int) {
    var totalTokens = (input: 0, output: 0, cacheCreate: 0, cacheRead: 0, count: 0)
    
    for file in files {
        autoreleasepool {
            if let content = try? String(contentsOfFile: file, encoding: .utf8) {
                let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
                
                for line in lines {
                    if let data = line.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let timestamp = json["timestamp"] as? String {
                        
                        // Extract date and check if today
                        let date = String(timestamp.prefix(10))
                        if date == todayDate {
                            if let message = json["message"] as? [String: Any],
                               let usage = message["usage"] as? [String: Any] {
                                totalTokens.input += usage["input_tokens"] as? Int ?? 0
                                totalTokens.output += usage["output_tokens"] as? Int ?? 0
                                totalTokens.cacheCreate += usage["cache_creation_input_tokens"] as? Int ?? 0
                                totalTokens.cacheRead += usage["cache_read_input_tokens"] as? Int ?? 0
                                totalTokens.count += 1
                            }
                        }
                    }
                }
            }
        }
    }
    
    return totalTokens
}

// METHOD 2: String search optimization
func method2_stringSearch(_ files: [String]) -> (Int, Int, Int, Int, Int) {
    var totalTokens = (input: 0, output: 0, cacheCreate: 0, cacheRead: 0, count: 0)
    
    for file in files {
        autoreleasepool {
            if let content = try? String(contentsOfFile: file, encoding: .utf8) {
                // Quick check if file contains today's date
                if !content.contains(todayDate) { return }
                
                content.enumerateLines { line, _ in
                    // Quick date check first
                    if line.contains("\"timestamp\":\"" + todayDate) {
                        // Parse only if it's today's data
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let message = json["message"] as? [String: Any],
                           let usage = message["usage"] as? [String: Any] {
                            totalTokens.input += usage["input_tokens"] as? Int ?? 0
                            totalTokens.output += usage["output_tokens"] as? Int ?? 0
                            totalTokens.cacheCreate += usage["cache_creation_input_tokens"] as? Int ?? 0
                            totalTokens.cacheRead += usage["cache_read_input_tokens"] as? Int ?? 0
                            totalTokens.count += 1
                        }
                    }
                }
            }
        }
    }
    
    return totalTokens
}

// METHOD 3: Parallel processing
func method3_parallel(_ files: [String]) -> (Int, Int, Int, Int, Int) {
    var totalTokens = (input: 0, output: 0, cacheCreate: 0, cacheRead: 0, count: 0)
    let lock = NSLock()
    
    DispatchQueue.concurrentPerform(iterations: files.count) { index in
        let file = files[index]
        
        autoreleasepool {
            if let content = try? String(contentsOfFile: file, encoding: .utf8) {
                if !content.contains(todayDate) { return }
                
                var localTokens = (input: 0, output: 0, cacheCreate: 0, cacheRead: 0, count: 0)
                
                content.enumerateLines { line, _ in
                    if line.contains("\"timestamp\":\"" + todayDate) {
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let message = json["message"] as? [String: Any],
                           let usage = message["usage"] as? [String: Any] {
                            localTokens.input += usage["input_tokens"] as? Int ?? 0
                            localTokens.output += usage["output_tokens"] as? Int ?? 0
                            localTokens.cacheCreate += usage["cache_creation_input_tokens"] as? Int ?? 0
                            localTokens.cacheRead += usage["cache_read_input_tokens"] as? Int ?? 0
                            localTokens.count += 1
                        }
                    }
                }
                
                lock.lock()
                totalTokens.input += localTokens.input
                totalTokens.output += localTokens.output
                totalTokens.cacheCreate += localTokens.cacheCreate
                totalTokens.cacheRead += localTokens.cacheRead
                totalTokens.count += localTokens.count
                lock.unlock()
            }
        }
    }
    
    return totalTokens
}

// METHOD 4: String extraction (no JSON parsing)
func method4_stringExtraction(_ files: [String]) -> (Int, Int, Int, Int, Int) {
    var totalTokens = (input: 0, output: 0, cacheCreate: 0, cacheRead: 0, count: 0)
    let lock = NSLock()
    
    func extractValue(_ line: String, key: String) -> Int {
        if let keyRange = line.range(of: "\"\(key)\":"),
           let start = line.index(keyRange.upperBound, offsetBy: 0, limitedBy: line.endIndex) {
            var end = start
            while end < line.endIndex && line[end].isNumber {
                end = line.index(after: end)
            }
            return Int(line[start..<end]) ?? 0
        }
        return 0
    }
    
    DispatchQueue.concurrentPerform(iterations: files.count) { index in
        let file = files[index]
        
        autoreleasepool {
            if let content = try? String(contentsOfFile: file, encoding: .utf8) {
                if !content.contains(todayDate) { return }
                
                var localTokens = (input: 0, output: 0, cacheCreate: 0, cacheRead: 0, count: 0)
                
                content.enumerateLines { line, _ in
                    if line.contains("\"timestamp\":\"" + todayDate) && line.contains("\"usage\"") {
                        localTokens.input += extractValue(line, key: "input_tokens")
                        localTokens.output += extractValue(line, key: "output_tokens")
                        localTokens.cacheCreate += extractValue(line, key: "cache_creation_input_tokens")
                        localTokens.cacheRead += extractValue(line, key: "cache_read_input_tokens")
                        localTokens.count += 1
                    }
                }
                
                lock.lock()
                totalTokens.input += localTokens.input
                totalTokens.output += localTokens.output
                totalTokens.cacheCreate += localTokens.cacheCreate
                totalTokens.cacheRead += localTokens.cacheRead
                totalTokens.count += localTokens.count
                lock.unlock()
            }
        }
    }
    
    return totalTokens
}

// Get test files
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

print("🚀 Performance Comparison (NO CACHING)")
print("=====================================")
print("📅 Today's date: \(todayDate)")
print("📁 Test files: \(jsonlFiles.count)")
print("🖥️  CPU cores: \(ProcessInfo.processInfo.activeProcessorCount)")
print("")

// Run benchmarks
let benchmark = PerformanceBenchmark()

// Method 1: Original (baseline)
print("Testing Method 1: Full JSON parsing...")
benchmark.start("Method 1")
let result1 = method1_fullJSON(jsonlFiles)
benchmark.end("Method 1")
print("✅ Tokens: \(result1.0 + result1.1 + result1.2 + result1.3), Entries: \(result1.4)")

// Method 2: String search optimization
print("\nTesting Method 2: String search + JSON...")
benchmark.start("Method 2")
let result2 = method2_stringSearch(jsonlFiles)
benchmark.end("Method 2")
print("✅ Tokens: \(result2.0 + result2.1 + result2.2 + result2.3), Entries: \(result2.4)")

// Method 3: Parallel processing
print("\nTesting Method 3: Parallel + String search...")
benchmark.start("Method 3")
let result3 = method3_parallel(jsonlFiles)
benchmark.end("Method 3")
print("✅ Tokens: \(result3.0 + result3.1 + result3.2 + result3.3), Entries: \(result3.4)")

// Method 4: String extraction (no JSON)
print("\nTesting Method 4: Parallel + String extraction...")
benchmark.start("Method 4")
let result4 = method4_stringExtraction(jsonlFiles)
benchmark.end("Method 4")
print("✅ Tokens: \(result4.0 + result4.1 + result4.2 + result4.3), Entries: \(result4.4)")

// Print comparison
_ = benchmark.printReport()

print("\n🏆 Performance Summary (NO CACHING):")
if let m1 = benchmark.measurements["Method 1"],
   let m2 = benchmark.measurements["Method 2"],
   let m3 = benchmark.measurements["Method 3"],
   let m4 = benchmark.measurements["Method 4"] {
    print("   Method 1 (baseline): \(String(format: "%.2f", m1))s")
    print("   Method 2 improvement: \(String(format: "%.1fx", m1/m2)) faster")
    print("   Method 3 improvement: \(String(format: "%.1fx", m1/m3)) faster")
    print("   Method 4 improvement: \(String(format: "%.1fx", m1/m4)) faster")
    print("")
    let bestTime = min(m1, m2, m3, m4)
    print("   Best method: \(String(format: "%.2f", bestTime))s")
    print("   vs ccusage (~2.0s): \(String(format: "%.1fx", 2.0/bestTime)) \(bestTime < 2.0 ? "faster 🎉" : "slower")")
}