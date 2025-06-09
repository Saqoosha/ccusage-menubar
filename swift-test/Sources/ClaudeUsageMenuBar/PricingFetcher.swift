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
    
    private init() {}
    
    // EXACT port of fetchModelPricing()
    func fetchModelPricing() async throws -> [String: ModelPricing] {
        if let cached = cachedPricing {
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
}