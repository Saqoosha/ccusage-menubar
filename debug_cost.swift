#!/usr/bin/env swift

import Foundation

// Quick debug script to analyze cost calculation
let claudePath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".claude/projects")
    .path

var totalCostWithUSD = 0.0
var totalCostCalculated = 0.0
var entriesWithCost = 0
var entriesWithoutCost = 0
var modelCounts: [String: Int] = [:]

// Check a sample of entries for 2025-06-09
if let enumerator = FileManager.default.enumerator(atPath: claudePath) {
    while let file = enumerator.nextObject() as? String {
        if file.hasSuffix(".jsonl") {
            let fullPath = "\(claudePath)/\(file)"
            if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
                
                for line in lines {
                    if let data = line.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let timestamp = json["timestamp"] as? String {
                        
                        // Check if this is 2025-06-09
                        if timestamp.hasPrefix("2025-06-09") {
                            if let costUSD = json["costUSD"] as? Double {
                                totalCostWithUSD += costUSD
                                entriesWithCost += 1
                            } else {
                                entriesWithoutCost += 1
                                // Check model for entries without cost
                                if let message = json["message"] as? [String: Any],
                                   let model = message["model"] as? String {
                                    modelCounts[model] = (modelCounts[model] ?? 0) + 1
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

print("🔍 Cost Analysis for 2025-06-09:")
print("================================")
print("Entries WITH costUSD: \(entriesWithCost)")
print("Entries WITHOUT costUSD: \(entriesWithoutCost)")
print("Total cost from costUSD fields: $\(String(format: "%.2f", totalCostWithUSD))")
print("\nModels for entries without cost:")
for (model, count) in modelCounts.sorted(by: { $0.key < $1.key }) {
    print("  \(model): \(count) entries")
}

// Now let's check what ccusage mode would do
print("\n📊 ccusage mode analysis:")
print("- auto mode: Uses costUSD when available, calculates otherwise")
print("- Entries with costUSD will use that value directly")
print("- Entries without costUSD need model-based calculation")