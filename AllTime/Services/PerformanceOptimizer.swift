import Foundation
import os.signpost

// MARK: - Performance Configuration
/// Global performance settings - adjust for testing
struct PerformanceConfig {
    /// In-memory cache TTL (seconds) - how long to trust cached data before background refresh
    static var memoryCacheTTL: TimeInterval = 60 // 1 minute

    /// Stale data TTL - how long to show stale data while refreshing (longer than memoryCacheTTL)
    static var staleCacheTTL: TimeInterval = 300 // 5 minutes

    /// Disk cache TTL
    static var diskCacheTTL: TimeInterval = 3600 // 1 hour

    /// Enable performance logging
    static var enableLogging = true

    /// Enable signpost profiling (for Instruments)
    static var enableSignposts = true
}

// MARK: - Performance Logger
/// Lightweight performance logging with signposts for Instruments
final class PerformanceLogger {
    static let shared = PerformanceLogger()

    private let log = OSLog(subsystem: "com.alltime", category: "Performance")
    private let signpostLog = OSLog(subsystem: "com.alltime", category: .pointsOfInterest)

    private init() {}

    /// Log tab switch timing
    func logTabSwitch(from: String, to: String) {
        guard PerformanceConfig.enableLogging else { return }
        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "TabSwitch", signpostID: signpostID, "%{public}s -> %{public}s", from, to)
    }

    func logTabSwitchEnd(to: String, ttfr: TimeInterval) {
        guard PerformanceConfig.enableLogging else { return }
        #if DEBUG
        print("⚡️ PERF: Tab '\(to)' TTFR: \(String(format: "%.1f", ttfr * 1000))ms")
        #endif
    }

    /// Log API call
    func logAPICall(endpoint: String, cached: Bool, duration: TimeInterval) {
        guard PerformanceConfig.enableLogging else { return }
        #if DEBUG
        let cacheStatus = cached ? "CACHE HIT" : "NETWORK"
        print("⚡️ PERF: [\(cacheStatus)] \(endpoint) in \(String(format: "%.1f", duration * 1000))ms")
        #endif
    }

    /// Log cache operation
    func logCacheOp(_ operation: String, key: String, hit: Bool) {
        guard PerformanceConfig.enableLogging else { return }
        #if DEBUG
        print("⚡️ CACHE: \(operation) '\(key)' - \(hit ? "HIT" : "MISS")")
        #endif
    }

    /// Track time to first render
    func measureTTFR<T>(name: String, operation: () async throws -> T) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let duration = CFAbsoluteTimeGetCurrent() - start
        logTabSwitchEnd(to: name, ttfr: duration)
        return result
    }
}

// MARK: - In-Memory Cache (Actor for thread safety)
/// Ultra-fast in-memory cache with TTL support
actor InMemoryCache {
    static let shared = InMemoryCache()

    private struct CacheEntry<T> {
        let value: T
        let timestamp: Date
        let ttl: TimeInterval

        var isValid: Bool {
            Date().timeIntervalSince(timestamp) < ttl
        }

        var isStale: Bool {
            let age = Date().timeIntervalSince(timestamp)
            return age >= ttl && age < PerformanceConfig.staleCacheTTL
        }
    }

    // Type-erased storage
    private var storage: [String: Any] = [:]
    private var timestamps: [String: Date] = [:]
    private var ttls: [String: TimeInterval] = [:]

    /// Get cached value (instant, no I/O)
    func get<T>(_ key: String) -> T? {
        guard let entry = storage[key],
              let timestamp = timestamps[key],
              let ttl = ttls[key] else {
            PerformanceLogger.shared.logCacheOp("GET", key: key, hit: false)
            return nil
        }

        let age = Date().timeIntervalSince(timestamp)

        // Return if valid or stale (stale-while-revalidate)
        if age < PerformanceConfig.staleCacheTTL {
            PerformanceLogger.shared.logCacheOp("GET", key: key, hit: true)
            return entry as? T
        }

        // Expired - remove and return nil
        storage.removeValue(forKey: key)
        timestamps.removeValue(forKey: key)
        ttls.removeValue(forKey: key)
        PerformanceLogger.shared.logCacheOp("GET", key: key, hit: false)
        return nil
    }

    /// Check if cache needs refresh (valid but stale)
    func needsRefresh(_ key: String) -> Bool {
        guard let timestamp = timestamps[key],
              let ttl = ttls[key] else {
            return true
        }
        let age = Date().timeIntervalSince(timestamp)
        return age >= ttl
    }

    /// Set cached value
    func set<T>(_ key: String, value: T, ttl: TimeInterval = PerformanceConfig.memoryCacheTTL) {
        storage[key] = value
        timestamps[key] = Date()
        ttls[key] = ttl
        PerformanceLogger.shared.logCacheOp("SET", key: key, hit: true)
    }

    /// Remove cached value
    func remove(_ key: String) {
        storage.removeValue(forKey: key)
        timestamps.removeValue(forKey: key)
        ttls.removeValue(forKey: key)
    }

    /// Clear all cache
    func clear() {
        storage.removeAll()
        timestamps.removeAll()
        ttls.removeAll()
    }

    /// Get cache stats
    func stats() -> (count: Int, keys: [String]) {
        return (storage.count, Array(storage.keys))
    }
}

// MARK: - Request De-duplicator
/// Prevents duplicate in-flight requests to the same endpoint
actor RequestDeduplicator {
    static let shared = RequestDeduplicator()

    private var inFlightRequests: [String: Task<Any, Error>] = [:]

    /// Execute request with de-duplication
    /// If same request is already in-flight, returns its result instead of making new request
    func dedupe<T>(
        key: String,
        request: @escaping () async throws -> T
    ) async throws -> T {
        // Check if request is already in flight
        if let existingTask = inFlightRequests[key] {
            #if DEBUG
            print("⚡️ DEDUPE: Reusing in-flight request for '\(key)'")
            #endif
            // Wait for existing request
            let result = try await existingTask.value
            if let typedResult = result as? T {
                return typedResult
            }
        }

        // Create new task
        let task = Task<Any, Error> {
            try await request()
        }

        inFlightRequests[key] = task

        defer {
            // Clean up after completion
            Task { await self.removeRequest(key) }
        }

        let result = try await task.value
        guard let typedResult = result as? T else {
            throw NSError(domain: "RequestDeduplicator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Type mismatch"])
        }
        return typedResult
    }

    private func removeRequest(_ key: String) {
        inFlightRequests.removeValue(forKey: key)
    }

    /// Cancel all in-flight requests (call on logout or app termination)
    func cancelAll() {
        for (_, task) in inFlightRequests {
            task.cancel()
        }
        inFlightRequests.removeAll()
    }
}

// MARK: - Cancellable Task Manager
/// Manages tasks that should be cancelled when view disappears
@MainActor
final class TaskManager {
    private var tasks: [String: Task<Void, Never>] = [:]

    /// Run a cancellable task
    func run(_ id: String, priority: _Concurrency.TaskPriority = .high, operation: @escaping () async -> Void) {
        // Cancel existing task with same ID
        tasks[id]?.cancel()

        tasks[id] = Task(priority: priority) {
            await operation()
        }
    }

    /// Cancel a specific task
    func cancel(_ id: String) {
        tasks[id]?.cancel()
        tasks.removeValue(forKey: id)
    }

    /// Cancel all tasks (call in onDisappear)
    func cancelAll() {
        for (_, task) in tasks {
            task.cancel()
        }
        tasks.removeAll()
    }

    deinit {
        for (_, task) in tasks {
            task.cancel()
        }
    }
}

// MARK: - Stale-While-Revalidate Helper
/// Helper for implementing stale-while-revalidate pattern
struct StaleWhileRevalidate<T> {
    let cacheKey: String
    let fetch: () async throws -> T
    let cache: InMemoryCache

    init(cacheKey: String, cache: InMemoryCache = .shared, fetch: @escaping () async throws -> T) {
        self.cacheKey = cacheKey
        self.fetch = fetch
        self.cache = cache
    }

    /// Get data with stale-while-revalidate
    /// Returns cached data immediately, refreshes in background if stale
    func get(forceRefresh: Bool = false, onUpdate: @escaping (T) -> Void) async throws -> T {
        // 1. Try to get from cache first (instant)
        if !forceRefresh, let cached: T = await cache.get(cacheKey) {
            let needsRefresh = await cache.needsRefresh(cacheKey)

            // Return cached immediately
            onUpdate(cached)

            // If stale, refresh in background
            if needsRefresh {
                Task.detached(priority: .utility) { [self] in
                    do {
                        let fresh = try await self.fetch()
                        await self.cache.set(self.cacheKey, value: fresh)
                        await MainActor.run {
                            onUpdate(fresh)
                        }
                    } catch {
                        // Silently fail - we already have cached data
                        #if DEBUG
                        print("⚠️ Background refresh failed for \(cacheKey): \(error.localizedDescription)")
                        #endif
                    }
                }
            }

            return cached
        }

        // 2. No cache - fetch fresh
        let fresh = try await fetch()
        await cache.set(cacheKey, value: fresh)
        onUpdate(fresh)
        return fresh
    }
}

// MARK: - Performance Report
/// Generate performance report for debugging
struct PerformanceReport {
    static func generate() async -> String {
        let cacheStats = await InMemoryCache.shared.stats()

        var report = """
        ========== PERFORMANCE REPORT ==========
        In-Memory Cache:
          - Entries: \(cacheStats.count)
          - Keys: \(cacheStats.keys.joined(separator: ", "))

        Configuration:
          - Memory Cache TTL: \(PerformanceConfig.memoryCacheTTL)s
          - Stale Cache TTL: \(PerformanceConfig.staleCacheTTL)s
          - Disk Cache TTL: \(PerformanceConfig.diskCacheTTL)s
        ========================================
        """

        return report
    }
}
