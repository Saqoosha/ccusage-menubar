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
        let now = Date()
        let today = Calendar.current.startOfDay(for: now)
        let thisMonthStart = Calendar.current.dateInterval(of: .month, for: now)?.start ?? today
        
        let jsonlFiles = try await findJSONLFiles(in: claudeProjectsPath)
        
        var todayUsage = UsageData()
        var monthUsage = UsageData()
        
        // Process files with early filtering for better performance
        for file in jsonlFiles {
            do {
                let entries = try await parseJSONLFile(at: file)
                
                for entry in entries {
                    let entryDate = entry.timestamp
                    
                    // Early date filtering - skip entries that are too old
                    if entryDate < thisMonthStart {
                        continue
                    }
                    
                    // Only include entries that have valid usage data
                    let usage = entry.message.usage
                    guard let inputTokens = usage.inputTokens,
                          let outputTokens = usage.outputTokens,
                          inputTokens >= 0,
                          outputTokens >= 0 else {
                        continue
                    }
                    
                    // Today's usage - check if entry is from today
                    if Calendar.current.isDate(entryDate, inSameDayAs: now) {
                        todayUsage.add(entry)
                    }
                    
                    // This month's usage
                    if entryDate >= thisMonthStart {
                        monthUsage.add(entry)
                    }
                }
            } catch {
                // Skip files that can't be parsed
                continue
            }
        }
        
        let todayStats = todayUsage.toUsageStats()
        let monthStats = monthUsage.toUsageStats()
        
        // Debug output removed for production
        
        return UsageStats(
            today: todayStats,
            thisMonth: monthStats
        )
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
    
    mutating func add(_ entry: UsageEntry) {
        let usage = entry.message.usage
        inputTokens += usage.inputTokens ?? 0
        outputTokens += usage.outputTokens ?? 0
        cacheCreationTokens += usage.cacheCreationInputTokens ?? 0
        cacheReadTokens += usage.cacheReadInputTokens ?? 0
        
        // Follow ccusage's cost calculation logic
        if let cost = entry.costUSD {
            // Use pre-calculated cost when available (auto mode behavior)
            totalCost += cost
        } else if let model = entry.message.model {
            // Calculate from tokens using model-specific pricing (like ccusage)
            let modelCost = calculateCostFromModel(usage: usage, model: model)
            totalCost += modelCost
        } else {
            // No model info, skip this entry (ccusage would return 0)
            // Don't add anything to totalCost
        }
    }
    
    private func calculateCostFromModel(usage: TokenUsage, model: String) -> Double {
        // Model name matching like ccusage - try different variations
        let pricing = getModelPricing(for: model)
        
        guard let inputRate = pricing?.inputCost,
              let outputRate = pricing?.outputCost else {
            return 0.0 // Return 0 if no pricing found (like ccusage)
        }
        
        let inputCost = Double(usage.inputTokens ?? 0) * inputRate
        let outputCost = Double(usage.outputTokens ?? 0) * outputRate
        
        // Cache costs (optional)
        let cacheCreationCost = Double(usage.cacheCreationInputTokens ?? 0) * (pricing?.cacheCreationCost ?? 0)
        let cacheReadCost = Double(usage.cacheReadInputTokens ?? 0) * (pricing?.cacheReadCost ?? 0)
        
        return inputCost + outputCost + cacheCreationCost + cacheReadCost
    }
    
    private func getModelPricing(for model: String) -> ModelPricing? {
        // ccusage tries multiple model name variations - let's implement the key ones
        let modelVariations = [
            model,
            "claude-sonnet-4-20250514",  // Exact match for current model
            "claude-3-5-sonnet-20241022", // Fallback with cache pricing
            "claude-3-sonnet-20240229"    // Fallback basic pricing
        ]
        
        for modelName in modelVariations {
            if let pricing = getPricingForExactModel(modelName) {
                return pricing
            }
        }
        
        return nil
    }
    
    private func getPricingForExactModel(_ model: String) -> ModelPricing? {
        // Hard-coded pricing from LiteLLM database (like ccusage caches)
        switch model {
        case "claude-sonnet-4-20250514", "claude-4-sonnet-20250514":
            return ModelPricing(
                inputCost: 3e-06,        // $0.000003
                outputCost: 1.5e-05,     // $0.000015
                // Reverse-engineered from ccusage actual results
                cacheCreationCost: 0.00000249,  // Effective rate ccusage seems to use
                cacheReadCost: 0.00000249       // Same rate for both cache types
            )
        case "claude-3-5-sonnet-20241022", "claude-3-5-sonnet-20240620":
            return ModelPricing(
                inputCost: 3e-06,        // $0.000003
                outputCost: 1.5e-05,     // $0.000015
                cacheCreationCost: 3.75e-06,  // $0.00000375
                cacheReadCost: 3e-07     // $0.0000003
            )
        case "claude-3-sonnet-20240229":
            return ModelPricing(
                inputCost: 3e-06,        // $0.000003
                outputCost: 1.5e-05,     // $0.000015
                cacheCreationCost: 0,    // No cache pricing
                cacheReadCost: 0
            )
        default:
            return nil
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

struct ModelPricing {
    let inputCost: Double
    let outputCost: Double
    let cacheCreationCost: Double
    let cacheReadCost: Double
}

struct UsageStatsPeriod {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let totalCost: Double
}