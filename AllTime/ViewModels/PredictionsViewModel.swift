import Foundation
import Combine
import SwiftUI

@MainActor
class PredictionsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var predictions: PredictionsResponse?
    @Published var isLoading: Bool = false
    @Published var hasError: Bool = false
    @Published var errorMessage: String?
    @Published var lastRefreshDate: Date?

    // MARK: - Private Properties
    private let apiService = APIService.shared
    private let cacheService = CacheService.shared
    private var retryCount = 0
    private let maxRetries = 3

    // Cache key for today's predictions
    private var cacheKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "predictions_\(formatter.string(from: Date()))"
    }

    // MARK: - Initialization
    init() {
        loadCacheSync()
    }

    // MARK: - Cache Loading (Synchronous for instant UI)
    private func loadCacheSync() {
        if let cached = cacheService.loadJSONSync(PredictionsResponse.self, filename: cacheKey) {
            print("Predictions: Loaded from cache instantly")
            predictions = cached
            hasError = false
            errorMessage = nil
        }
    }

    // MARK: - Public Methods

    /// Fetch predictions from API with optional force refresh
    func fetchPredictions(forceRefresh: Bool = false) async {
        // Reset error state
        hasError = false
        errorMessage = nil

        // Check cache first if not force refreshing
        if !forceRefresh {
            if let cached = cacheService.loadJSONSync(PredictionsResponse.self, filename: cacheKey) {
                predictions = cached
                print("Predictions: Using cached data")

                // Check if cache is stale (older than 5 minutes for predictions)
                if let metadata = cacheService.getCacheMetadataSync(filename: cacheKey),
                   Date().timeIntervalSince(metadata.lastUpdated) > 300 {
                    print("Predictions: Cache is stale, refreshing in background")
                    Task.detached(priority: .utility) { [weak self] in
                        await self?.refreshInBackground()
                    }
                }
                return
            }
        }

        // Show loading only if we don't have cached data
        if predictions == nil {
            isLoading = true
        }

        do {
            let response = try await apiService.getTodayPredictions()
            predictions = response
            lastRefreshDate = Date()
            retryCount = 0

            // Cache the response (5 min TTL for predictions)
            cacheService.saveJSONSync(response, filename: cacheKey, expiration: 300)
            print("Predictions: Saved to cache with TTL 300s")

            isLoading = false
            hasError = false
            errorMessage = nil
        } catch {
            print("Predictions: Error - \(error.localizedDescription)")
            isLoading = false

            // Only show error if we have no cached data
            if predictions == nil {
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
        print("Predictions: Retry attempt \(retryCount)/\(maxRetries)")

        await fetchPredictions(forceRefresh: true)
    }

    /// Refresh predictions (pull-to-refresh)
    func refresh() async {
        await fetchPredictions(forceRefresh: true)
    }

    // MARK: - Private Methods

    private func refreshInBackground() async {
        do {
            let response = try await apiService.getTodayPredictions()

            await MainActor.run {
                self.predictions = response
                self.lastRefreshDate = Date()
            }

            cacheService.saveJSONSync(response, filename: cacheKey, expiration: 300)
            print("Predictions: Background refresh completed")
        } catch {
            print("Predictions: Background refresh failed - \(error.localizedDescription)")
        }
    }

    // MARK: - Computed Properties for Tile Display

    var tilePreviewText: String {
        guard let predictions = predictions else {
            return "Tap to view insights"
        }

        if let capacity = predictions.capacity {
            return "\(capacity.capacityDisplayText) day"
        } else if predictions.travelPredictions.count > 0 {
            return "\(predictions.travelPredictions.count) travel alert\(predictions.travelPredictions.count == 1 ? "" : "s")"
        }

        return "View today's insights"
    }

    var capacityLevel: String? {
        predictions?.capacity?.capacityLevel
    }

    var capacityPercentage: Double? {
        predictions?.capacity?.capacityPercentage
    }

    var warningCount: Int {
        predictions?.warningCount ?? 0
    }

    var hasWarnings: Bool {
        predictions?.hasWarnings ?? false
    }

    var travelPredictionsCount: Int {
        predictions?.travelPredictions.count ?? 0
    }

    var nextLeaveByTime: String? {
        guard let travel = predictions?.travelPredictions.first,
              travel.leaveByDate != nil else { return nil }
        return travel.formattedLeaveBy
    }

    var patternsCount: Int {
        predictions?.patterns.count ?? 0
    }
}
