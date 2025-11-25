import Foundation
import CommonCrypto

/// Unified cache service for AllTime app
/// Uses FileManager cachesDirectory for automatic cleanup
/// All operations are async and non-blocking
class CacheService {
    static let shared = CacheService()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    // Cache expiration: 24 hours for most data, 1 hour for real-time data
    private let defaultCacheExpiration: TimeInterval = 24 * 60 * 60 // 24 hours
    private let realtimeCacheExpiration: TimeInterval = 60 * 60 // 1 hour
    
    // Background queue for cache I/O
    private let cacheQueue = DispatchQueue(label: "com.alltime.cache", qos: .utility)
    
    private init() {
        // Use FileManager's cachesDirectory (automatically cleaned by iOS)
        let cachesPath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesPath.appendingPathComponent("AllTimeCache", isDirectory: true)
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Configure encoder/decoder
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        #if DEBUG
        print("💾 CacheService: Cache directory: \(cacheDirectory.path)")
        #endif
    }
    
    // MARK: - Cache Metadata
    
    struct CacheMetadata: Codable, Sendable {
        let lastUpdated: Date
        let dataHash: String? // Optional hash for change detection
        
        // Make Date Sendable-compatible
        enum CodingKeys: String, CodingKey {
            case lastUpdated
            case dataHash
        }
    }
    
    // MARK: - Generic Cache Operations
    
    /// Save JSON data to cache (async, non-blocking)
    func saveJSON<T: Codable>(_ object: T, filename: String, expiration: TimeInterval? = nil) async {
        let _ = expiration ?? defaultCacheExpiration
        let startTime = Date()
        
        await Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            
            do {
                let fileURL = self.cacheDirectory.appendingPathComponent("\(filename).json")
                let metadataURL = self.cacheDirectory.appendingPathComponent("\(filename).meta.json")
                
                // Create encoder/decoder in detached context
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.keyEncodingStrategy = .convertToSnakeCase
                
                // Encode data
                let data = try encoder.encode(object)
                
                // Calculate hash for change detection
                let hash = data.sha256()
                
                // Save data
                try data.write(to: fileURL, options: .atomic)
                
                // Save metadata
                let metadata = CacheMetadata(
                    lastUpdated: Date(),
                    dataHash: hash
                )
                let metadataData = try encoder.encode(metadata)
                try metadataData.write(to: metadataURL, options: .atomic)
                
                let duration = Date().timeIntervalSince(startTime)
                #if DEBUG
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB]
                formatter.countStyle = .file
                let sizeStr = formatter.string(fromByteCount: Int64(data.count))
                print("💾 CacheService: ✅ Saved \(filename) (\(sizeStr)) in \(String(format: "%.2f", duration * 1000))ms")
                #endif
            } catch {
                #if DEBUG
                print("❌ CacheService: Failed to save \(filename): \(error.localizedDescription)")
                #endif
            }
        }.value
    }
    
    /// Load JSON data from cache (async, non-blocking)
    func loadJSON<T: Codable>(_ type: T.Type, filename: String) async -> T? {
        let startTime = Date()
        let fileManager = FileManager.default
        let cacheDir = cacheDirectory
        
        return await Task.detached(priority: .userInitiated) {
            let fileURL = cacheDir.appendingPathComponent("\(filename).json")
            
            guard fileManager.fileExists(atPath: fileURL.path) else {
                #if DEBUG
                print("💾 CacheService: ❌ Cache miss: \(filename)")
                #endif
                return nil
            }
            
            do {
                let data = try Data(contentsOf: fileURL)
                
                // Create decoder in detached context
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                let object = try decoder.decode(type, from: data)
                
                let duration = Date().timeIntervalSince(startTime)
                #if DEBUG
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB]
                formatter.countStyle = .file
                let sizeStr = formatter.string(fromByteCount: Int64(data.count))
                print("💾 CacheService: ✅ Cache hit: \(filename) (\(sizeStr)) in \(String(format: "%.2f", duration * 1000))ms")
                #endif
                return object
            } catch {
                #if DEBUG
                print("❌ CacheService: Failed to load \(filename): \(error.localizedDescription)")
                #endif
                // Delete corrupted cache
                try? fileManager.removeItem(at: fileURL)
                return nil
            }
        }.value
    }
    
    /// Load JSON data from cache SYNCHRONOUSLY (for app launch - instant UI)
    /// WARNING: Only use on app launch for critical data. All other loads should use async version.
    func loadJSONSync<T: Codable>(_ type: T.Type, filename: String) -> T? {
        let startTime = Date()
        let fileURL = cacheDirectory.appendingPathComponent("\(filename).json")
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            #if DEBUG
            print("💾 CacheService: ❌ Cache miss (sync): \(filename)")
            #endif
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let object = try decoder.decode(type, from: data)
            
            let duration = Date().timeIntervalSince(startTime)
            #if DEBUG
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB]
            formatter.countStyle = .file
            let sizeStr = formatter.string(fromByteCount: Int64(data.count))
            print("💾 CacheService: ✅ Cache hit (sync): \(filename) (\(sizeStr)) in \(String(format: "%.2f", duration * 1000))ms")
            #endif
            return object
        } catch {
            #if DEBUG
            print("❌ CacheService: Failed to load \(filename) (sync): \(error.localizedDescription)")
            #endif
            // Delete corrupted cache
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
    }
    
    /// Check if cache file exists
    func exists(filename: String) -> Bool {
        let fileURL = cacheDirectory.appendingPathComponent("\(filename).json")
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Delete cache file
    func delete(filename: String) async {
        let fileManager = FileManager.default
        await Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            
            let fileURL = self.cacheDirectory.appendingPathComponent("\(filename).json")
            let metadataURL = self.cacheDirectory.appendingPathComponent("\(filename).meta.json")
            
            try? fileManager.removeItem(at: fileURL)
            try? fileManager.removeItem(at: metadataURL)
            
            #if DEBUG
            print("💾 CacheService: ✅ Deleted \(filename)")
            #endif
        }.value
    }
    
    /// Check if cache is valid (not expired)
    func isCacheValid(filename: String, expiration: TimeInterval? = nil) async -> Bool {
        let expiration = expiration ?? defaultCacheExpiration
        let fileManager = FileManager.default
        
        return await Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return false }
            
            let metadataURL = self.cacheDirectory.appendingPathComponent("\(filename).meta.json")
            
            guard fileManager.fileExists(atPath: metadataURL.path) else {
                return false
            }
            
            do {
                let data = try Data(contentsOf: metadataURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let metadata = try decoder.decode(CacheMetadata.self, from: data)
                
                let timeSinceUpdate = Date().timeIntervalSince(metadata.lastUpdated)
                return timeSinceUpdate < expiration
            } catch {
                return false
            }
        }.value
    }
    
    /// Get cache metadata
    func getCacheMetadata(filename: String) async -> CacheMetadata? {
        let fileManager = FileManager.default
        return await Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return nil }
            
            let metadataURL = self.cacheDirectory.appendingPathComponent("\(filename).meta.json")
            
            guard fileManager.fileExists(atPath: metadataURL.path) else {
                return nil
            }
            
            do {
                let data = try Data(contentsOf: metadataURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                return try decoder.decode(CacheMetadata.self, from: data)
            } catch {
                return nil
            }
        }.value
    }
    
    // MARK: - Calendar Events Cache
    
    /// Cache events by month (key: "events_YYYY-MM")
    func cacheEvents(_ events: [Event], for month: Date) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let key = "events_\(formatter.string(from: month))"
        await saveJSON(events, filename: key, expiration: defaultCacheExpiration)
    }
    
    /// Load cached events for month
    func loadCachedEvents(for month: Date) async -> [Event]? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let key = "events_\(formatter.string(from: month))"
        return await loadJSON([Event].self, filename: key)
    }
    
    // MARK: - Health Insights Cache
    
    /// Cache 1-day health insights (key: "health_insights_YYYY-MM-DD")
    func cacheHealthInsights(_ insights: HealthInsightsResponse, for date: Date) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = "health_insights_\(formatter.string(from: date))"
        await saveJSON(insights, filename: key, expiration: realtimeCacheExpiration)
    }
    
    /// Load cached 1-day health insights
    func loadCachedHealthInsights(for date: Date) async -> HealthInsightsResponse? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = "health_insights_\(formatter.string(from: date))"
        return await loadJSON(HealthInsightsResponse.self, filename: key)
    }
    
    /// Cache 7-day health insights (key: "health_insights_7d_YYYY-MM-DD")
    func cacheHealthInsights7Day(_ insights: HealthInsightsResponse, startDate: Date, endDate: Date) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = "health_insights_7d_\(formatter.string(from: startDate))_\(formatter.string(from: endDate))"
        await saveJSON(insights, filename: key, expiration: defaultCacheExpiration)
    }
    
    /// Load cached 7-day health insights
    func loadCachedHealthInsights7Day(startDate: Date, endDate: Date) async -> HealthInsightsResponse? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = "health_insights_7d_\(formatter.string(from: startDate))_\(formatter.string(from: endDate))"
        return await loadJSON(HealthInsightsResponse.self, filename: key)
    }
    
    // MARK: - Life Wheel Cache
    
    /// Cache life wheel insights (key: "life_wheel_YYYY-MM-DD_YYYY-MM-DD")
    func cacheLifeWheel(_ lifeWheel: LifeWheelResponse, startDate: Date, endDate: Date) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = "life_wheel_\(formatter.string(from: startDate))_\(formatter.string(from: endDate))"
        await saveJSON(lifeWheel, filename: key, expiration: defaultCacheExpiration)
    }
    
    /// Load cached life wheel insights
    func loadCachedLifeWheel(startDate: Date, endDate: Date) async -> LifeWheelResponse? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = "life_wheel_\(formatter.string(from: startDate))_\(formatter.string(from: endDate))"
        return await loadJSON(LifeWheelResponse.self, filename: key)
    }
    
    // MARK: - Timeline Cache
    
    /// Cache timeline for a day (key: "timeline_YYYY-MM-DD")
    func cacheTimeline(_ timeline: TimelineDayResponse, for date: Date) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = "timeline_\(formatter.string(from: date))"
        await saveJSON(timeline, filename: key, expiration: realtimeCacheExpiration)
    }
    
    /// Load cached timeline for a day
    func loadCachedTimeline(for date: Date) async -> TimelineDayResponse? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = "timeline_\(formatter.string(from: date))"
        return await loadJSON(TimelineDayResponse.self, filename: key)
    }
    
    // MARK: - Daily Summary Cache
    
    /// Cache daily summary (key: "daily_summary_YYYY-MM-DD")
    func cacheDailySummary(_ summary: EnhancedDailySummaryResponse, for date: Date) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = "daily_summary_\(formatter.string(from: date))"
        await saveJSON(summary, filename: key, expiration: realtimeCacheExpiration)
    }
    
    /// Load cached daily summary
    func loadCachedDailySummary(for date: Date) async -> EnhancedDailySummaryResponse? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = "daily_summary_\(formatter.string(from: date))"
        return await loadJSON(EnhancedDailySummaryResponse.self, filename: key)
    }
    
    // MARK: - Cache Management
    
    /// Clear all cache
    func clearAllCache() async {
        let fileManager = FileManager.default
        await Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            
            do {
                let files = try fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: nil)
                for file in files {
                    try? fileManager.removeItem(at: file)
                }
                #if DEBUG
                print("💾 CacheService: ✅ Cleared all cache")
                #endif
            } catch {
                #if DEBUG
                print("❌ CacheService: Failed to clear cache: \(error.localizedDescription)")
                #endif
            }
        }.value
    }
    
    /// Get total cache size
    func getCacheSize() async -> Int64 {
        let fileManager = FileManager.default
        return await Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return 0 }
            
            var totalSize: Int64 = 0
            
            do {
                let files = try fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
                for file in files {
                    if let attributes = try? file.resourceValues(forKeys: [.fileSizeKey]),
                       let size = attributes.fileSize {
                        totalSize += Int64(size)
                    }
                }
            } catch {
                // Ignore errors
            }
            
            return totalSize
        }.value
    }
}

// MARK: - Data Extension for Hash

extension Data {
    nonisolated func sha256() -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.baseAddress, CC_LONG(self.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

