import Foundation
import Combine
import SwiftUI

@MainActor
class TodayBriefingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var briefing: DailyBriefingResponse?
    @Published var isLoading: Bool = false
    @Published var hasError: Bool = false
    @Published var errorMessage: String?
    @Published var lastRefreshDate: Date?

    // MARK: - Private Properties
    private let apiService = APIService()
    private let cacheService = CacheService.shared
    private var cancellables = Set<AnyCancellable>()
    private var retryCount = 0
    private let maxRetries = 3

    // Cache key for today's briefing
    private var cacheKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "daily_briefing_\(formatter.string(from: Date()))"
    }

    // MARK: - Initialization
    init() {
        loadCacheSync()
    }

    // MARK: - Cache Loading (Synchronous for instant UI)
    private func loadCacheSync() {
        if let cached = cacheService.loadJSONSync(DailyBriefingResponse.self, filename: cacheKey) {
            print("Today Briefing: Loaded from cache instantly")
            briefing = cached
            hasError = false
            errorMessage = nil
        }
    }

    // MARK: - Public Methods

    /// Fetch briefing from API with optional force refresh
    func fetchBriefing(forceRefresh: Bool = false) async {
        // Reset error state
        hasError = false
        errorMessage = nil

        // Check cache first if not force refreshing
        if !forceRefresh {
            if let cached = cacheService.loadJSONSync(DailyBriefingResponse.self, filename: cacheKey) {
                briefing = cached
                print("Today Briefing: Using cached data")

                // Check if cache is stale (older than 30 minutes)
                if let metadata = cacheService.getCacheMetadataSync(filename: cacheKey),
                   Date().timeIntervalSince(metadata.lastUpdated) > 1800 {
                    print("Today Briefing: Cache is stale, refreshing in background")
                    Task.detached(priority: .utility) { [weak self] in
                        await self?.refreshInBackground()
                    }
                }
                return
            }
        }

        // Show loading only if we don't have cached data
        if briefing == nil {
            isLoading = true
        }

        do {
            let response = try await fetchFromAPI()
            briefing = response
            lastRefreshDate = Date()
            retryCount = 0

            // Cache the response
            cacheService.saveJSONSync(response, filename: cacheKey, expiration: 24 * 60 * 60)
            print("Today Briefing: Saved to cache")

            isLoading = false
            hasError = false
            errorMessage = nil
        } catch {
            print("Today Briefing: Error - \(error.localizedDescription)")
            isLoading = false

            // Only show error if we have no cached data
            if briefing == nil {
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
        print("Today Briefing: Retry attempt \(retryCount)/\(maxRetries)")

        await fetchBriefing(forceRefresh: true)
    }

    /// Refresh briefing (pull-to-refresh)
    func refresh() async {
        await fetchBriefing(forceRefresh: true)
    }

    // MARK: - Private Methods

    private func fetchFromAPI() async throws -> DailyBriefingResponse {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw BriefingError.unauthorized
        }

        // Build URL with timezone
        let timezone = TimeZone.current.identifier
        let encodedTimezone = timezone.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? timezone

        guard let url = URL(string: "\(Constants.API.baseURL)/api/v1/today/briefing?timezone=\(encodedTimezone)") else {
            throw BriefingError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = Constants.API.timeout

        print("Today Briefing: Fetching from \(url)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BriefingError.invalidResponse
        }

        print("Today Briefing: Response status \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            do {
                let briefingResponse = try decoder.decode(DailyBriefingResponse.self, from: data)
                print("Today Briefing: Successfully decoded response")
                return briefingResponse
            } catch {
                print("Today Briefing: Decode error - \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Today Briefing: Raw response - \(responseString.prefix(500))")
                }
                throw BriefingError.decodingFailed(error)
            }
        case 401:
            throw BriefingError.unauthorized
        case 404:
            throw BriefingError.notFound
        case 500...599:
            throw BriefingError.serverError(httpResponse.statusCode)
        default:
            throw BriefingError.unknown(httpResponse.statusCode)
        }
    }

    private func refreshInBackground() async {
        do {
            let response = try await fetchFromAPI()

            await MainActor.run {
                self.briefing = response
                self.lastRefreshDate = Date()
            }

            cacheService.saveJSONSync(response, filename: cacheKey, expiration: 24 * 60 * 60)
            print("Today Briefing: Background refresh completed")
        } catch {
            print("Today Briefing: Background refresh failed - \(error.localizedDescription)")
        }
    }
}

// MARK: - Briefing Error Types
enum BriefingError: LocalizedError {
    case unauthorized
    case invalidURL
    case invalidResponse
    case notFound
    case serverError(Int)
    case decodingFailed(Error)
    case unknown(Int)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Please sign in to view your daily briefing."
        case .invalidURL:
            return "Invalid request URL."
        case .invalidResponse:
            return "Invalid response from server."
        case .notFound:
            return "Daily briefing not available yet."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .decodingFailed:
            return "Failed to process briefing data."
        case .unknown(let code):
            return "Unexpected error (\(code))."
        }
    }
}
