import Foundation
import Combine
import SwiftUI

@MainActor
class TodayOverviewViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var overview: TodayOverviewResponse?
    @Published var isLoading: Bool = false
    @Published var hasError: Bool = false
    @Published var errorMessage: String?
    @Published var lastRefreshDate: Date?

    // MARK: - Private Properties
    private let apiService = APIService.shared
    private let cacheService = CacheService.shared
    private let memoryCache = InMemoryCache.shared
    private var retryCount = 0
    private let maxRetries = 3
    private var currentTask: Task<Void, Never>?

    // Cache key for today's overview
    private var cacheKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "today_overview_\(formatter.string(from: Date()))"
    }

    // In-memory cache key
    private var memoryCacheKey: String { "mem_\(cacheKey)" }

    // MARK: - Initialization
    init() {
        loadCacheSync()
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

    // MARK: - Cache Loading (Synchronous for instant UI)
    private func loadCacheSync() {
        // Try disk cache directly (fast, ~5-10ms) - memory cache requires async
        // This ensures we have data on first frame render
        if let cached = cacheService.loadJSONSync(TodayOverviewResponse.self, filename: cacheKey) {
            overview = cached
            hasError = false
            errorMessage = nil
            // Populate memory cache (non-blocking)
            Task.detached(priority: .utility) { [memoryCacheKey, memoryCache] in
                await memoryCache.set(memoryCacheKey, value: cached, ttl: 60)
            }
        }
    }

    // MARK: - Public Methods

    /// Fetch overview from API with optional force refresh
    /// Uses request de-duplication to prevent duplicate API calls
    func fetchOverview(forceRefresh: Bool = false) async {
        // Reset error state
        hasError = false
        errorMessage = nil

        // 1. Check in-memory cache first (instant)
        if !forceRefresh {
            if let memCached: TodayOverviewResponse = await memoryCache.get(memoryCacheKey) {
                overview = memCached

                // Check if needs background refresh
                if await memoryCache.needsRefresh(memoryCacheKey) {
                    refreshInBackgroundNonBlocking()
                }
                return
            }
        }

        // 2. Check disk cache
        if !forceRefresh {
            if let cached = cacheService.loadJSONSync(TodayOverviewResponse.self, filename: cacheKey) {
                overview = cached
                await memoryCache.set(memoryCacheKey, value: cached, ttl: 60)

                // Check if stale
                if let metadata = cacheService.getCacheMetadataSync(filename: cacheKey),
                   Date().timeIntervalSince(metadata.lastUpdated) > 120 {
                    refreshInBackgroundNonBlocking()
                }
                return
            }
        }

        // 3. No cache - show loading
        if overview == nil {
            isLoading = true
        }

        // 4. Fetch with request de-duplication and auto-retry for auth errors
        do {
            let response = try await RequestDeduplicator.shared.dedupe(key: "overview_fetch") {
                try await self.apiService.fetchTodayOverview()
            }

            overview = response
            lastRefreshDate = Date()
            retryCount = 0

            // Cache (memory + disk)
            let ttl = response.cacheTtlSeconds ?? 120
            await memoryCache.set(memoryCacheKey, value: response, ttl: TimeInterval(ttl))
            cacheService.saveJSONSync(response, filename: cacheKey, expiration: TimeInterval(ttl))

            isLoading = false
            hasError = false
            errorMessage = nil
        } catch {
            if Task.isCancelled { return }

            // Auto-retry for auth errors (token may not be ready yet on app launch)
            let nsError = error as NSError
            if nsError.code == 401 && retryCount < maxRetries {
                retryCount += 1
                print("⚠️ Overview: Auth error on initial load, auto-retrying (\(retryCount)/\(maxRetries))...")
                // Wait briefly for token to become available
                try? await Task.sleep(nanoseconds: UInt64(500_000_000 * retryCount)) // 0.5s, 1s, 1.5s
                await fetchOverview(forceRefresh: true)
                return
            }

            isLoading = false

            if overview == nil {
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

    /// Retry fetching after error
    func retry() async {
        guard retryCount < maxRetries else {
            errorMessage = "Maximum retry attempts reached. Please try again later."
            return
        }

        retryCount += 1
        await fetchOverview(forceRefresh: true)
    }

    /// Refresh overview (pull-to-refresh)
    func refresh() async {
        await fetchOverview(forceRefresh: true)
    }

    // MARK: - Private Methods

    private func refreshInBackground() async {
        guard !Task.isCancelled else { return }

        do {
            let response = try await apiService.fetchTodayOverview()

            guard !Task.isCancelled else { return }

            // Update memory cache first
            let ttl = response.cacheTtlSeconds ?? 120
            await memoryCache.set(memoryCacheKey, value: response, ttl: TimeInterval(ttl))

            await MainActor.run {
                self.overview = response
                self.lastRefreshDate = Date()
            }

            // Save to disk in background
            // Important: Do not capture @MainActor self; capture only value types and use the nonisolated singleton
            Task.detached(priority: .utility) { [response, cacheKey, ttl] in
                await CacheService.shared.saveJSONSync(response, filename: cacheKey, expiration: TimeInterval(ttl))
            }
        } catch {
            #if DEBUG
            if !Task.isCancelled {
                print("⚠️ Overview background refresh failed: \(error.localizedDescription)")
            }
            #endif
        }
    }
}
