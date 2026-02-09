import Foundation
import Combine

@MainActor
class UnifiedTodayViewModel: ObservableObject {
    @Published var unified: UnifiedTodayResponse?
    @Published var isLoading = false
    @Published var hasError = false
    @Published var errorMessage: String?

    private let cacheService = CacheService.shared
    private let memoryCache = InMemoryCache.shared
    private var currentTask: Task<Void, Never>?

    private var cacheKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "unified_today_\(formatter.string(from: Date()))"
    }

    private var memoryCacheKey: String { "mem_\(cacheKey)" }

    init() {
        loadCacheSync()
    }

    // MARK: - Public Methods

    func fetchUnified(forceRefresh: Bool = false) async {
        hasError = false
        errorMessage = nil

        // Check memory cache
        if !forceRefresh {
            if let cached: UnifiedTodayResponse = await memoryCache.get(memoryCacheKey) {
                unified = cached
                if await memoryCache.needsRefresh(memoryCacheKey) {
                    refreshInBackgroundNonBlocking()
                }
                return
            }
        }

        // Check disk cache
        if !forceRefresh {
            if let cached = cacheService.loadJSONSync(UnifiedTodayResponse.self, filename: cacheKey) {
                unified = cached
                await memoryCache.set(memoryCacheKey, value: cached)
                if let metadata = cacheService.getCacheMetadataSync(filename: cacheKey),
                   Date().timeIntervalSince(metadata.lastUpdated) > 1800 {
                    refreshInBackgroundNonBlocking()
                }
                return
            }
        }

        if unified == nil {
            isLoading = true
        }

        do {
            let response = try await RequestDeduplicator.shared.dedupe(key: "unified_today_fetch") {
                try await self.fetchFromAPI()
            }

            unified = response
            await memoryCache.set(memoryCacheKey, value: response)
            cacheService.saveJSONSync(response, filename: cacheKey, expiration: 24 * 60 * 60)
            isLoading = false
        } catch {
            isLoading = false
            if unified == nil {
                hasError = true
                errorMessage = error.localizedDescription
            }
        }
    }

    func refresh() async {
        await fetchUnified(forceRefresh: true)
    }

    // MARK: - Commitment Actions

    func commitToAction() async {
        await respondToCommitment(response: "COMMITTED")
    }

    func changeAction() async {
        await respondToCommitment(response: "CHANGED")
    }

    func dismissAction() async {
        await respondToCommitment(response: "DISMISSED")
    }

    // MARK: - Private Methods

    private func loadCacheSync() {
        if let cached = cacheService.loadJSONSync(UnifiedTodayResponse.self, filename: cacheKey) {
            unified = cached
        }
    }

    private func refreshInBackgroundNonBlocking() {
        currentTask?.cancel()
        let capturedCacheKey = cacheKey
        let capturedMemoryCacheKey = memoryCacheKey
        let capturedCacheService = cacheService
        currentTask = Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            do {
                let response = try await self.fetchFromAPI()
                await self.memoryCache.set(capturedMemoryCacheKey, value: response)
                await MainActor.run {
                    self.unified = response
                }
                Task.detached(priority: .utility) {
                    capturedCacheService.saveJSONSync(response, filename: capturedCacheKey, expiration: 24 * 60 * 60)
                }
            } catch {
                // Silently fail
            }
        }
    }

    private func fetchFromAPI() async throws -> UnifiedTodayResponse {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw BriefingError.unauthorized
        }

        let timezone = TimeZone.current.identifier
        let encoded = timezone.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? timezone

        guard let url = URL(string: "\(Constants.API.baseURL)/api/v1/today/unified?timezone=\(encoded)") else {
            throw BriefingError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = Constants.API.timeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BriefingError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(UnifiedTodayResponse.self, from: data)
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

    private func respondToCommitment(response: String, changedTo: String? = nil) async {
        guard let token = KeychainManager.shared.getAccessToken() else { return }

        let timezone = TimeZone.current.identifier
        let encoded = timezone.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? timezone

        guard let url = URL(string: "\(Constants.API.baseURL)/api/v1/today/commitment?timezone=\(encoded)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Constants.API.timeout

        var body: [String: String] = ["response": response]
        if let changedTo = changedTo {
            body["changed_to"] = changedTo
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, httpResponse) = try await URLSession.shared.data(for: request)
            if let http = httpResponse as? HTTPURLResponse, http.statusCode == 200 {
                await fetchUnified(forceRefresh: true)
            }
        } catch {
            print("Failed to record commitment: \(error.localizedDescription)")
        }
    }
}
