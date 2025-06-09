import Foundation

// Ultra-fast manager that keeps everything in memory
@MainActor
class UltraFastManager {
    static let shared = UltraFastManager()
    
    // Memory caches
    private var fileListCache: [String]?
    private var fileListCacheDate: Date?
    private var pricingCache: [String: ModelPricing]?
    private var pricingCacheDate: Date?
    private let fileListCacheDuration: TimeInterval = 300 // 5 minutes
    private let pricingCacheDuration: TimeInterval = 3600 // 1 hour
    
    // File watcher for real-time updates
    private var fileWatcher: DispatchSourceFileSystemObject?
    
    private init() {
        setupFileWatcher()
    }
    
    // ULTRA FAST: Get cached file list (instant return)
    func getCachedFileList() async -> [String]? {
        // Check if cache is valid
        if let cache = fileListCache,
           let cacheDate = fileListCacheDate,
           Date().timeIntervalSince(cacheDate) < fileListCacheDuration {
            return cache
        }
        
        // Return nil if cache is invalid (caller should use regular method)
        return nil
    }
    
    // Cache file list after discovery
    func cacheFileList(_ files: [String]) {
        fileListCache = files
        fileListCacheDate = Date()
    }
    
    // ULTRA FAST: Get cached pricing (instant return)
    func getCachedPricing() async -> [String: ModelPricing]? {
        // Check if cache is valid
        if let cache = pricingCache,
           let cacheDate = pricingCacheDate,
           Date().timeIntervalSince(cacheDate) < pricingCacheDuration {
            return cache
        }
        
        return nil
    }
    
    // Cache pricing after fetch
    func cachePricing(_ pricing: [String: ModelPricing]) {
        pricingCache = pricing
        pricingCacheDate = Date()
    }
    
    // Setup file watcher for real-time updates
    private func setupFileWatcher() {
        let claudePath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
        
        let fileDescriptor = open(claudePath.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global(qos: .background)
        )
        
        source.setEventHandler { [weak self] in
            // Invalidate file list cache when directory changes
            Task { @MainActor in
                self?.fileListCache = nil
                self?.fileListCacheDate = nil
                print("📁 File system changed - cache invalidated")
            }
        }
        
        source.setCancelHandler {
            close(fileDescriptor)
        }
        
        source.resume()
        fileWatcher = source
    }
    
    deinit {
        fileWatcher?.cancel()
    }
}

