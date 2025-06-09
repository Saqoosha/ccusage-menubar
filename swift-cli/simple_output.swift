#!/usr/bin/env swift

import Foundation

// Same ccusage implementation but with simple output
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

// Main execution
let claudePath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".claude")
    .path

let claudeDir = "\(claudePath)/projects"
let files = findJSONLFiles(in: claudeDir)

var allEntries: [(data: UsageEntry, date: String)] = []

for file in files {
    let entries = parseJSONLFile(at: file)
    
    for entry in entries {
        let date = formatDate(entry.timestamp)
        allEntries.append((data: entry, date: date))
    }
}

// Group by date
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

let total = result.inputTokens + result.outputTokens + result.cacheCreationTokens + result.cacheReadTokens

// Check command line argument for output format
let args = CommandLine.arguments
let useJsonOutput = args.contains("--json") || args.contains("-j")

if useJsonOutput {
    // ccusage-compatible JSON format
    let jsonOutput = [
        "daily": [[
            "date": targetDate,
            "inputTokens": result.inputTokens,
            "outputTokens": result.outputTokens,
            "cacheCreationTokens": result.cacheCreationTokens,
            "cacheReadTokens": result.cacheReadTokens,
            "totalTokens": total,
            "totalCost": 0 // Not calculating cost in this version
        ]]
    ] as [String : Any]
    
    if let jsonData = try? JSONSerialization.data(withJSONObject: jsonOutput, options: .prettyPrinted),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        print(jsonString)
    }
} else {
    // Human-readable format
    print("SWIFT_CLI_RESULT")
    print("Date: \(targetDate)")
    print("Input: \(result.inputTokens)")
    print("Output: \(result.outputTokens)")
    print("Cache_Create: \(result.cacheCreationTokens)")
    print("Cache_Read: \(result.cacheReadTokens)")
    print("Total: \(total)")
}