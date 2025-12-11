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
    private var retryCount = 0
    private let maxRetries = 3

    // Cache key for today's overview
    private var cacheKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "today_overview_\(formatter.string(from: Date()))"
    }

    // MARK: - Initialization
    init() {
        loadCacheSync()
    }

    // MARK: - Cache Loading (Synchronous for instant UI)
    private func loadCacheSync() {
        if let cached = cacheService.loadJSONSync(TodayOverviewResponse.self, filename: cacheKey) {
            print("Today Overview: Loaded from cache instantly")
            overview = cached
            hasError = false
            errorMessage = nil
        }
    }

    // MARK: - Public Methods

    /// Fetch overview from API with optional force refresh
    func fetchOverview(forceRefresh: Bool = false) async {
        // Reset error state
        hasError = false
        errorMessage = nil

        // Check cache first if not force refreshing
        if !forceRefresh {
            if let cached = cacheService.loadJSONSync(TodayOverviewResponse.self, filename: cacheKey) {
                overview = cached
                print("Today Overview: Using cached data")

                // Check if cache is stale (older than 2 minutes for overview)
                if let metadata = cacheService.getCacheMetadataSync(filename: cacheKey),
                   Date().timeIntervalSince(metadata.lastUpdated) > 120 {
                    print("Today Overview: Cache is stale, refreshing in background")
                    Task.detached(priority: .utility) { [weak self] in
                        await self?.refreshInBackground()
                    }
                }
                return
            }
        }

        // Show loading only if we don't have cached data
        if overview == nil {
            isLoading = true
        }

        do {
            let response = try await apiService.fetchTodayOverview()
            overview = response
            lastRefreshDate = Date()
            retryCount = 0

            // Cache the response (short TTL for overview)
            let cacheTtl = response.cacheTtlSeconds ?? 120
            cacheService.saveJSONSync(response, filename: cacheKey, expiration: TimeInterval(cacheTtl))
            print("Today Overview: Saved to cache with TTL \(cacheTtl)s")

            isLoading = false
            hasError = false
            errorMessage = nil
        } catch {
            print("Today Overview: Error - \(error.localizedDescription)")
            isLoading = false

            // Only show error if we have no cached data
            if overview == nil {
                hasError = true
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Retry fetching after error
    func retry() async {
        guard retryCount < maxRetries else {
            errorMessage = "Maximum retry attempts reached. Please try again later."
            return
        }

        retryCount += 1
        print("Today Overview: Retry attempt \(retryCount)/\(maxRetries)")

        await fetchOverview(forceRefresh: true)
    }

    /// Refresh overview (pull-to-refresh)
    func refresh() async {
        await fetchOverview(forceRefresh: true)
    }

    // MARK: - Private Methods

    private func refreshInBackground() async {
        do {
            let response = try await apiService.fetchTodayOverview()

            await MainActor.run {
                self.overview = response
                self.lastRefreshDate = Date()
            }

            let cacheTtl = response.cacheTtlSeconds ?? 120
            cacheService.saveJSONSync(response, filename: cacheKey, expiration: TimeInterval(cacheTtl))
            print("Today Overview: Background refresh completed")
        } catch {
            print("Today Overview: Background refresh failed - \(error.localizedDescription)")
        }
    }
}
