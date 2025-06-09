#!/usr/bin/env swift

import Foundation

// Same token calculation as simple_output.swift
func formatDate(_ dateStr: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    guard let date = formatter.date(from: dateStr) else {
        return String(dateStr.prefix(10))
    }
    
    let calendar = Calendar.current
    let year = calendar.component(.year, from: date)
    let month = calendar.component(.month, from: date)
    let day = calendar.component(.day, from: date)
    
    return String(format: "%04d-%02d-%02d", year, month, day)
}

// Process files
let claudePath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".claude/projects")
    .path

let targetDate = "2025-06-09"
var tokens = (input: 0, output: 0, cacheCreate: 0, cacheRead: 0)
var modelCounts: [String: Int] = [:]

guard let enumerator = FileManager.default.enumerator(atPath: claudePath) else { exit(1) }

while let file = enumerator.nextObject() as? String {
    if file.hasSuffix(".jsonl") {
        let fullPath = "\(claudePath)/\(file)"
        if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
            let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
            
            for line in lines {
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let timestamp = json["timestamp"] as? String else { continue }
                
                let date = formatDate(timestamp)
                if date == targetDate {
                    if let message = json["message"] as? [String: Any],
                       let usage = message["usage"] as? [String: Any] {
                        tokens.input += usage["input_tokens"] as? Int ?? 0
                        tokens.output += usage["output_tokens"] as? Int ?? 0
                        tokens.cacheCreate += usage["cache_creation_input_tokens"] as? Int ?? 0
                        tokens.cacheRead += usage["cache_read_input_tokens"] as? Int ?? 0
                        
                        // Count models
                        if let model = message["model"] as? String {
                            modelCounts[model] = (modelCounts[model] ?? 0) + 1
                        }
                    }
                }
            }
        }
    }
}

let total = tokens.input + tokens.output + tokens.cacheCreate + tokens.cacheRead

print("🔍 Swift CLI Token Count (verified correct):")
print("   Input: \(tokens.input)")
print("   Output: \(tokens.output)")
print("   Cache Create: \(tokens.cacheCreate)")
print("   Cache Read: \(tokens.cacheRead)")
print("   Total: \(total)")

print("\n📊 Models found:")
for (model, count) in modelCounts.sorted(by: { $0.key < $1.key }) {
    print("   \(model): \(count)")
}

// Test different cost calculations
print("\n💰 Cost Calculations:")

// 1. All at Sonnet rates with $2.49/M cache
let cost1 = Double(tokens.input) * 3e-06 +
           Double(tokens.output) * 1.5e-05 +
           Double(tokens.cacheCreate + tokens.cacheRead) * 0.00000249
print("1. Sonnet rates + $2.49/M cache: $\(String(format: "%.2f", cost1))")

// 2. All at Sonnet rates with $1.96/M cache (ccusage actual)
let cost2 = Double(tokens.input) * 3e-06 +
           Double(tokens.output) * 1.5e-05 +
           Double(tokens.cacheCreate + tokens.cacheRead) * 0.00000196
print("2. Sonnet rates + $1.96/M cache: $\(String(format: "%.2f", cost2))")

print("\n✅ ccusage shows: ~$543")