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
    
    init() {
        self.claudeProjectsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("projects")
            .path
        
        // Set loading state immediately
        self.isLoading = true
        
        // Load data immediately on init
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
    
    func refreshUsage() async {
        isLoading = true
        
        do {
            let usage = try await loadUsageData()
            
            todayInputTokens = usage.today.inputTokens
            todayOutputTokens = usage.today.outputTokens
            todayCost = usage.today.totalCost
            
            monthInputTokens = usage.thisMonth.inputTokens
            monthOutputTokens = usage.thisMonth.outputTokens
            monthCost = usage.thisMonth.totalCost
            
            lastUpdated = Date()
        } catch {
            print("Failed to load usage data: \(error)")
        }
        
        isLoading = false
    }
    
    private func startPeriodicRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
            Task { @MainActor in
                await self.refreshUsage()
            }
        }
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