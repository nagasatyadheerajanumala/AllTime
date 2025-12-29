import SwiftUI
import Combine

/// ViewModel for the Life Insights (Monthly/2-Month) feature.
/// Handles data fetching, caching, and state management.
/// Optimized with InMemoryCache, request deduplication, and parallel fetching.
@MainActor
class LifeInsightsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var insights: LifeInsightsResponse?
    @Published var placesRecommendations: PlacesRecommendationResponse?
    @Published var rateLimitStatus: RateLimitStatus?

    @Published var selectedMode: LifeInsightsMode = .thirtyDay
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var error: String?

    // MARK: - State

    enum ViewState {
        case loading
        case loaded
        case error(String)
    }

    @Published var state: ViewState = .loading

    // MARK: - Private Properties

    private let apiService = APIService.shared
    private let cacheService = CacheService.shared
    private let memoryCache = InMemoryCache.shared
    private var loadTask: Task<Void, Never>?
    private var backgroundTask: Task<Void, Never>?

    private var cacheFilename: String {
        "life_insights_\(selectedMode.rawValue)"
    }

    private var memoryCacheKey: String {
        "mem_life_insights_\(selectedMode.rawValue)"
    }

    private var placesCacheKey: String {
        "mem_places_recommendations"
    }

    // MARK: - Initialization

    init() {
        // Load cached data immediately for instant display
        loadFromCache()
    }

    // MARK: - Task Cancellation

    /// Cancel any in-flight requests (call in onDisappear)
    func cancelPendingRequests() {
        loadTask?.cancel()
        loadTask = nil
        backgroundTask?.cancel()
        backgroundTask = nil
    }

    deinit {
        loadTask?.cancel()
        backgroundTask?.cancel()
    }

    /// Clear cached insights (useful when model changes)
    func clearCache() {
        Task {
            await memoryCache.remove(memoryCacheKey)
            await memoryCache.remove(placesCacheKey)
        }

        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AllTimeCache", isDirectory: true)
        let file30 = cacheDir.appendingPathComponent("life_insights_30day.json")
        let file60 = cacheDir.appendingPathComponent("life_insights_60day.json")
        let meta30 = cacheDir.appendingPathComponent("life_insights_30day.meta.json")
        let meta60 = cacheDir.appendingPathComponent("life_insights_60day.meta.json")
        try? FileManager.default.removeItem(at: file30)
        try? FileManager.default.removeItem(at: file60)
        try? FileManager.default.removeItem(at: meta30)
        try? FileManager.default.removeItem(at: meta60)
        print("🧠 LifeInsights: Cleared local cache at \(cacheDir.path)")
    }

    // MARK: - Public Methods

    /// Load insights for the selected mode.
    /// Uses cache if available, then fetches fresh data in background.
    func loadInsights() async {
        // Cancel any existing load
        loadTask?.cancel()

        print("🧠 LifeInsights: Loading insights for mode \(selectedMode.rawValue)")

        // 1. Try memory cache first (instant)
        if let memCached: LifeInsightsResponse = await memoryCache.get(memoryCacheKey) {
            insights = memCached
            state = .loaded

            // Check if needs background refresh
            if await memoryCache.needsRefresh(memoryCacheKey) {
                refreshInBackgroundNonBlocking()
            }
            return
        }

        loadTask = Task {
            // If no cached data, show loading state
            if insights == nil {
                state = .loading
                isLoading = true
                print("🧠 LifeInsights: No cached data, showing loading state")
            } else {
                print("🧠 LifeInsights: Have cached data, fetching in background")
            }

            do {
                // Fetch insights and places in PARALLEL using async let
                print("🧠 LifeInsights: Calling API (parallel with places)...")

                async let insightsTask = RequestDeduplicator.shared.dedupe(key: "life_insights_\(selectedMode.rawValue)") {
                    try await self.apiService.getLifeInsights(mode: self.selectedMode.rawValue)
                }
                async let placesTask = fetchPlacesFromAPI()

                // Wait for insights (required), places can fail silently
                let response = try await insightsTask
                _ = try? await placesTask

                guard !Task.isCancelled else { return }

                // Debug: Log what we received
                print("🧠 LifeInsights: API success!")
                print("   - rangeStart: \(response.rangeStart)")
                print("   - rangeEnd: \(response.rangeEnd)")
                print("   - mode: \(response.mode)")
                print("   - headline: \(response.headline ?? "nil")")
                print("   - patterns count: \(response.yourLifePatterns?.count ?? 0)")

                insights = response
                state = .loaded
                error = nil

                print("🧠 LifeInsights: hasData = \(hasData)")

                // Cache the response (memory + disk)
                saveToCache(response)
                print("🧠 LifeInsights: Cached response")

            } catch {
                if Task.isCancelled {
                    print("🧠 LifeInsights: Task cancelled")
                    return
                }

                print("🧠 LifeInsights: API error - \(error)")
                print("🧠 LifeInsights: Error details - \(error.localizedDescription)")

                // If we have cached data, show it with a refresh indicator
                if insights != nil {
                    self.error = "Using cached data. Pull to refresh."
                    state = .loaded
                } else {
                    self.error = error.localizedDescription
                    state = .error(error.localizedDescription)
                }
            }

            isLoading = false
            print("🧠 LifeInsights: Load complete. state=\(state), hasData=\(hasData)")
        }

        await loadTask?.value
    }

    /// Non-blocking background refresh
    private func refreshInBackgroundNonBlocking() {
        backgroundTask?.cancel()
        backgroundTask = Task.detached(priority: .utility) { [weak self] in
            await self?.refreshInBackground()
        }
    }

    private func refreshInBackground() async {
        guard !Task.isCancelled else { return }

        do {
            let response = try await apiService.getLifeInsights(mode: selectedMode.rawValue)

            guard !Task.isCancelled else { return }

            // Update memory cache first
            await memoryCache.set(memoryCacheKey, value: response, ttl: 600) // 10 min

            await MainActor.run {
                self.insights = response
                self.state = .loaded
            }

            // Save to disk in background
            Task.detached(priority: .utility) { [cacheFilename = self.cacheFilename] in
                CacheService.shared.saveJSONSync(response, filename: cacheFilename, expiration: 3600)
            }
        } catch {
            #if DEBUG
            if !Task.isCancelled {
                print("⚠️ LifeInsights background refresh failed: \(error.localizedDescription)")
            }
            #endif
        }
    }

    /// Refresh insights (pull-to-refresh).
    func refresh() async {
        isRefreshing = true
        // Clear memory cache to force fresh fetch
        await memoryCache.remove(memoryCacheKey)
        await loadInsights()
        isRefreshing = false
    }

    /// Force regenerate insights (uses OpenAI).
    func regenerateInsights() async {
        isLoading = true
        error = nil

        do {
            let response = try await apiService.regenerateLifeInsights(mode: selectedMode.rawValue)

            guard !Task.isCancelled else { return }

            insights = response.insights
            rateLimitStatus = RateLimitStatus(
                remaining: response.remainingRegenerations,
                maxPerDay: 5,
                resetsAt: nil
            )
            state = .loaded

            // Cache the new response
            if let newInsights = insights {
                saveToCache(newInsights)
            }

        } catch {
            if !Task.isCancelled {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }

    /// Switch between 30-day and 60-day modes.
    func switchMode(to mode: LifeInsightsMode) async {
        guard mode != selectedMode else { return }

        selectedMode = mode
        insights = nil
        loadFromCache()
        await loadInsights()
    }

    /// Fetch rate limit status.
    func fetchRateLimitStatus() async {
        do {
            rateLimitStatus = try await RequestDeduplicator.shared.dedupe(key: "life_insights_rate_limit") {
                try await self.apiService.getLifeInsightsRateLimit()
            }
        } catch {
            if !Task.isCancelled {
                print("Failed to fetch rate limit: \(error)")
            }
        }
    }

    // MARK: - Private Methods

    private func loadFromCache() {
        // Try memory cache first (instant)
        Task {
            if let memCached: LifeInsightsResponse = await memoryCache.get(memoryCacheKey) {
                insights = memCached
                state = .loaded
                return
            }
        }

        // Fall back to disk cache
        print("🧠 LifeInsights: Attempting to load from cache: \(cacheFilename)")
        if let cached = cacheService.loadJSONSync(LifeInsightsResponse.self, filename: cacheFilename) {
            print("🧠 LifeInsights: Cache hit! headline=\(cached.headline ?? "nil"), patterns=\(cached.yourLifePatterns?.count ?? 0)")
            insights = cached
            state = .loaded

            // Populate memory cache
            Task {
                await memoryCache.set(memoryCacheKey, value: cached, ttl: 600) // 10 min
            }
        } else {
            print("🧠 LifeInsights: Cache miss")
        }

        // Also load places from cache
        if let cachedPlaces = cacheService.loadJSONSync(PlacesRecommendationResponse.self, filename: "places_recommendations") {
            placesRecommendations = cachedPlaces
        }
    }

    private func saveToCache(_ response: LifeInsightsResponse) {
        // Memory cache first (instant for next access)
        Task {
            await memoryCache.set(memoryCacheKey, value: response, ttl: 600) // 10 min
        }

        // Disk cache in background
        Task.detached(priority: .utility) { [cacheFilename = self.cacheFilename] in
            CacheService.shared.saveJSONSync(response, filename: cacheFilename, expiration: 3600) // 1 hour
        }
    }

    private func fetchPlacesFromAPI() async throws {
        // Check memory cache first
        if let memCached: PlacesRecommendationResponse = await memoryCache.get(placesCacheKey) {
            await MainActor.run {
                self.placesRecommendations = memCached
            }
            return
        }

        let places = try await RequestDeduplicator.shared.dedupe(key: "places_recommendations") {
            try await self.apiService.getPlacesRecommendations()
        }

        await memoryCache.set(placesCacheKey, value: places, ttl: 1800) // 30 min

        await MainActor.run {
            self.placesRecommendations = places
        }

        // Save to disk
        Task.detached(priority: .utility) {
            CacheService.shared.saveJSONSync(places, filename: "places_recommendations", expiration: 3600)
        }
    }

    // MARK: - Computed Properties

    var hasData: Bool {
        insights != nil
    }

    var displayHeadline: String {
        insights?.headline ?? "Analyzing your calendar patterns..."
    }

    var displayPatterns: [LifeInsightItem] {
        insights?.yourLifePatterns ?? []
    }

    var displayWhatWentWell: [LifeInsightItem] {
        insights?.whatWentWell ?? []
    }

    var displayPatternsToWatch: [LifeInsightItem] {
        insights?.patternsToWatch ?? []
    }

    var displayNextWeekFocus: [LifeActionItem] {
        insights?.nextWeekFocus ?? []
    }

    var displayKeyMetrics: [LifeKeyMetric] {
        insights?.keyMetrics ?? []
    }

    var displayRecommendations: LifeRecommendations? {
        insights?.recommendations
    }

    var displayPlacesSuggestions: [PlaceSuggestion] {
        placesRecommendations?.suggestions ?? []
    }

    var displayPlacesCategories: [PlaceCategory] {
        placesRecommendations?.categories ?? []
    }

    var canRegenerate: Bool {
        rateLimitStatus?.remaining ?? 5 > 0
    }

    var remainingRegenerations: Int {
        rateLimitStatus?.remaining ?? 5
    }
}

// MARK: - Regenerate Response
struct RegenerateInsightsResponse: Codable {
    let insights: LifeInsightsResponse
    let remainingRegenerations: Int

    enum CodingKeys: String, CodingKey {
        case insights
        case remainingRegenerations = "remaining_regenerations"
    }
}
