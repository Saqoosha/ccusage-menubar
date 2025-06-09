#!/usr/bin/env swift

import Foundation

// Test cost calculation with exact ccusage logic

let claudePath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".claude/projects")
    .path

var totalCostAuto = 0.0  // ccusage auto mode
var totalCostCalc = 0.0  // always calculate
var entriesWithCost = 0
var entriesWithoutCost = 0

// Process exactly like ccusage - check one sample file
if let enumerator = FileManager.default.enumerator(atPath: claudePath) {
    fileLoop: while let file = enumerator.nextObject() as? String {
        if file.hasSuffix(".jsonl") {
            let fullPath = "\(claudePath)/\(file)"
            if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
                
                for line in lines.prefix(100) { // Check first 100 lines
                    if let data = line.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let timestamp = json["timestamp"] as? String {
                        
                        if timestamp.hasPrefix("2025-06-09") {
                            // Check costUSD field
                            if let costUSD = json["costUSD"] as? Double {
                                print("✅ Entry WITH costUSD: $\(costUSD)")
                                totalCostAuto += costUSD
                                entriesWithCost += 1
                            } else {
                                // No costUSD - need to calculate
                                if let message = json["message"] as? [String: Any],
                                   let model = message["model"] as? String,
                                   let usage = message["usage"] as? [String: Any] {
                                    print("❌ Entry WITHOUT costUSD, model: \(model)")
                                    entriesWithoutCost += 1
                                }
                            }
                            
                            if entriesWithCost + entriesWithoutCost >= 10 {
                                break fileLoop
                            }
                        }
                    }
                }
            }
        }
    }
}

print("\n📊 Summary of first entries:")
print("Entries WITH costUSD: \(entriesWithCost)")
print("Entries WITHOUT costUSD: \(entriesWithoutCost)")
print("Total from costUSD: $\(totalCostAuto)")
print("\n💡 If ALL entries have costUSD, no calculation is needed!")
print("   If NO entries have costUSD, model-based calculation is used")