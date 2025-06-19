import Foundation

// Ultra-fast cache structure
struct UltraCachedFileData: Codable {
    let modificationDate: Date
    let entries: [UltraCachedEntry]
}

struct UltraCachedEntry: Codable {
    let date: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreateTokens: Int
    let cacheReadTokens: Int
    let costUSD: Double?
    let model: String?
    // Add deduplication fields
    let messageId: String?
    let requestId: String?
    
    // Computed property for deduplication hash
    var deduplicationHash: String? {
        guard let messageId = messageId, let requestId = requestId else { return nil }
        return "\(messageId):\(requestId)"
    }
}

// Ultra-fast two-level cache manager
class UltraCacheManager {
    static let shared = UltraCacheManager()
    
    private let cacheDir: URL
    private let memoryCache = NSCache<NSString, NSData>()
    private let dateFormatter: DateFormatter
    
    private init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        cacheDir = homeDir.appendingPathComponent(".claude_ultra_cache")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        
        // Configure memory cache
        memoryCache.countLimit = 1000
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // Pre-configured date formatter
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current
    }
    
    // Fast date extraction without DateFormatter
    func extractDate(_ dateStr: String) -> String {
        // Most timestamps are like "2024-01-01T12:34:56.789Z"
        // We just need first 10 characters
        return String(dateStr.prefix(10))
    }
    
    func extractDate(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }
    
    func getCachedData(for filePath: String) -> [UltraCachedEntry]? {
        let key = NSString(string: filePath)
        
        // Check memory cache first (nanosecond speed!)
        if let data = memoryCache.object(forKey: key),
           let cached = try? JSONDecoder().decode(UltraCachedFileData.self, from: data as Data) {
            // Verify file hasn't been modified
            if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
               let modDate = attrs[.modificationDate] as? Date,
               abs(cached.modificationDate.timeIntervalSince(modDate)) < 1.0 {
                return cached.entries
            }
        }
        
        // Check disk cache
        let cacheKey = filePath
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ".", with: "_")
            + ".cache"
        let cacheFile = cacheDir.appendingPathComponent(cacheKey)
        
        if let data = try? Data(contentsOf: cacheFile),
           let cached = try? JSONDecoder().decode(UltraCachedFileData.self, from: data) {
            // Verify file hasn't been modified
            if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
               let modDate = attrs[.modificationDate] as? Date,
               abs(cached.modificationDate.timeIntervalSince(modDate)) < 1.0 {
                // Store in memory cache for next time
                memoryCache.setObject(data as NSData, forKey: key, cost: data.count)
                return cached.entries
            } else {
                // Cache is stale, remove it
                try? FileManager.default.removeItem(at: cacheFile)
            }
        }
        
        return nil
    }
    
    func setCachedData(_ entries: [UltraCachedEntry], for filePath: String, modificationDate: Date) {
        let cached = UltraCachedFileData(modificationDate: modificationDate, entries: entries)
        
        if let data = try? JSONEncoder().encode(cached) {
            let key = NSString(string: filePath)
            
            // Store in memory cache
            memoryCache.setObject(data as NSData, forKey: key, cost: data.count)
            
            // Store on disk
            let cacheKey = filePath
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: ".", with: "_")
                + ".cache"
            let cacheFile = cacheDir.appendingPathComponent(cacheKey)
            try? data.write(to: cacheFile)
        }
    }
    
    func clearCache() {
        // Clear memory cache
        memoryCache.removeAllObjects()
        
        // Clear disk cache
        if let contents = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
            for file in contents {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
    
    func getCacheStatistics() -> (memoryCount: Int, diskSize: Int64) {
        // Memory cache count (approximate)
        let memoryCount = memoryCache.totalCostLimit > 0 ? 
            min(1000, memoryCache.totalCostLimit / 1024) : 0
        
        // Disk cache size
        var diskSize: Int64 = 0
        if let contents = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for file in contents {
                if let resourceValues = try? file.resourceValues(forKeys: [.fileSizeKey]),
                   let size = resourceValues.fileSize {
                    diskSize += Int64(size)
                }
            }
        }
        
        return (memoryCount, diskSize)
    }
}