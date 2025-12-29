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
    private let memoryCache = InMemoryCache.shared
    private var cancellables = Set<AnyCancellable>()
    private var retryCount = 0
    private let maxRetries = 3
    private var currentTask: Task<Void, Never>?

    // Cache key for today's briefing
    private var cacheKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "daily_briefing_\(formatter.string(from: Date()))"
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
        if let cached = cacheService.loadJSONSync(DailyBriefingResponse.self, filename: cacheKey) {
            briefing = cached
            hasError = false
            errorMessage = nil
            // Populate memory cache for next access (non-blocking)
            Task.detached(priority: .utility) { [memoryCacheKey, memoryCache] in
                await memoryCache.set(memoryCacheKey, value: cached)
            }
        }
    }

    // MARK: - Public Methods

    /// Fetch briefing from API with optional force refresh
    /// Uses request de-duplication to prevent duplicate API calls
    func fetchBriefing(forceRefresh: Bool = false) async {
        // Reset error state
        hasError = false
        errorMessage = nil

        // 1. Check in-memory cache first (instant, < 1ms)
        if !forceRefresh {
            if let memCached: DailyBriefingResponse = await memoryCache.get(memoryCacheKey) {
                briefing = memCached

                // Check if needs background refresh
                if await memoryCache.needsRefresh(memoryCacheKey) {
                    refreshInBackgroundNonBlocking()
                }
                return
            }
        }

        // 2. Check disk cache if not force refreshing
        if !forceRefresh {
            if let cached = cacheService.loadJSONSync(DailyBriefingResponse.self, filename: cacheKey) {
                briefing = cached
                await memoryCache.set(memoryCacheKey, value: cached)

                // Check if cache is stale (older than 30 minutes)
                if let metadata = cacheService.getCacheMetadataSync(filename: cacheKey),
                   Date().timeIntervalSince(metadata.lastUpdated) > 1800 {
                    refreshInBackgroundNonBlocking()
                }
                return
            }
        }

        // 3. No cache - show loading only if we don't have data
        if briefing == nil {
            isLoading = true
        }

        // 4. Fetch with request de-duplication and auto-retry for auth errors
        do {
            let response = try await RequestDeduplicator.shared.dedupe(key: "briefing_fetch") {
                try await self.fetchFromAPI()
            }

            briefing = response
            lastRefreshDate = Date()
            retryCount = 0

            // Cache the response (memory + disk)
            await memoryCache.set(memoryCacheKey, value: response)
            cacheService.saveJSONSync(response, filename: cacheKey, expiration: 24 * 60 * 60)

            isLoading = false
            hasError = false
            errorMessage = nil
        } catch {
            if Task.isCancelled { return } // Don't show error if cancelled

            // Auto-retry for auth errors (token may not be ready yet on app launch)
            if case BriefingError.unauthorized = error, retryCount < maxRetries {
                retryCount += 1
                print("⚠️ Briefing: Auth error on initial load, auto-retrying (\(retryCount)/\(maxRetries))...")
                // Wait briefly for token to become available
                try? await Task.sleep(nanoseconds: UInt64(500_000_000 * retryCount)) // 0.5s, 1s, 1.5s
                await fetchBriefing(forceRefresh: true)
                return
            }

            isLoading = false

            // Only show error if we have no cached data
            if briefing == nil {
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
        guard !Task.isCancelled else { return }

        do {
            let response = try await fetchFromAPI()

            guard !Task.isCancelled else { return }

            // Update memory cache first (instant for next access)
            await memoryCache.set(memoryCacheKey, value: response)

            await MainActor.run {
                self.briefing = response
                self.lastRefreshDate = Date()
            }

            // Save to disk cache in background
            Task.detached(priority: .utility) { [cacheService, cacheKey] in
                cacheService.saveJSONSync(response, filename: cacheKey, expiration: 24 * 60 * 60)
            }
        } catch {
            // Silently fail - we have cached data
            #if DEBUG
            if !Task.isCancelled {
                print("⚠️ Briefing background refresh failed: \(error.localizedDescription)")
            }
            #endif
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
