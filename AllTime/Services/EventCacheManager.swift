import Foundation

/// Manages local caching of calendar events for offline support and fast UI
/// Cache operations are optimized for performance - I/O happens on background threads
class EventCacheManager {
    static let shared = EventCacheManager()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let eventsCacheFile: URL
    private let cacheMetadataFile: URL
    
    // Cache expiration: 15 minutes
    private let cacheExpirationInterval: TimeInterval = 15 * 60
    
    private init() {
        // Get cache directory in Documents
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("EventCache", isDirectory: true)
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        eventsCacheFile = cacheDirectory.appendingPathComponent("events.json")
        cacheMetadataFile = cacheDirectory.appendingPathComponent("cache_metadata.json")
        
        #if DEBUG
        print("💾 EventCacheManager: Cache directory: \(cacheDirectory.path)")
        #endif
    }
    
    // MARK: - Cache Metadata
    
    struct CacheMetadata: Codable {
        let lastUpdated: Date
        let eventsCount: Int
        let daysFetched: Int
    }
    
    // MARK: - Save Events
    
    /// Save events to local cache (background thread)
    func saveEvents(_ events: [Event], daysFetched: Int) {
        // Move cache I/O to background queue
        Task.detached(priority: .utility) {
            do {
                // Save events
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let eventsData = try encoder.encode(events)
                try eventsData.write(to: self.eventsCacheFile, options: .atomic)
                
                // Save metadata
                let metadata = CacheMetadata(
                    lastUpdated: Date(),
                    eventsCount: events.count,
                    daysFetched: daysFetched
                )
                let metadataData = try encoder.encode(metadata)
                try metadataData.write(to: self.cacheMetadataFile, options: .atomic)
                
                #if DEBUG
                print("💾 EventCacheManager: ✅ Saved \(events.count) events to cache")
                #endif
            } catch {
                #if DEBUG
                print("❌ EventCacheManager: Failed to save cache: \(error.localizedDescription)")
                #endif
            }
        }
    }
    
    // MARK: - Load Events
    
    /// Load events from local cache (optimized - decode on background if large)
    func loadEvents() -> [Event]? {
        guard fileManager.fileExists(atPath: eventsCacheFile.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: eventsCacheFile)
            
            // Decode JSON (usually fast, but do it synchronously for immediate UI)
            // For very large caches (>1MB), this might take a moment, but it's rare
            // Note: CalendarEvent uses explicit CodingKeys, so keyDecodingStrategy is not needed
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([Event].self, from: data)
        } catch {
            #if DEBUG
            print("❌ EventCacheManager: Failed to load cache: \(error.localizedDescription)")
            #endif
            // If cache is corrupted, delete it
            try? fileManager.removeItem(at: eventsCacheFile)
            return nil
        }
    }
    
    // MARK: - Cache Metadata
    
    /// Get cache metadata
    func getCacheMetadata() -> CacheMetadata? {
        guard fileManager.fileExists(atPath: cacheMetadataFile.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: cacheMetadataFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(CacheMetadata.self, from: data)
        } catch {
            print("❌ EventCacheManager: Failed to load cache metadata: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Cache Validation
    
    /// Check if cache is valid (not expired)
    func isCacheValid() -> Bool {
        guard let metadata = getCacheMetadata() else {
            return false
        }
        
        let timeSinceUpdate = Date().timeIntervalSince(metadata.lastUpdated)
        return timeSinceUpdate < cacheExpirationInterval
    }
    
    /// Check if cache exists and has data
    func hasCache() -> Bool {
        guard let metadata = getCacheMetadata() else {
            return false
        }
        return metadata.eventsCount > 0
    }
    
    // MARK: - Cache Management
    
    /// Clear all cached data
    func clearCache() {
        do {
            if fileManager.fileExists(atPath: eventsCacheFile.path) {
                try fileManager.removeItem(at: eventsCacheFile)
            }
            if fileManager.fileExists(atPath: cacheMetadataFile.path) {
                try fileManager.removeItem(at: cacheMetadataFile)
            }
            #if DEBUG
            print("💾 EventCacheManager: ✅ Cache cleared")
            #endif
        } catch {
            #if DEBUG
            print("❌ EventCacheManager: Failed to clear cache: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// Get cache size in bytes
    func getCacheSize() -> Int64 {
        var totalSize: Int64 = 0
        
        if let attributes = try? fileManager.attributesOfItem(atPath: eventsCacheFile.path),
           let size = attributes[.size] as? Int64 {
            totalSize += size
        }
        
        if let attributes = try? fileManager.attributesOfItem(atPath: cacheMetadataFile.path),
           let size = attributes[.size] as? Int64 {
            totalSize += size
        }
        
        return totalSize
    }
    
    /// Get human-readable cache size
    func getCacheSizeString() -> String {
        let size = getCacheSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}


