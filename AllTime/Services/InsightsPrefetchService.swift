import Foundation

/// Service that prefetches all app data in the background
/// so it's available instantly when users navigate to any screen.
///
/// This runs after sign-in and on app foreground to keep data fresh.
@MainActor
class InsightsPrefetchService {
    static let shared = InsightsPrefetchService()

    private let apiService = APIService.shared
    private let cacheService = CacheService.shared

    /// Track if prefetch is already running to avoid duplicate calls
    private var isPrefetching = false

    /// Last prefetch time to avoid too frequent calls
    private var lastPrefetchTime: Date?

    /// Minimum interval between prefetches (5 minutes)
    private let minPrefetchInterval: TimeInterval = 300

    private init() {}

    // MARK: - Public API

    /// Prefetch all app data in parallel.
    /// Called after sign-in and on app foreground.
    func prefetchAllInsights() async {
        // Avoid duplicate prefetches
        guard !isPrefetching else {
            print("📊 Prefetch: Already prefetching, skipping...")
            return
        }

        // Check if we prefetched recently
        if let lastTime = lastPrefetchTime,
           Date().timeIntervalSince(lastTime) < minPrefetchInterval {
            print("📊 Prefetch: Prefetched recently, skipping...")
            return
        }

        isPrefetching = true
        lastPrefetchTime = Date()

        print("📊 Prefetch: ===== STARTING BACKGROUND PREFETCH =====")

        // Run all prefetches in parallel for efficiency
        await withTaskGroup(of: Void.self) { group in
            // Today screen data
            group.addTask {
                await self.prefetchDailyBriefing()
            }

            // Health data
            group.addTask {
                await self.prefetchHealthSummary()
            }

            // Insights data
            group.addTask {
                await self.prefetchWeeklyInsights()
            }

            group.addTask {
                await self.prefetchLifeInsights()
            }

            group.addTask {
                await self.prefetchCapacityAnalysis()
            }

            group.addTask {
                await self.prefetchAvailableWeeks()
            }

            group.addTask {
                await self.prefetchHealthInsights()
            }
        }

        isPrefetching = false
        print("📊 Prefetch: ===== ALL PREFETCHES COMPLETE =====")
    }

    /// Force prefetch regardless of timing (used by refresh buttons)
    func forcePrefetch() async {
        lastPrefetchTime = nil
        await prefetchAllInsights()
    }

    // MARK: - Today Screen Data

    /// Prefetch daily briefing for Today screen
    private func prefetchDailyBriefing() async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cacheKey = "daily_briefing_\(formatter.string(from: Date()))"

        // Check if cache is still valid (30 min expiration)
        if let metadata = cacheService.getCacheMetadataSync(filename: cacheKey),
           Date().timeIntervalSince(metadata.lastUpdated) < 1800 {
            print("📊 Prefetch: Daily briefing cache still valid")
            return
        }

        do {
            print("📊 Prefetch: Fetching daily briefing...")

            guard let token = KeychainManager.shared.getAccessToken() else {
                print("📊 Prefetch: ⚠️ No access token for daily briefing")
                return
            }

            let timezone = TimeZone.current.identifier
            let encodedTimezone = timezone.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? timezone

            guard let url = URL(string: "\(Constants.API.baseURL)/api/v1/today/briefing?timezone=\(encodedTimezone)") else {
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 30

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("📊 Prefetch: ⚠️ Daily briefing fetch failed with non-200 status")
                return
            }

            let briefingResponse = try JSONDecoder().decode(DailyBriefingResponse.self, from: data)
            cacheService.saveJSONSync(briefingResponse, filename: cacheKey, expiration: 24 * 60 * 60)

            print("📊 Prefetch: ✅ Daily briefing cached")
        } catch {
            print("📊 Prefetch: ⚠️ Daily briefing prefetch failed: \(error.localizedDescription)")
        }
    }

    /// Prefetch health summary data
    private func prefetchHealthSummary() async {
        let filename = "health_summary"

        // Check if cache is still valid (30 min)
        if let metadata = cacheService.getCacheMetadataSync(filename: filename),
           Date().timeIntervalSince(metadata.lastUpdated) < 1800 {
            print("📊 Prefetch: Health summary cache still valid")
            return
        }

        do {
            print("📊 Prefetch: Fetching health summary...")
            if let response = try await apiService.getHealthSummary() {
                cacheService.saveJSONSync(response, filename: filename, expiration: 1800)
                print("📊 Prefetch: ✅ Health summary cached")
            }
        } catch {
            print("📊 Prefetch: ⚠️ Health summary prefetch failed: \(error.localizedDescription)")
        }
    }

    /// Prefetch health insights data (7 day range)
    private func prefetchHealthInsights() async {
        // Use the same cache key format as HealthInsightsDetailView
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: endDate) else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cacheKey = "health_insights_\(formatter.string(from: startDate))_\(formatter.string(from: endDate))"

        // Check if cache is still valid (30 min)
        if let metadata = cacheService.getCacheMetadataSync(filename: cacheKey),
           Date().timeIntervalSince(metadata.lastUpdated) < 1800 {
            print("📊 Prefetch: Health insights cache still valid")
            return
        }

        do {
            print("📊 Prefetch: Fetching health insights...")
            let response = try await apiService.fetchHealthInsights(startDate: startDate, endDate: endDate)
            cacheService.saveJSONSync(response, filename: cacheKey, expiration: 1800)
            print("📊 Prefetch: ✅ Health insights cached")
        } catch {
            print("📊 Prefetch: ⚠️ Health insights prefetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Individual Prefetches

    /// Prefetch weekly narrative insights for the current week
    private func prefetchWeeklyInsights() async {
        let weekStart = currentWeekStart
        let cacheKey = "weekly_narrative_\(weekStart)"

        // Check if cache is still valid (30 min expiration)
        if let metadata = cacheService.getCacheMetadataSync(filename: cacheKey),
           Date().timeIntervalSince(metadata.lastUpdated) < 1800 {
            print("📊 InsightsPrefetch: Weekly narrative cache still valid")
            return
        }

        do {
            print("📊 InsightsPrefetch: Fetching weekly narrative insights...")
            let response = try await apiService.getWeeklyNarrativeInsights(weekStart: weekStart)

            // Cache with same key as WeeklyNarrativeViewModel expects
            cacheService.saveJSONSync(response, filename: cacheKey, expiration: 1800)

            print("📊 InsightsPrefetch: ✅ Weekly narrative insights cached")
        } catch {
            print("📊 InsightsPrefetch: ⚠️ Weekly narrative prefetch failed: \(error.localizedDescription)")
        }
    }

    /// Prefetch life insights (30 day mode)
    private func prefetchLifeInsights() async {
        let filename = "life_insights_30day"

        // Check if cache is still valid (1 hour expiration)
        if let metadata = cacheService.getCacheMetadataSync(filename: filename),
           Date().timeIntervalSince(metadata.lastUpdated) < 3600 {
            print("📊 InsightsPrefetch: Life insights cache still valid")
            return
        }

        do {
            print("📊 InsightsPrefetch: Fetching life insights...")
            let response = try await apiService.getLifeInsights(mode: "30day")

            // Cache with same key as LifeInsightsViewModel expects
            cacheService.saveJSONSync(response, filename: filename, expiration: 3600)

            print("📊 InsightsPrefetch: ✅ Life insights cached")
        } catch {
            print("📊 InsightsPrefetch: ⚠️ Life insights prefetch failed: \(error.localizedDescription)")
        }
    }

    /// Prefetch capacity analysis for insights preview card
    private func prefetchCapacityAnalysis() async {
        let filename = "capacity_analysis"

        // Check if cache is still valid (30 min expiration)
        if let metadata = cacheService.getCacheMetadataSync(filename: filename),
           Date().timeIntervalSince(metadata.lastUpdated) < 1800 {
            print("📊 InsightsPrefetch: Capacity analysis cache still valid")
            return
        }

        do {
            print("📊 InsightsPrefetch: Fetching capacity analysis...")
            let response = try await apiService.getCapacityAnalysis(days: 30)

            // Cache for InsightsPreviewCard
            cacheService.saveJSONSync(response, filename: filename, expiration: 1800)

            print("📊 InsightsPrefetch: ✅ Capacity analysis cached")
        } catch {
            print("📊 InsightsPrefetch: ⚠️ Capacity analysis prefetch failed: \(error.localizedDescription)")
        }
    }

    /// Prefetch available weeks for week picker
    private func prefetchAvailableWeeks() async {
        let filename = "available_weeks"

        // Check if cache is still valid (1 hour expiration)
        if let metadata = cacheService.getCacheMetadataSync(filename: filename),
           Date().timeIntervalSince(metadata.lastUpdated) < 3600 {
            print("📊 InsightsPrefetch: Available weeks cache still valid")
            return
        }

        do {
            print("📊 InsightsPrefetch: Fetching available weeks...")
            let response = try await apiService.getAvailableWeeks()

            cacheService.saveJSONSync(response, filename: filename, expiration: 3600)

            print("📊 InsightsPrefetch: ✅ Available weeks cached")
        } catch {
            print("📊 InsightsPrefetch: ⚠️ Available weeks prefetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private var currentWeekStart: String {
        let calendar = Calendar.current
        let today = Date()
        guard let monday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: monday)
    }
}
