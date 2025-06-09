import Foundation

// Cache structure for parsed file data
struct CachedFileData: Codable {
    let modificationDate: Date
    let entries: [CachedEntry]
}

struct CachedEntry: Codable {
    let date: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreateTokens: Int
    let cacheReadTokens: Int
    let costUSD: Double?
    let model: String?
}

// Cache manager for usage data
class UsageCacheManager {
    static let shared = UsageCacheManager()
    private let cacheDir: URL
    
    private init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        cacheDir = homeDir.appendingPathComponent(".claude_usage_cache")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
    
    private func cacheKey(for filePath: String) -> String {
        // Create a safe filename from the path
        return filePath
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ".", with: "_")
            + ".cache"
    }
    
    func getCachedData(for filePath: String) -> CachedFileData? {
        let key = cacheKey(for: filePath)
        let cacheFile = cacheDir.appendingPathComponent(key)
        
        guard let data = try? Data(contentsOf: cacheFile),
              let cached = try? JSONDecoder().decode(CachedFileData.self, from: data) else {
            return nil
        }
        
        // Check if file has been modified since cache was created
        if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
           let modDate = attrs[.modificationDate] as? Date,
           abs(modDate.timeIntervalSince(cached.modificationDate)) < 1.0 { // Allow 1 second tolerance
            return cached
        }
        
        // Cache is stale, remove it
        try? FileManager.default.removeItem(at: cacheFile)
        return nil
    }
    
    func setCachedData(_ data: CachedFileData, for filePath: String) {
        let key = cacheKey(for: filePath)
        let cacheFile = cacheDir.appendingPathComponent(key)
        
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: cacheFile)
        }
    }
    
    func clearCache() {
        // Remove all cache files
        if let contents = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
            for file in contents {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
    
    func cacheSize() -> Int64 {
        var totalSize: Int64 = 0
        if let contents = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for file in contents {
                if let resourceValues = try? file.resourceValues(forKeys: [.fileSizeKey]),
                   let size = resourceValues.fileSize {
                    totalSize += Int64(size)
                }
            }
        }
        return totalSize
    }
}