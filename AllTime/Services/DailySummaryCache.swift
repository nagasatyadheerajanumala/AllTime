import Foundation

/// Caching service for AI-generated daily summaries
/// Implements the caching strategy recommended in the API documentation
class DailySummaryCache {
    static let shared = DailySummaryCache()

    private init() {}

    // MARK: - Cache Storage

    private var cache: [String: CachedSummary] = [:]
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour

    private struct CachedSummary {
        let summary: DailySummary
        let cachedAt: Date

        var isValid: Bool {
            Date().timeIntervalSince(cachedAt) < 3600 // 1 hour validity
        }
    }

    // MARK: - Public API

    /// Get cached summary for a specific date
    func getCachedSummary(for date: Date) -> DailySummary? {
        let key = cacheKey(for: date)

        guard let cached = cache[key] else {
            print("💾 DailySummaryCache: No cache found for \(formatDate(date))")
            return nil
        }

        if cached.isValid {
            print("💾 DailySummaryCache: ✅ Cache HIT for \(formatDate(date)) (age: \(Int(Date().timeIntervalSince(cached.cachedAt)))s)")
            return cached.summary
        } else {
            print("💾 DailySummaryCache: ⏰ Cache EXPIRED for \(formatDate(date)) (age: \(Int(Date().timeIntervalSince(cached.cachedAt)))s)")
            cache.removeValue(forKey: key)
            return nil
        }
    }

    /// Cache a summary for a specific date
    func cacheSummary(_ summary: DailySummary, for date: Date) {
        let key = cacheKey(for: date)
        cache[key] = CachedSummary(summary: summary, cachedAt: Date())

        print("💾 DailySummaryCache: ✅ Cached summary for \(formatDate(date))")
        print("💾 DailySummaryCache: Cache size: \(cache.count) entries")

        // Schedule automatic expiration cleanup
        scheduleExpiration(for: key)
    }

    /// Invalidate cache for a specific date
    func invalidate(for date: Date) {
        let key = cacheKey(for: date)
        cache.removeValue(forKey: key)
        print("💾 DailySummaryCache: ❌ Invalidated cache for \(formatDate(date))")
    }

    /// Invalidate all cached summaries
    func invalidateAll() {
        let count = cache.count
        cache.removeAll()
        print("💾 DailySummaryCache: ❌ Invalidated ALL cache (\(count) entries)")
    }

    /// Invalidate cache for today (useful after calendar or health sync)
    func invalidateToday() {
        invalidate(for: Date())
    }

    /// Check if we have a valid cache for a date
    func hasValidCache(for date: Date) -> Bool {
        getCachedSummary(for: date) != nil
    }

    // MARK: - Private Helpers

    private func cacheKey(for date: Date) -> String {
        return formatDate(date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    private func scheduleExpiration(for key: String) {
        // Remove from cache after expiration interval
        DispatchQueue.main.asyncAfter(deadline: .now() + cacheExpirationInterval) { [weak self] in
            self?.cache.removeValue(forKey: key)
            print("💾 DailySummaryCache: ⏰ Auto-expired cache for key: \(key)")
        }
    }

    // MARK: - Cache Management

    /// Clean up expired entries
    func cleanupExpiredEntries() {
        let beforeCount = cache.count
        cache = cache.filter { $0.value.isValid }
        let removedCount = beforeCount - cache.count

        if removedCount > 0 {
            print("💾 DailySummaryCache: 🧹 Cleaned up \(removedCount) expired entries")
        }
    }

    /// Get cache statistics for debugging
    func getCacheStats() -> String {
        let validCount = cache.values.filter { $0.isValid }.count
        let expiredCount = cache.count - validCount
        let oldestEntry = cache.values.map { $0.cachedAt }.min()
        let newestEntry = cache.values.map { $0.cachedAt }.max()

        var stats = "Cache Stats:\n"
        stats += "  Total entries: \(cache.count)\n"
        stats += "  Valid entries: \(validCount)\n"
        stats += "  Expired entries: \(expiredCount)\n"

        if let oldest = oldestEntry {
            let age = Int(Date().timeIntervalSince(oldest))
            stats += "  Oldest entry: \(age)s ago\n"
        }

        if let newest = newestEntry {
            let age = Int(Date().timeIntervalSince(newest))
            stats += "  Newest entry: \(age)s ago\n"
        }

        return stats
    }
}
