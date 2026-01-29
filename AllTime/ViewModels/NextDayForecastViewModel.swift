import Foundation
import Combine
import SwiftUI

/// ViewModel for Next Day (Tomorrow) Forecast
/// Provides pattern-based predictions to help users prepare for tomorrow
@MainActor
class NextDayForecastViewModel: ObservableObject {
    @Published var forecast: NextDayForecast?
    @Published var isLoading = false
    @Published var hasError = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared
    private let cacheService = CacheService.shared
    private let memoryCache = InMemoryCache.shared
    private var currentTask: Task<Void, Never>?

    // MARK: - Cache Keys
    private let memoryCacheKey = "mem_tomorrow_forecast"
    private let diskCacheKey = "tomorrow_forecast"

    init() {
        loadCachedData()
    }

    // MARK: - Task Cancellation

    /// Cancel any in-flight requests (call in onDisappear)
    func cancelPendingRequests() {
        currentTask?.cancel()
        currentTask = nil
    }

    deinit {
        currentTask?.cancel()
    }

    // MARK: - Cache Loading (Instant UI)

    private func loadCachedData() {
        // Try memory cache first (instant)
        Task {
            if let memCached: NextDayForecast = await memoryCache.get(memoryCacheKey) {
                // Verify the cache is for tomorrow
                if isCacheForTomorrow(memCached) {
                    forecast = memCached
                    return
                }
            }
        }

        // Fall back to disk cache
        if let cached = cacheService.loadJSONSync(NextDayForecast.self, filename: diskCacheKey) {
            if isCacheForTomorrow(cached) {
                print("NextDayForecast: Loaded from disk cache")
                forecast = cached
                // Populate memory cache
                Task {
                    await memoryCache.set(memoryCacheKey, value: cached, ttl: 300) // 5 min
                }
            }
        }
    }

    /// Check if cached forecast is for tomorrow (not stale)
    private func isCacheForTomorrow(_ cached: NextDayForecast) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let tomorrowStr = formatter.string(from: tomorrow)
        return cached.date == tomorrowStr
    }

    private func cacheForecast(_ response: NextDayForecast) {
        // Memory cache first (instant for next access)
        Task {
            await memoryCache.set(memoryCacheKey, value: response, ttl: 300)
        }

        // Disk cache in background
        Task.detached(priority: .utility) {
            CacheService.shared.saveJSONSync(response, filename: "tomorrow_forecast", expiration: 1800) // 30 min
        }
    }

    // MARK: - Data Loading

    /// Fetch tomorrow's forecast
    /// Uses request deduplication to prevent duplicate API calls
    func fetchForecast(forceRefresh: Bool = false) async {
        // 1. Try memory cache first (instant)
        if !forceRefresh {
            if let memCached: NextDayForecast = await memoryCache.get(memoryCacheKey),
               isCacheForTomorrow(memCached) {
                forecast = memCached

                // Check if needs background refresh
                if await memoryCache.needsRefresh(memoryCacheKey) {
                    refreshInBackgroundNonBlocking()
                }
                return
            }
        }

        // 2. Try disk cache
        if !forceRefresh {
            if let diskCached = cacheService.loadJSONSync(NextDayForecast.self, filename: diskCacheKey),
               isCacheForTomorrow(diskCached) {
                print("NextDayForecast: Loaded from disk cache")
                forecast = diskCached

                // Populate memory cache
                Task {
                    await memoryCache.set(memoryCacheKey, value: diskCached, ttl: 300)
                }

                // Check if disk cache is stale and needs background refresh
                if let metadata = cacheService.getCacheMetadataSync(filename: diskCacheKey),
                   Date().timeIntervalSince(metadata.lastUpdated) > 900 { // Refresh after 15 min
                    refreshInBackgroundNonBlocking()
                }
                return
            }
        }

        // 3. Show loading only if we don't have data
        if forecast == nil {
            isLoading = true
        }
        hasError = false
        errorMessage = nil

        // 4. Fetch with request deduplication
        do {
            let response = try await RequestDeduplicator.shared.dedupe(key: "tomorrow_forecast") {
                try await self.apiService.getTomorrowForecast()
            }

            guard !Task.isCancelled else { return }

            forecast = response
            cacheForecast(response)
            isLoading = false
            print("NextDayForecast: Fetched successfully - \(response.headline)")
        } catch {
            if Task.isCancelled { return }

            print("NextDayForecast: Error - \(error.localizedDescription)")
            isLoading = false
            if forecast == nil {
                hasError = true
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Non-blocking background refresh
    private func refreshInBackgroundNonBlocking() {
        currentTask?.cancel()
        currentTask = Task.detached(priority: .utility) { [weak self] in
            await self?.refreshInBackground()
        }
    }

    private func refreshInBackground() async {
        guard !Task.isCancelled else { return }

        do {
            let response = try await apiService.getTomorrowForecast()

            guard !Task.isCancelled else { return }

            // Update memory cache first
            await memoryCache.set(memoryCacheKey, value: response, ttl: 300)

            await MainActor.run {
                self.forecast = response
            }

            // Save to disk in background
            Task.detached(priority: .utility) {
                CacheService.shared.saveJSONSync(response, filename: "tomorrow_forecast", expiration: 1800)
            }
        } catch {
            #if DEBUG
            if !Task.isCancelled {
                print("NextDayForecast background refresh failed: \(error.localizedDescription)")
            }
            #endif
        }
    }

    /// Force refresh forecast
    func refresh() async {
        isLoading = true
        hasError = false
        errorMessage = nil

        do {
            let response = try await apiService.getTomorrowForecast()

            guard !Task.isCancelled else { return }

            forecast = response
            cacheForecast(response)
            isLoading = false
        } catch {
            if Task.isCancelled { return }

            print("NextDayForecast: Refresh error - \(error.localizedDescription)")
            isLoading = false
            hasError = true
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Computed Properties

    var hasForecast: Bool {
        forecast != nil
    }

    var meetingCount: Int {
        forecast?.meetingCount ?? 0
    }

    var meetingHours: Double {
        forecast?.meetingHours ?? 0
    }

    var focusHours: Double {
        forecast?.focusHours ?? 0
    }

    var intensity: String {
        forecast?.intensity ?? "unknown"
    }

    var intensityLabel: String {
        forecast?.intensityLabel ?? "Unknown"
    }

    var headline: String {
        forecast?.headline ?? "Loading tomorrow's forecast..."
    }

    var subheadline: String? {
        forecast?.subheadline
    }

    var claraInsight: String? {
        forecast?.claraInsight
    }

    var hasRisks: Bool {
        forecast?.hasRisks ?? false
    }

    var riskSignals: [TomorrowRiskSignal] {
        forecast?.riskSignals ?? []
    }

    var interventions: [TomorrowIntervention] {
        forecast?.interventions ?? []
    }

    var similarDays: [TomorrowSimilarDayMatch] {
        forecast?.similarDays ?? []
    }

    var prediction: TomorrowDayPrediction? {
        forecast?.prediction
    }

    var sleepRecommendation: TomorrowSleepRecommendation? {
        forecast?.sleepRecommendation
    }

    var comparedToToday: TomorrowComparison? {
        forecast?.comparedToToday
    }

    var isLighterThanToday: Bool {
        comparedToToday?.isLighter ?? false
    }

    var isHeavierThanToday: Bool {
        comparedToToday?.isHeavier ?? false
    }
}
