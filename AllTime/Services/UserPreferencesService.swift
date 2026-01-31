import Foundation
import Combine

/// Centralized service for user preferences that affect app-wide behavior.
/// Views observe this service to react to preference changes immediately.
@MainActor
class UserPreferencesService: ObservableObject {
    static let shared = UserPreferencesService()

    // MARK: - Published Preferences

    /// Whether to show sleep data in the app UI and Clara insights.
    /// When false, all sleep-related data is hidden from views.
    @Published var useSleepDataForInsights: Bool = true {
        didSet {
            // Persist locally for quick access
            UserDefaults.standard.set(useSleepDataForInsights, forKey: Keys.useSleepDataForInsights)
            print("🛏️ UserPreferencesService: Sleep data preference changed to \(useSleepDataForInsights)")
        }
    }

    /// Loading state for preference fetches
    @Published var isLoading: Bool = false

    // MARK: - Keys

    private enum Keys {
        static let useSleepDataForInsights = "useSleepDataForInsights"
        static let hasLoadedFromServer = "hasLoadedSleepPrefFromServer"
    }

    // MARK: - Init

    private init() {
        // Load cached value immediately (defaults to true if not set)
        useSleepDataForInsights = UserDefaults.standard.object(forKey: Keys.useSleepDataForInsights) as? Bool ?? true

        // Fetch from server in background to sync
        Task {
            await loadFromServer()
        }
    }

    // MARK: - Server Sync

    /// Load preference from server (call on app launch and when needed)
    func loadFromServer() async {
        guard let token = KeychainManager.shared.getAccessToken(), !token.isEmpty else {
            print("🛏️ UserPreferencesService: No auth token, skipping server fetch")
            return
        }

        guard let url = URL(string: "\(Constants.API.baseURL)/api/user/preferences/sleep-insights") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            isLoading = true
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                isLoading = false
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let value = json["useSleepDataForInsights"] as? Bool {
                // Only update if different to avoid unnecessary UI updates
                if self.useSleepDataForInsights != value {
                    self.useSleepDataForInsights = value
                }
                UserDefaults.standard.set(true, forKey: Keys.hasLoadedFromServer)
                print("🛏️ UserPreferencesService: Loaded from server: \(value)")
            }
            isLoading = false
        } catch {
            print("🛏️ UserPreferencesService: Failed to load from server: \(error)")
            isLoading = false
        }
    }

    /// Update preference on server and locally
    func setUseSleepDataForInsights(_ enabled: Bool) async -> Bool {
        guard let token = KeychainManager.shared.getAccessToken(), !token.isEmpty else {
            return false
        }

        guard let url = URL(string: "\(Constants.API.baseURL)/api/user/preferences/sleep-insights") else {
            return false
        }

        // Optimistically update local state immediately for responsive UI
        let previousValue = useSleepDataForInsights
        useSleepDataForInsights = enabled

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["useSleepDataForInsights": enabled]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                // Revert on failure
                useSleepDataForInsights = previousValue
                return false
            }

            print("🛏️ UserPreferencesService: Updated on server: \(enabled)")

            // Post notification for any views that need explicit refresh
            NotificationCenter.default.post(name: .sleepPreferenceChanged, object: nil)

            return true
        } catch {
            print("🛏️ UserPreferencesService: Failed to update on server: \(error)")
            // Revert on failure
            useSleepDataForInsights = previousValue
            return false
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let sleepPreferenceChanged = Notification.Name("sleepPreferenceChanged")
}
