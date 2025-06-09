import Foundation
import SwiftUI

@MainActor
class UsageManager: ObservableObject {
    @Published var todayInputTokens: Int = 0
    @Published var todayOutputTokens: Int = 0
    @Published var todayCost: Double? = nil
    
    @Published var monthInputTokens: Int = 0
    @Published var monthOutputTokens: Int = 0
    @Published var monthCost: Double? = nil
    
    @Published var lastUpdated: Date? = nil
    @Published var isLoading: Bool = false
    
    private var refreshTimer: Timer?
    private let claudeProjectsPath: String
    private let cacheManager = UltraCacheManager.shared
    
    init() {
        self.claudeProjectsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("projects")
            .path
        
        // Try to load cached values immediately for instant display
        loadCachedValues()
        
        // Set loading state for fresh data
        self.isLoading = true
        
        // Load fresh data in background
        Task {
            await refreshUsage()
            await MainActor.run {
                startPeriodicRefresh()
            }
        }
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    private func loadCachedValues() {
        // Try to load previously cached aggregated values
        let cacheKey = "aggregated_usage_\(cacheManager.extractDate(Date()))"
        if let cachedData = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(CachedAggregatedUsage.self, from: cachedData) {
            // Show cached values immediately
            todayInputTokens = cached.todayInputTokens
            todayOutputTokens = cached.todayOutputTokens
            todayCost = cached.todayCost
            monthInputTokens = cached.monthInputTokens
            monthOutputTokens = cached.monthOutputTokens
            monthCost = cached.monthCost
            lastUpdated = cached.lastUpdated
        }
    }
    
    func refreshUsage() async {
        // Don't set isLoading = true here to keep showing previous values
        // Only show loading state on initial load
        
        do {
            // Use ultra fast method if not initial load
            let usage = isLoading ? 
                try await loadUsageDataOptimized() : 
                try await loadUsageDataUltraFast()
            
            // Update values only after successful load
            todayInputTokens = usage.today.inputTokens
            todayOutputTokens = usage.today.outputTokens
            todayCost = usage.today.totalCost
            
            monthInputTokens = usage.thisMonth.inputTokens
            monthOutputTokens = usage.thisMonth.outputTokens
            monthCost = usage.thisMonth.totalCost
            
            lastUpdated = Date()
            isLoading = false
            
            // Cache aggregated values for instant display next time
            let cached = CachedAggregatedUsage(
                todayInputTokens: todayInputTokens,
                todayOutputTokens: todayOutputTokens,
                todayCost: todayCost,
                monthInputTokens: monthInputTokens,
                monthOutputTokens: monthOutputTokens,
                monthCost: monthCost,
                lastUpdated: lastUpdated!
            )
            let cacheKey = "aggregated_usage_\(cacheManager.extractDate(Date()))"
            if let data = try? JSONEncoder().encode(cached) {
                UserDefaults.standard.set(data, forKey: cacheKey)
            }
        } catch {
            print("Failed to load usage data: \(error)")
            // Keep showing previous values on error
            isLoading = false
        }
    }
    
    private func startPeriodicRefresh() {
        // Fixed 60 seconds refresh interval
        let refreshInterval: TimeInterval = 60.0
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.refreshUsage()
            }
        }
    }
    
    private func loadUsageDataOptimized() async throws -> UsageStats {
        let startTime = Date()
        print("\n🚀 Starting optimized usage data loading...")
        
        // Measure file discovery
        let fileStartTime = Date()
        let jsonlFiles = try await findJSONLFilesOptimized(in: claudeProjectsPath)
        let fileEndTime = Date()
        let fileDiscoveryTime = fileEndTime.timeIntervalSince(fileStartTime)
        print("   📁 File discovery: \(String(format: "%.3f", fileDiscoveryTime))s (\(jsonlFiles.count) files)")
        
        // Measure pricing data fetch
        let pricingStartTime = Date()
        let modelPricing = try await PricingFetcher.shared.fetchModelPricing()
        let pricingEndTime = Date()
        let pricingFetchTime = pricingEndTime.timeIntervalSince(pricingStartTime)
        print("   💰 Pricing fetch: \(String(format: "%.3f", pricingFetchTime))s")
        
        // Get today and month dates
        let todayDate = cacheManager.extractDate(Date())
        let currentMonth = String(todayDate.prefix(7))
        
        // Measure parallel processing
        let processingStartTime = Date()
        let allEntries = await processFilesInParallel(jsonlFiles, modelPricing: modelPricing)
        let processingEndTime = Date()
        let processingTime = processingEndTime.timeIntervalSince(processingStartTime)
        print("   ⚡ Total parallel processing: \(String(format: "%.3f", processingTime))s")
        
        // Measure aggregation
        let aggregationStartTime = Date()
        
        // Calculate today's usage
        var todayUsage = UsageData()
        todayUsage.setPricing(modelPricing)
        
        // Calculate month's usage
        var monthUsage = UsageData()
        monthUsage.setPricing(modelPricing)
        
        for entry in allEntries {
            if entry.date == todayDate {
                todayUsage.addFromCached(entry)
            }
            if entry.date.hasPrefix(currentMonth) {
                monthUsage.addFromCached(entry)
            }
        }
        
        let aggregationEndTime = Date()
        let aggregationTime = aggregationEndTime.timeIntervalSince(aggregationStartTime)
        print("   📊 Aggregation: \(String(format: "%.3f", aggregationTime))s")
        
        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)
        
        // Print performance metrics
        print("\n📊 Performance Metrics:")
        print("   Total execution time: \(String(format: "%.3f", totalTime))s")
        print("   Files processed: \(jsonlFiles.count)")
        print("   Total entries: \(allEntries.count)")
        print("   Speed: \(String(format: "%.0f", Double(allEntries.count) / totalTime)) entries/second")
        
        // Check cache statistics
        let cacheStats = cacheManager.getCacheStatistics()
        print("   Cache stats: ~\(cacheStats.memoryCount) in memory, \(cacheStats.diskSize / 1024 / 1024) MB on disk")
        
        if totalTime < 2.0 {
            print("   🎉 ULTRA FAST: Beat ccusage target!")
        } else if totalTime < 5.0 {
            print("   ⚡ FAST: Good performance")
        } else {
            print("   ⚠️  SLOW: Needs optimization")
        }
        print("")
        
        return UsageStats(
            today: todayUsage.toUsageStats(),
            thisMonth: monthUsage.toUsageStats()
        )
    }
    
    private func loadUsageData() async throws -> UsageStats {
        let jsonlFiles = try await findJSONLFiles(in: claudeProjectsPath)
        
        // EXACT ccusage logic: Fetch pricing data first (like ccusage auto mode)
        let modelPricing = try await PricingFetcher.shared.fetchModelPricing()
        
        // Use exact ccusage logic - collect all entries first, then group by date
        var allEntries: [(entry: UsageEntry, date: String)] = []
        
        // Process files like ccusage - line by line
        for file in jsonlFiles {
            do {
                let entries = try await parseJSONLFile(at: file)
                
                for entry in entries {
                    // Format date exactly like ccusage
                    let dateString = formatDateLikeCCusage(entry.timestamp)
                    allEntries.append((entry: entry, date: dateString))
                }
            } catch {
                // Skip files that can't be parsed (like ccusage)
                continue
            }
        }
        
        // Group by date using ccusage's Object.groupBy equivalent
        var groupedByDate: [String: [(entry: UsageEntry, date: String)]] = [:]
        
        for item in allEntries {
            if groupedByDate[item.date] == nil {
                groupedByDate[item.date] = []
            }
            groupedByDate[item.date]?.append(item)
        }
        
        // Get target dates
        let targetDate = formatDateLikeCCusage(Date()) // Today
        let currentMonth = String(targetDate.prefix(7)) // YYYY-MM
        
        // Calculate today's usage
        var todayUsage = UsageData()
        todayUsage.setPricing(modelPricing) // Set pricing for cost calculation
        if let todayEntries = groupedByDate[targetDate] {
            for item in todayEntries {
                todayUsage.add(item.entry)
            }
        }
        
        // Calculate this month's usage
        var monthUsage = UsageData()
        monthUsage.setPricing(modelPricing) // Set pricing for cost calculation
        for (dateKey, entries) in groupedByDate {
            if dateKey.hasPrefix(currentMonth) {
                for item in entries {
                    monthUsage.add(item.entry)
                }
            }
        }
        
        let todayStats = todayUsage.toUsageStats()
        let monthStats = monthUsage.toUsageStats()
        
        return UsageStats(
            today: todayStats,
            thisMonth: monthStats
        )
    }
    
    // EXACT port of ccusage's formatDate function
    private func formatDateLikeCCusage(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Convert back to string then parse to ensure consistent behavior
        let isoString = formatter.string(from: date)
        guard let parsedDate = formatter.date(from: isoString) else {
            // Fallback like ccusage does
            let fallbackFormatter = DateFormatter()
            fallbackFormatter.dateFormat = "yyyy-MM-dd"
            fallbackFormatter.timeZone = TimeZone.current
            return fallbackFormatter.string(from: date)
        }
        
        let calendar = Calendar.current
        let year = calendar.component(.year, from: parsedDate)
        let month = calendar.component(.month, from: parsedDate)
        let day = calendar.component(.day, from: parsedDate)
        
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
    
    private func findJSONLFilesOptimized(in directory: String) async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var files: [String] = []
                
                guard let enumerator = FileManager.default.enumerator(
                    at: URL(fileURLWithPath: directory),
                    includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) else {
                    continuation.resume(returning: [])
                    return
                }
                
                for case let fileURL as URL in enumerator {
                    guard fileURL.pathExtension == "jsonl" else { continue }
                    files.append(fileURL.path)
                }
                
                // Sort by modification date (newest first)
                files.sort { file1, file2 in
                    let attrs1 = try? FileManager.default.attributesOfItem(atPath: file1)
                    let attrs2 = try? FileManager.default.attributesOfItem(atPath: file2)
                    let date1 = attrs1?[.modificationDate] as? Date ?? Date.distantPast
                    let date2 = attrs2?[.modificationDate] as? Date ?? Date.distantPast
                    return date1 > date2
                }
                
                continuation.resume(returning: files)
            }
        }
    }
    
    private func findJSONLFiles(in directory: String) async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var files: [String] = []
                
                // More efficient recursive search using DirectoryEnumerator with filtering
                guard let enumerator = FileManager.default.enumerator(
                    at: URL(fileURLWithPath: directory),
                    includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) else {
                    continuation.resume(returning: [])
                    return
                }
                
                let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                
                for case let fileURL as URL in enumerator {
                    // Only process .jsonl files
                    guard fileURL.pathExtension == "jsonl" else { continue }
                    
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
                        
                        // Skip if not a regular file
                        guard resourceValues.isRegularFile == true else { continue }
                        
                        // Skip old files for performance
                        if let modDate = resourceValues.contentModificationDate,
                           modDate < thirtyDaysAgo {
                            continue
                        }
                        
                        files.append(fileURL.path)
                    } catch {
                        // Skip files we can't read attributes for
                        continue
                    }
                }
                
                continuation.resume(returning: files)
            }
        }
    }
    
    private func processFilesInParallel(_ files: [String], modelPricing: [String: ModelPricing]) async -> [UltraCachedEntry] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }
                
                let parallelStart = Date()
                var allEntries: [UltraCachedEntry] = []
                let lock = NSLock()
                let group = DispatchGroup()
                var cacheHits = 0
                var cacheMisses = 0
                
                // Process files in parallel
                let batchSize = max(1, files.count / (ProcessInfo.processInfo.activeProcessorCount * 2))
                print("   Using \(ProcessInfo.processInfo.activeProcessorCount) CPU cores")
                
                for (index, batch) in files.chunked(into: batchSize).enumerated() {
                    group.enter()
                    
                    DispatchQueue.global(qos: .userInitiated).async {
                        var batchEntries: [UltraCachedEntry] = []
                        
                        for file in batch {
                            autoreleasepool {
                                // Get file modification date
                                guard let attrs = try? FileManager.default.attributesOfItem(atPath: file),
                                      let modDate = attrs[.modificationDate] as? Date else { return }
                                
                                // Check cache first
                                if let cached = self.cacheManager.getCachedData(for: file) {
                                    batchEntries.append(contentsOf: cached)
                                    lock.lock()
                                    cacheHits += 1
                                    lock.unlock()
                                    return
                                }
                                
                                // Parse file if not cached
                                var fileEntries: [UltraCachedEntry] = []
                                
                                if let content = try? String(contentsOfFile: file, encoding: .utf8) {
                                    let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
                                    let decoder = JSONDecoder()
                                    
                                    for line in lines {
                                        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                                        guard !trimmedLine.isEmpty else { continue }
                                        
                                        do {
                                            let data = trimmedLine.data(using: .utf8)!
                                            let entry = try decoder.decode(UsageEntry.self, from: data)
                                            
                                            // Convert to cached entry
                                            let date = self.cacheManager.extractDate(entry.timestamp)
                                            var cost = entry.costUSD
                                            
                                            // Calculate cost if not provided
                                            if cost == nil, let model = entry.message.model,
                                               let modelPrice = PricingFetcher.shared.getModelPricing(model, from: modelPricing) {
                                                cost = PricingFetcher.shared.calculateCostFromTokens(
                                                    inputTokens: entry.message.usage.inputTokens ?? 0,
                                                    outputTokens: entry.message.usage.outputTokens ?? 0,
                                                    cacheCreationTokens: entry.message.usage.cacheCreationInputTokens ?? 0,
                                                    cacheReadTokens: entry.message.usage.cacheReadInputTokens ?? 0,
                                                    pricing: modelPrice
                                                )
                                            }
                                            
                                            let cachedEntry = UltraCachedEntry(
                                                date: date,
                                                inputTokens: entry.message.usage.inputTokens ?? 0,
                                                outputTokens: entry.message.usage.outputTokens ?? 0,
                                                cacheCreateTokens: entry.message.usage.cacheCreationInputTokens ?? 0,
                                                cacheReadTokens: entry.message.usage.cacheReadInputTokens ?? 0,
                                                costUSD: cost,
                                                model: entry.message.model
                                            )
                                            fileEntries.append(cachedEntry)
                                        } catch {
                                            // Skip invalid entries
                                            continue
                                        }
                                    }
                                    
                                    // Cache the parsed entries
                                    self.cacheManager.setCachedData(fileEntries, for: file, modificationDate: modDate)
                                    
                                    lock.lock()
                                    cacheMisses += 1
                                    lock.unlock()
                                }
                                
                                batchEntries.append(contentsOf: fileEntries)
                            }
                        }
                        
                        
                        lock.lock()
                        allEntries.append(contentsOf: batchEntries)
                        lock.unlock()
                        
                        group.leave()
                    }
                }
                
                group.wait()
                
                let parallelEnd = Date()
                let parallelTime = parallelEnd.timeIntervalSince(parallelStart)
                
                print("   Parallel processing completed in \(String(format: "%.3f", parallelTime))s")
                print("   Cache hits: \(cacheHits) (\(String(format: "%.1f", Double(cacheHits) / Double(files.count) * 100))%)")
                print("   Cache misses: \(cacheMisses)")
                
                continuation.resume(returning: allEntries)
            }
        }
    }
    
    private func parseJSONLFile(at path: String) async throws -> [UsageEntry] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    // Simplified streaming approach - read in larger chunks like ccusage
                    let content = try String(contentsOfFile: path, encoding: .utf8)
                    let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
                    
                    var entries: [UsageEntry] = []
                    let decoder = JSONDecoder()
                    
                    // Process lines efficiently like ccusage
                    for line in lines {
                        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedLine.isEmpty else { continue }
                        
                        do {
                            let data = trimmedLine.data(using: .utf8)!
                            let entry = try decoder.decode(UsageEntry.self, from: data)
                            entries.append(entry)
                        } catch {
                            // Skip invalid JSON lines (like ccusage does)
                            continue
                        }
                    }
                    
                    continuation.resume(returning: entries)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Data Models

struct UsageEntry: Codable {
    let timestamp: Date
    let version: String?
    let message: MessageUsage
    let costUSD: Double?
    
    private enum CodingKeys: String, CodingKey {
        case timestamp, version, message, costUSD
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Parse timestamp - could be ISO string or Unix timestamp
        if let timestampString = try? container.decode(String.self, forKey: .timestamp) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            self.timestamp = formatter.date(from: timestampString) ?? Date()
        } else {
            self.timestamp = Date()
        }
        
        self.version = try container.decodeIfPresent(String.self, forKey: .version)
        self.message = try container.decode(MessageUsage.self, forKey: .message)
        self.costUSD = try container.decodeIfPresent(Double.self, forKey: .costUSD)
    }
}

struct MessageUsage: Codable {
    let usage: TokenUsage
    let model: String?
}

struct TokenUsage: Codable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?
    
    private enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}

struct UsageData {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var cacheReadTokens: Int = 0
    var totalCost: Double = 0.0
    
    // Store pricing for cost calculation
    private var modelPricing: [String: ModelPricing]?
    
    mutating func setPricing(_ pricing: [String: ModelPricing]) {
        self.modelPricing = pricing
    }
    
    mutating func add(_ entry: UsageEntry) {
        let usage = entry.message.usage
        inputTokens += usage.inputTokens ?? 0
        outputTokens += usage.outputTokens ?? 0
        cacheCreationTokens += usage.cacheCreationInputTokens ?? 0
        cacheReadTokens += usage.cacheReadInputTokens ?? 0
        
        // EXACT ccusage logic: calculateCostForEntry() with auto mode
        if let cost = entry.costUSD {
            // Use pre-calculated cost when available
            totalCost += cost
        } else if let model = entry.message.model,
                  let pricing = modelPricing {
            // Calculate from tokens using ccusage's exact logic
            if let modelPrice = PricingFetcher.shared.getModelPricing(model, from: pricing) {
                let cost = PricingFetcher.shared.calculateCostFromTokens(
                    inputTokens: usage.inputTokens ?? 0,
                    outputTokens: usage.outputTokens ?? 0,
                    cacheCreationTokens: usage.cacheCreationInputTokens ?? 0,
                    cacheReadTokens: usage.cacheReadInputTokens ?? 0,
                    pricing: modelPrice
                )
                totalCost += cost
            }
            // If no pricing found, cost is 0 (same as ccusage)
        }
    }
    
    
    func toUsageStats() -> UsageStatsPeriod {
        return UsageStatsPeriod(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            totalCost: totalCost
        )
    }
}

struct UsageStats {
    let today: UsageStatsPeriod
    let thisMonth: UsageStatsPeriod
}


struct UsageStatsPeriod {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let totalCost: Double
}

// Helper structures for caching
struct CachedAggregatedUsage: Codable {
    let todayInputTokens: Int
    let todayOutputTokens: Int
    let todayCost: Double?
    let monthInputTokens: Int
    let monthOutputTokens: Int
    let monthCost: Double?
    let lastUpdated: Date
}

// Extension for UsageData to work with cached entries
extension UsageData {
    mutating func addFromCached(_ entry: UltraCachedEntry) {
        inputTokens += entry.inputTokens
        outputTokens += entry.outputTokens
        cacheCreationTokens += entry.cacheCreateTokens
        cacheReadTokens += entry.cacheReadTokens
        
        if let cost = entry.costUSD {
            totalCost += cost
        }
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

// Extension for ultra-fast loading
extension UsageManager {
    internal func loadUsageDataUltraFast() async throws -> UsageStats {
        let startTime = Date()
        print("\n⚡ Starting ULTRA FAST loading...")
        
        // Try to get cached file list (instant)
        var jsonlFiles: [String]
        if let cachedFiles = await UltraFastManager.shared.getCachedFileList() {
            jsonlFiles = cachedFiles
            print("   📁 File list from memory cache (instant)")
        } else {
            // Fall back to regular discovery and cache it
            let discoveryStart = Date()
            jsonlFiles = try await self.findJSONLFilesOptimized(in: self.claudeProjectsPath)
            let discoveryTime = Date().timeIntervalSince(discoveryStart)
            print("   📁 File discovery: \(String(format: "%.3f", discoveryTime))s (\(jsonlFiles.count) files)")
            UltraFastManager.shared.cacheFileList(jsonlFiles)
        }
        
        // Try to get cached pricing (instant)
        var modelPricing: [String: ModelPricing]
        if let cachedPricing = await UltraFastManager.shared.getCachedPricing() {
            modelPricing = cachedPricing
            print("   💰 Pricing from memory cache (instant)")
        } else {
            // Fall back to fetching and cache it
            let pricingStart = Date()
            modelPricing = try await PricingFetcher.shared.fetchModelPricing()
            let pricingTime = Date().timeIntervalSince(pricingStart)
            print("   💰 Pricing fetch: \(String(format: "%.3f", pricingTime))s")
            UltraFastManager.shared.cachePricing(modelPricing)
        }
        
        // Get today and month dates
        let todayDate = self.cacheManager.extractDate(Date())
        let currentMonth = String(todayDate.prefix(7))
        
        // Process files (mostly from cache)
        let processingStartTime = Date()
        let allEntries = await self.processFilesInParallel(jsonlFiles, modelPricing: modelPricing)
        let processingTime = Date().timeIntervalSince(processingStartTime)
        print("   ⚡ Parallel processing: \(String(format: "%.3f", processingTime))s")
        
        // Calculate usage
        var todayUsage = UsageData()
        todayUsage.setPricing(modelPricing)
        
        var monthUsage = UsageData()
        monthUsage.setPricing(modelPricing)
        
        for entry in allEntries {
            if entry.date == todayDate {
                todayUsage.addFromCached(entry)
            }
            if entry.date.hasPrefix(currentMonth) {
                monthUsage.addFromCached(entry)
            }
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        print("   ⏱️  Total time: \(String(format: "%.3f", totalTime))s")
        
        if totalTime < 0.01 {
            print("   🚀 ULTRA FAST: < 10ms!")
        } else if totalTime < 0.1 {
            print("   ⚡ VERY FAST: < 100ms")
        }
        
        return UsageStats(
            today: todayUsage.toUsageStats(),
            thisMonth: monthUsage.toUsageStats()
        )
    }
}