import Foundation

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
        
        // Parse timestamp
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

struct ModelPricing {
    let inputCost: Double
    let outputCost: Double
    let cacheCreationCost: Double
    let cacheReadCost: Double
}

struct DailyUsageData {
    var entries: Int = 0
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheCreateTokens: Int = 0
    var cacheReadTokens: Int = 0
    var totalCost: Double = 0.0
    var costFromUSD: Double = 0.0
    var costFromTokens: Double = 0.0
    var entriesWithCostUSD: Int = 0
    var entriesWithModel: Int = 0
}

// MARK: - Cost Calculation
func fetchLiteLLMPricing() async -> [String: ModelPricing] {
    let url = "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json"
    
    do {
        let (data, _) = try await URLSession.shared.data(from: URL(string: url)!)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        var pricing: [String: ModelPricing] = [:]
        
        for (modelName, modelData) in json {
            if let model = modelData as? [String: Any] {
                let inputCost = model["input_cost_per_token"] as? Double ?? 0.0
                let outputCost = model["output_cost_per_token"] as? Double ?? 0.0
                let cacheCost = model["cache_creation_input_token_cost"] as? Double ?? 0.0
                let cacheReadCost = model["cache_read_input_token_cost"] as? Double ?? 0.0
                
                pricing[modelName] = ModelPricing(
                    inputCost: inputCost,
                    outputCost: outputCost,
                    cacheCreationCost: cacheCost,
                    cacheReadCost: cacheReadCost
                )
            }
        }
        
        print("🌐 Loaded pricing for \(pricing.count) models from LiteLLM")
        return pricing
    } catch {
        print("❌ Failed to fetch LiteLLM pricing: \(error)")
        return [:]
    }
}

func getModelPricing(for modelName: String, from pricing: [String: ModelPricing]) -> ModelPricing? {
    // Direct match like ccusage
    if let directMatch = pricing[modelName] {
        return directMatch
    }
    
    // Try with provider prefix variations like ccusage
    let variations = [
        modelName,
        "anthropic/\(modelName)",
        "claude-3-5-\(modelName)",
        "claude-3-\(modelName)",
        "claude-\(modelName)"
    ]
    
    for variant in variations {
        if let match = pricing[variant] {
            return match
        }
    }
    
    // Try partial matches like ccusage
    let lowerModel = modelName.lowercased()
    for (key, value) in pricing {
        let lowerKey = key.lowercased()
        if lowerKey.contains(lowerModel) || lowerModel.contains(lowerKey) {
            return value
        }
    }
    
    // Suppress unknown model warnings for cleaner output
    // print("🚨 No pricing found for model: \(modelName)")
    return nil
}

func calculateCostFromModel(usage: TokenUsage, model: String, pricing: [String: ModelPricing]) -> Double {
    guard let modelPricing = getModelPricing(for: model, from: pricing) else {
        return 0.0
    }
    
    // Calculate exactly like ccusage
    var cost = 0.0
    
    // Input tokens cost
    cost += Double(usage.inputTokens ?? 0) * modelPricing.inputCost
    
    // Output tokens cost  
    cost += Double(usage.outputTokens ?? 0) * modelPricing.outputCost
    
    // Cache creation tokens cost
    if let cacheCreate = usage.cacheCreationInputTokens {
        cost += Double(cacheCreate) * modelPricing.cacheCreationCost
    }
    
    // Cache read tokens cost
    if let cacheRead = usage.cacheReadInputTokens {
        cost += Double(cacheRead) * modelPricing.cacheReadCost
    }
    
    return cost
}

// MARK: - File Processing
func findJSONLFiles(in directory: String) -> [String] {
    guard let enumerator = FileManager.default.enumerator(
        at: URL(fileURLWithPath: directory),
        includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }
    
    var files: [String] = []
    
    for case let fileURL as URL in enumerator {
        guard fileURL.pathExtension == "jsonl" else { continue }
        files.append(fileURL.path)
    }
    
    return files
}

func parseJSONLFile(at path: String) -> [UsageEntry] {
    do {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        
        var entries: [UsageEntry] = []
        let decoder = JSONDecoder()
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            
            do {
                let data = trimmedLine.data(using: .utf8)!
                let entry = try decoder.decode(UsageEntry.self, from: data)
                entries.append(entry)
            } catch {
                continue
            }
        }
        
        return entries
    } catch {
        return []
    }
}

// MARK: - Main Logic  
func runCostCalculation() async {
    print("🧮 Claude Cost Calculator CLI")
    print("=============================")
    
    let claudeProjectsPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude")
        .appendingPathComponent("projects")
        .path
    
    print("📁 Loading from: \(claudeProjectsPath)")
    
    let startTime = Date()
    
    // Fetch LiteLLM pricing like ccusage
    let modelPricing = await fetchLiteLLMPricing()
    
    let files = findJSONLFiles(in: claudeProjectsPath)
    print("📄 Found \(files.count) JSONL files")
    
    // Dictionary to store daily usage data
    var dailyUsage: [String: DailyUsageData] = [:]
    
    for file in files {
        let entries = parseJSONLFile(at: file)
        
        for entry in entries {
            // Format date as YYYY-MM-DD
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateKey = dateFormatter.string(from: entry.timestamp)
            
            // Initialize daily data if needed
            if dailyUsage[dateKey] == nil {
                dailyUsage[dateKey] = DailyUsageData()
            }
            
            var dayData = dailyUsage[dateKey]!
            dayData.entries += 1
            
            let usage = entry.message.usage
            dayData.inputTokens += usage.inputTokens ?? 0
            dayData.outputTokens += usage.outputTokens ?? 0
            dayData.cacheCreateTokens += usage.cacheCreationInputTokens ?? 0
            dayData.cacheReadTokens += usage.cacheReadInputTokens ?? 0
            
            // Calculate cost like ccusage
            if let cost = entry.costUSD {
                dayData.totalCost += cost
                dayData.costFromUSD += cost
                dayData.entriesWithCostUSD += 1
            } else if let model = entry.message.model {
                let modelCost = calculateCostFromModel(usage: usage, model: model, pricing: modelPricing)
                dayData.totalCost += modelCost
                dayData.costFromTokens += modelCost
                dayData.entriesWithModel += 1
            }
            
            dailyUsage[dateKey] = dayData
        }
    }
    
    let processingTime = Date().timeIntervalSince(startTime)
    
    print("\n📊 Daily Usage Report")
    print("===========================================")
    print("⏱️ Processing time: \(String(format: "%.2f", processingTime))s")
    print("📄 Found \(dailyUsage.count) days with usage data\n")
    
    // Sort dates in descending order (most recent first)
    let sortedDates = dailyUsage.keys.sorted().reversed()
    
    // Print header
    print(String(format: "%-12s %10s %10s %12s %14s %12s", 
                  "Date", "Input", "Output", "Cache Create", "Cache Read", "Cost (USD)"))
    print(String(repeating: "-", count: 80))
    
    var totalInputTokens = 0
    var totalOutputTokens = 0
    var totalCacheCreate = 0
    var totalCacheRead = 0
    var totalCost = 0.0
    
    for date in sortedDates {
        let data = dailyUsage[date]!
        
        totalInputTokens += data.inputTokens
        totalOutputTokens += data.outputTokens
        totalCacheCreate += data.cacheCreateTokens
        totalCacheRead += data.cacheReadTokens
        totalCost += data.totalCost
        
        print(String(format: "%-12s %10s %10s %12s %14s $%10.2f", 
                      date,
                      String(data.inputTokens).withCommas(),
                      String(data.outputTokens).withCommas(),
                      String(data.cacheCreateTokens).withCommas(),
                      String(data.cacheReadTokens).withCommas(),
                      data.totalCost))
    }
    
    print(String(repeating: "-", count: 80))
    print(String(format: "%-12s %10s %10s %12s %14s $%10.2f", 
                  "Total",
                  String(totalInputTokens).withCommas(),
                  String(totalOutputTokens).withCommas(),
                  String(totalCacheCreate).withCommas(),
                  String(totalCacheRead).withCommas(),
                  totalCost))
    
    // Run ccusage in parallel for comparison
    print("\n🔄 Running ccusage for comparison...")
    
    let ccusageTask = Task {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["npx", "ccusage@latest"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "Error running ccusage: \(error)"
        }
    }
    
    let ccusageOutput = await ccusageTask.value
    
    print("\n📊 Comparison with ccusage")
    print("==========================")
    
    // Show today's data specifically
    let todayFormatter = DateFormatter()
    todayFormatter.dateFormat = "yyyy-MM-dd"
    let todayKey = todayFormatter.string(from: Date())
    
    if let todayData = dailyUsage[todayKey] {
        print("🔹 Swift CLI Today (\(todayKey)): $\(String(format: "%.2f", todayData.totalCost))")
        
        // Extract today's cost from ccusage output
        if let ccusageTodayMatch = ccusageOutput.range(of: #"2025-06-09.*?\$(\d+\.\d+)"#, options: .regularExpression) {
            let ccusageLine = String(ccusageOutput[ccusageTodayMatch])
            if let dollarRange = ccusageLine.range(of: #"\$\d+\.\d+"#, options: .regularExpression) {
                let ccusageCost = String(ccusageLine[dollarRange])
                print("🔹 ccusage Today: \(ccusageCost)")
                
                if let ccusageValue = Double(ccusageCost.replacingOccurrences(of: "$", with: "")) {
                    let difference = todayData.totalCost - ccusageValue
                    print("🔧 Difference: $\(String(format: "%.2f", difference))")
                    let accuracy = (1.0 - abs(difference) / ccusageValue) * 100
                    print("✅ Accuracy: \(String(format: "%.1f", accuracy))%")
                }
            }
        }
    }
    
    print("\n📋 ccusage output:")
    print(String(repeating: "-", count: 60))
    print(ccusageOutput)
}

extension String {
    func withCommas() -> String {
        guard let number = Int(self) else { return self }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? self
    }
}

@main
struct ClaudeCostCLI {
    static func main() async {
        await runCostCalculation()
    }
}