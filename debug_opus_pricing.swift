#!/usr/bin/env swift

import Foundation

// Test pricing for different models
let opusPricing = (
    input: 15e-06,     // $0.000015 per token (5x more than Sonnet)
    output: 75e-06,    // $0.000075 per token (5x more than Sonnet)
    cache: 0.00000249  // Same cache rate
)

let sonnetPricing = (
    input: 3e-06,      // $0.000003 per token
    output: 15e-06,    // $0.000015 per token
    cache: 0.00000249
)

// Sample token counts for one message
let sampleTokens = (
    input: 100,
    output: 500,
    cache: 10000
)

print("🔍 Model Pricing Comparison:")
print("============================")
print("\nFor sample message with:")
print("  Input: \(sampleTokens.input) tokens")
print("  Output: \(sampleTokens.output) tokens")
print("  Cache: \(sampleTokens.cache) tokens")
print("")

// Calculate costs
let opusCost = Double(sampleTokens.input) * opusPricing.input +
               Double(sampleTokens.output) * opusPricing.output +
               Double(sampleTokens.cache) * opusPricing.cache

let sonnetCost = Double(sampleTokens.input) * sonnetPricing.input +
                 Double(sampleTokens.output) * sonnetPricing.output +
                 Double(sampleTokens.cache) * sonnetPricing.cache

print("💰 Cost with OPUS pricing: $\(String(format: "%.6f", opusCost))")
print("💰 Cost with SONNET pricing: $\(String(format: "%.6f", sonnetCost))")
print("📈 Opus is \(String(format: "%.1fx", opusCost/sonnetCost)) more expensive")
print("")

// Now check real data
print("📊 Your usage has:")
print("  claude-opus-4-20250514: 1012 entries")
print("  claude-sonnet-4-20250514: 1298 entries")
print("")
print("⚠️  If Opus entries are being priced as Sonnet, the cost will be MUCH lower than actual!")