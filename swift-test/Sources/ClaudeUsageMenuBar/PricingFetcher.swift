import Foundation

// EXACT port of ccusage's pricing-fetcher.ts
struct ModelPricing: Codable {
    let inputCostPerToken: Double?
    let outputCostPerToken: Double?
    let cacheCreationInputTokenCost: Double?
    let cacheReadInputTokenCost: Double?
    
    private enum CodingKeys: String, CodingKey {
        case inputCostPerToken = "input_cost_per_token"
        case outputCostPerToken = "output_cost_per_token"
        case cacheCreationInputTokenCost = "cache_creation_input_token_cost"
        case cacheReadInputTokenCost = "cache_read_input_token_cost"
    }
}

class PricingFetcher {
    static let shared = PricingFetcher()
    
    private let litellmPricingURL = "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json"
    private var cachedPricing: [String: ModelPricing]?
    private var lastFetchTime: Date?
    private let cacheDuration: TimeInterval = 86400 // 24 hours
    
    private init() {
        // Load cached pricing from UserDefaults on init
        loadCachedPricingFromDisk()
    }
    
    // Load cached pricing from UserDefaults
    private func loadCachedPricingFromDisk() {
        if let data = UserDefaults.standard.data(forKey: "claudePricingCache"),
           let cached = try? JSONDecoder().decode([String: ModelPricing].self, from: data),
           let lastFetch = UserDefaults.standard.object(forKey: "claudePricingCacheDate") as? Date {
            
            // Check if cache is still valid (within 24 hours)
            if Date().timeIntervalSince(lastFetch) < cacheDuration {
                self.cachedPricing = cached
                self.lastFetchTime = lastFetch
                print("📦 Loaded pricing from disk cache (\(cached.count) models)")
            } else {
                print("⏰ Pricing cache expired, will fetch fresh data")
            }
        }
    }
    
    // Save pricing to UserDefaults
    private func saveCachedPricingToDisk(_ pricing: [String: ModelPricing]) {
        if let data = try? JSONEncoder().encode(pricing) {
            UserDefaults.standard.set(data, forKey: "claudePricingCache")
            UserDefaults.standard.set(Date(), forKey: "claudePricingCacheDate")
        }
    }
    
    // EXACT port of fetchModelPricing() with 24h caching
    func fetchModelPricing() async throws -> [String: ModelPricing] {
        // Check if we have valid cached pricing
        if let cached = cachedPricing,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheDuration {
            print("💰 Using cached pricing (\(cached.count) models)")
            return cached
        }
        
        print("[ccusage]  WARN  Fetching latest model pricing from LiteLLM...")
        
        guard let url = URL(string: litellmPricingURL) else {
            throw NSError(domain: "PricingFetcher", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // Parse JSON as dictionary
        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "PricingFetcher", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"])
        }
        
        var pricing: [String: ModelPricing] = [:]
        
        for (modelName, modelData) in jsonObject {
            if let modelDict = modelData as? [String: Any] {
                // Try to decode this model's pricing
                if let modelJson = try? JSONSerialization.data(withJSONObject: modelDict),
                   let modelPricing = try? JSONDecoder().decode(ModelPricing.self, from: modelJson) {
                    pricing[modelName] = modelPricing
                }
            }
        }
        
        cachedPricing = pricing
        lastFetchTime = Date()
        
        // Save to disk for next time
        saveCachedPricingToDisk(pricing)
        
        print("ℹ Loaded pricing for \(pricing.count) models")
        
        return pricing
    }
    
    // EXACT port of getModelPricing()
    func getModelPricing(_ modelName: String, from pricing: [String: ModelPricing]) -> ModelPricing? {
        // Direct match
        if let directMatch = pricing[modelName] {
            return directMatch
        }
        
        // Try with provider prefix variations (EXACT same as ccusage)
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
        
        // Try to find partial matches (EXACT same logic)
        let lowerModel = modelName.lowercased()
        for (key, value) in pricing {
            if key.lowercased().contains(lowerModel) || lowerModel.contains(key.lowercased()) {
                return value
            }
        }
        
        return nil
    }
    
    // EXACT port of calculateCostFromTokens()
    func calculateCostFromTokens(
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int,
        pricing: ModelPricing
    ) -> Double {
        var cost = 0.0
        
        // Input tokens cost
        if let inputRate = pricing.inputCostPerToken {
            cost += Double(inputTokens) * inputRate
        }
        
        // Output tokens cost
        if let outputRate = pricing.outputCostPerToken {
            cost += Double(outputTokens) * outputRate
        }
        
        // Cache creation tokens cost
        if let cacheCreateRate = pricing.cacheCreationInputTokenCost {
            cost += Double(cacheCreationTokens) * cacheCreateRate
        }
        
        // Cache read tokens cost
        if let cacheReadRate = pricing.cacheReadInputTokenCost {
            cost += Double(cacheReadTokens) * cacheReadRate
        }
        
        return cost
    }
    
    // Force refresh pricing (for manual refresh button)
    func refreshPricing() async throws -> [String: ModelPricing] {
        cachedPricing = nil
        lastFetchTime = nil
        UserDefaults.standard.removeObject(forKey: "claudePricingCache")
        UserDefaults.standard.removeObject(forKey: "claudePricingCacheDate")
        return try await fetchModelPricing()
    }
}