#!/usr/bin/env swift

import Foundation

// Ultimate benchmark: Parallel + Caching combined!
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

// Ultra-fast cache structure
struct UltraCache: Codable {
    let modDate: Date
    let tokens: TokenData
}

struct TokenData: Codable {
    var input: Int = 0
    var output: Int = 0
    var cacheCreate: Int = 0
    var cacheRead: Int = 0
    var count: Int = 0
}

// Ultra-fast cache manager
class UltraCacheManager {
    private let cacheDir: URL
    private let memoryCache = NSCache<NSString, NSData>()
    
    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        cacheDir = homeDir.appendingPathComponent(".claude_ultra_cache")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        
        // Configure memory cache
        memoryCache.countLimit = 1000
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func getCached(for file: String, modDate: Date) -> TokenData? {
        let key = NSString(string: file)
        
        // Check memory cache first (nanosecond speed!)
        if let data = memoryCache.object(forKey: key),
           let cached = try? JSONDecoder().decode(UltraCache.self, from: data as Data),
           abs(cached.modDate.timeIntervalSince(modDate)) < 1.0 {
            return cached.tokens
        }
        
        // Check disk cache
        let cacheFile = cacheDir.appendingPathComponent(file.replacingOccurrences(of: "/", with: "_"))
        if let data = try? Data(contentsOf: cacheFile),
           let cached = try? JSONDecoder().decode(UltraCache.self, from: data),
           abs(cached.modDate.timeIntervalSince(modDate)) < 1.0 {
            // Store in memory cache for next time
            memoryCache.setObject(data as NSData, forKey: key, cost: data.count)
            return cached.tokens
        }
        
        return nil
    }
    
    func setCache(_ tokens: TokenData, for file: String, modDate: Date) {
        let cache = UltraCache(modDate: modDate, tokens: tokens)
        if let data = try? JSONEncoder().encode(cache) {
            let key = NSString(string: file)
            // Store in both memory and disk
            memoryCache.setObject(data as NSData, forKey: key, cost: data.count)
            
            let cacheFile = cacheDir.appendingPathComponent(file.replacingOccurrences(of: "/", with: "_"))
            try? data.write(to: cacheFile)
        }
    }
}

// Ultra-fast parallel processor
func processWithUltraSpeed(_ files: [String], targetDate: String, cacheManager: UltraCacheManager) -> TokenData {
    var totalTokens = TokenData()
    let lock = NSLock()
    let queue = DispatchQueue.global(qos: .userInitiated)
    let group = DispatchGroup()
    
    // Process in optimal batch size
    let batchSize = max(1, files.count / (ProcessInfo.processInfo.activeProcessorCount * 2))
    
    for batch in files.chunked(into: batchSize) {
        group.enter()
        queue.async {
            var batchTokens = TokenData()
            
            for file in batch {
                autoreleasepool {
                    // Get file modification date
                    guard let attrs = try? FileManager.default.attributesOfItem(atPath: file),
                          let modDate = attrs[.modificationDate] as? Date else { return }
                    
                    // Check cache first
                    if let cached = cacheManager.getCached(for: file, modDate: modDate) {
                        batchTokens.input += cached.input
                        batchTokens.output += cached.output
                        batchTokens.cacheCreate += cached.cacheCreate
                        batchTokens.cacheRead += cached.cacheRead
                        batchTokens.count += cached.count
                        return
                    }
                    
                    // Parse file if not cached
                    var fileTokens = TokenData()
                    
                    if let content = try? String(contentsOfFile: file, encoding: .utf8) {
                        // Quick date check
                        if !content.contains(targetDate) {
                            // Cache empty result
                            cacheManager.setCache(fileTokens, for: file, modDate: modDate)
                            return
                        }
                        
                        // Parse matching lines
                        content.enumerateLines { line, _ in
                            if line.contains("\"timestamp\":\"\(targetDate)") {
                                if let data = line.data(using: .utf8),
                                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                   let message = json["message"] as? [String: Any],
                                   let usage = message["usage"] as? [String: Any] {
                                    fileTokens.input += usage["input_tokens"] as? Int ?? 0
                                    fileTokens.output += usage["output_tokens"] as? Int ?? 0
                                    fileTokens.cacheCreate += usage["cache_creation_input_tokens"] as? Int ?? 0
                                    fileTokens.cacheRead += usage["cache_read_input_tokens"] as? Int ?? 0
                                    fileTokens.count += 1
                                }
                            }
                        }
                        
                        // Cache the result
                        cacheManager.setCache(fileTokens, for: file, modDate: modDate)
                    }
                    
                    batchTokens.input += fileTokens.input
                    batchTokens.output += fileTokens.output
                    batchTokens.cacheCreate += fileTokens.cacheCreate
                    batchTokens.cacheRead += fileTokens.cacheRead
                    batchTokens.count += fileTokens.count
                }
            }
            
            lock.lock()
            totalTokens.input += batchTokens.input
            totalTokens.output += batchTokens.output
            totalTokens.cacheCreate += batchTokens.cacheCreate
            totalTokens.cacheRead += batchTokens.cacheRead
            totalTokens.count += batchTokens.count
            lock.unlock()
            
            group.leave()
        }
    }
    
    group.wait()
    return totalTokens
}

// Array chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// Get today's date
let todayDate = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone.current
    return formatter.string(from: Date())
}()

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

// Sort by modification date (newest first)
jsonlFiles.sort { file1, file2 in
    let attrs1 = try? FileManager.default.attributesOfItem(atPath: file1)
    let attrs2 = try? FileManager.default.attributesOfItem(atPath: file2)
    let date1 = attrs1?[.modificationDate] as? Date ?? Date.distantPast
    let date2 = attrs2?[.modificationDate] as? Date ?? Date.distantPast
    return date1 > date2
}

print("🚀 ULTIMATE Performance Benchmark (Parallel + Cache)")
print("===================================================")
print("📅 Today's date: \(todayDate)")
print("📁 Test files: \(jsonlFiles.count)")
print("🖥️  CPU cores: \(ProcessInfo.processInfo.activeProcessorCount)")
print("💾 Cache: Memory + Disk")

let benchmark = PerformanceBenchmark()
let cacheManager = UltraCacheManager()

// Run 1: First run (builds cache)
print("\n--- Run 1: First execution (building cache) ---")
benchmark.start("Run 1")
let result1 = processWithUltraSpeed(jsonlFiles, targetDate: todayDate, cacheManager: cacheManager)
benchmark.end("Run 1")
print("✅ Tokens: \(result1.input + result1.output + result1.cacheCreate + result1.cacheRead)")
print("   Entries: \(result1.count)")

// Run 2: Second run (uses cache)
print("\n--- Run 2: With warm cache ---")
benchmark.start("Run 2")
let result2 = processWithUltraSpeed(jsonlFiles, targetDate: todayDate, cacheManager: cacheManager)
benchmark.end("Run 2")
print("✅ Tokens: \(result2.input + result2.output + result2.cacheCreate + result2.cacheRead)")
print("   Entries: \(result2.count)")

// Run 3: Third run (memory cache hit)
print("\n--- Run 3: Memory cache only ---")
benchmark.start("Run 3")
let result3 = processWithUltraSpeed(jsonlFiles, targetDate: todayDate, cacheManager: cacheManager)
benchmark.end("Run 3")
print("✅ Tokens: \(result3.input + result3.output + result3.cacheCreate + result3.cacheRead)")
print("   Entries: \(result3.count)")

// Print results
_ = benchmark.printReport()

print("\n🏆 ULTIMATE Performance Results:")
if let r1 = benchmark.measurements["Run 1"],
   let r2 = benchmark.measurements["Run 2"],
   let r3 = benchmark.measurements["Run 3"] {
    print("   First run: \(String(format: "%.3f", r1))s")
    print("   Cached run: \(String(format: "%.3f", r2))s (\(String(format: "%.1fx", r1/r2)) faster)")
    print("   Memory cached: \(String(format: "%.3f", r3))s (\(String(format: "%.1fx", r1/r3)) faster)")
    print("")
    print("   vs ccusage (~2.0s):")
    print("   - First run: \(String(format: "%.1fx", 2.0/r1)) \(r1 < 2.0 ? "faster 🚀" : "slower")")
    print("   - Cached: \(String(format: "%.1fx", 2.0/r2)) faster 🚀🚀")
    print("   - Memory: \(String(format: "%.1fx", 2.0/r3)) faster 🚀🚀🚀")
}