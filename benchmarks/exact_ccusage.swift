#!/usr/bin/env swift

import Foundation

print("🎯 Exact ccusage Implementation")
print("===============================")

// EXACT port of ccusage's formatDate function
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

// EXACT port of ccusage's file finding logic
func findJSONLFiles(in directory: String) -> [String] {
    var files: [String] = []
    
    guard let enumerator = FileManager.default.enumerator(
        at: URL(fileURLWithPath: directory),
        includingPropertiesForKeys: nil,
        options: []
    ) else {
        return []
    }
    
    for case let fileURL as URL in enumerator {
        if fileURL.pathExtension == "jsonl" {
            files.append(fileURL.path)
        }
    }
    
    return files
}

struct UsageEntry {
    let timestamp: String
    let message: [String: Any]
}

// EXACT port of ccusage's entry processing
func parseJSONLFile(at path: String) -> [UsageEntry] {
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        return []
    }
    
    let lines = content.trimmingCharacters(in: .whitespacesAndNewlines)
        .components(separatedBy: .newlines)
        .filter { !$0.isEmpty }
    
    var entries: [UsageEntry] = []
    
    for line in lines {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let timestamp = json["timestamp"] as? String,
              let message = json["message"] as? [String: Any] else {
            continue
        }
        
        entries.append(UsageEntry(timestamp: timestamp, message: message))
    }
    
    return entries
}

// EXACT port of ccusage's loadDailyUsageData logic
let claudePath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".claude")
    .path

let claudeDir = "\(claudePath)/projects"
let files = findJSONLFiles(in: claudeDir)

print("📁 Found \(files.count) JSONL files (same as ccusage)")

// Collect all valid data entries first (EXACT ccusage logic)
var allEntries: [(data: UsageEntry, date: String)] = []

for file in files {
    let entries = parseJSONLFile(at: file)
    
    for entry in entries {
        let date = formatDate(entry.timestamp)
        allEntries.append((data: entry, date: date))
    }
}

print("📊 Total entries processed: \(allEntries.count)")

// Group by date using same logic as ccusage (Object.groupBy equivalent)
var groupedByDate: [String: [(data: UsageEntry, date: String)]] = [:]

for entry in allEntries {
    if groupedByDate[entry.date] == nil {
        groupedByDate[entry.date] = []
    }
    groupedByDate[entry.date]?.append(entry)
}

// Find today's data
let targetDate = "2025-06-09"
let todayEntries = groupedByDate[targetDate] ?? []

print("📅 Entries for \(targetDate): \(todayEntries.count)")

// Aggregate exactly like ccusage
var result = (
    inputTokens: 0,
    outputTokens: 0,
    cacheCreationTokens: 0,
    cacheReadTokens: 0
)

for entry in todayEntries {
    if let usage = entry.data.message["usage"] as? [String: Any] {
        result.inputTokens += usage["input_tokens"] as? Int ?? 0
        result.outputTokens += usage["output_tokens"] as? Int ?? 0
        result.cacheCreationTokens += usage["cache_creation_input_tokens"] as? Int ?? 0
        result.cacheReadTokens += usage["cache_read_input_tokens"] as? Int ?? 0
    }
}

let swiftTotal = result.inputTokens + result.outputTokens + result.cacheCreationTokens + result.cacheReadTokens

print("\n📊 Swift CLI Results for 2025-06-09:")
print("=====================================")
print("   Input: \(result.inputTokens)")
print("   Output: \(result.outputTokens)")
print("   Cache Creation: \(result.cacheCreationTokens)")
print("   Cache Read: \(result.cacheReadTokens)")
print("   Total: \(swiftTotal)")

print("\n✅ Processing complete!")
print("💡 Run ./compare_both.sh to compare with ccusage in real-time")