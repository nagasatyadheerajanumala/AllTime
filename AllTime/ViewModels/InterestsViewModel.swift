import Foundation
import SwiftUI
import Combine

@MainActor
class InterestsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedActivities: Set<String> = []
    @Published var selectedLifestyle: Set<String> = []
    @Published var selectedSocial: Set<String> = []
    @Published var weekendPace: String = "balanced"
    @Published var outingDistance: String = "moderate"
    @Published var budgetPreference: String = "moderate"

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var setupCompleted = false

    // MARK: - Options
    let activityOptions = InterestOptions.activity
    let lifestyleOptions = InterestOptions.lifestyle
    let socialOptions = InterestOptions.social
    let paceOptions = InterestOptions.paceOptions
    let distanceOptions = InterestOptions.distanceOptions
    let budgetOptions = InterestOptions.budgetOptions

    // MARK: - Initialization
    init() {
        Task {
            await loadExistingInterests()
        }
    }

    // MARK: - Toggle Methods
    func toggleActivity(_ id: String) {
        if selectedActivities.contains(id) {
            selectedActivities.remove(id)
        } else {
            selectedActivities.insert(id)
        }
    }

    func toggleLifestyle(_ id: String) {
        if selectedLifestyle.contains(id) {
            selectedLifestyle.remove(id)
        } else {
            selectedLifestyle.insert(id)
        }
    }

    func toggleSocial(_ id: String) {
        if selectedSocial.contains(id) {
            selectedSocial.remove(id)
        } else {
            selectedSocial.insert(id)
        }
    }

    // MARK: - API Methods
    func loadExistingInterests() async {
        guard let userId = UserDefaults.standard.value(forKey: "userId") as? Int64 else { return }
        guard let token = KeychainManager.shared.getAccessToken() else {
            print("No access token available for loading interests")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            guard let url = URL(string: "\(Constants.API.baseURL)/api/v1/interests") else {
                throw URLError(.badURL)
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(String(userId), forHTTPHeaderField: "X-User-ID")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let interests = try JSONDecoder().decode(UserInterests.self, from: data)

            selectedActivities = Set(interests.activityInterests)
            selectedLifestyle = Set(interests.lifestyleInterests)
            selectedSocial = Set(interests.socialInterests)
            weekendPace = interests.preferredWeekendPace ?? "balanced"
            outingDistance = interests.preferredOutingDistance ?? "moderate"
            budgetPreference = interests.budgetPreference ?? "moderate"
            setupCompleted = interests.setupCompleted

            print("Loaded interests: \(interests.activityInterests.count) activities, \(interests.lifestyleInterests.count) lifestyle, \(interests.socialInterests.count) social")

        } catch {
            print("Failed to load interests: \(error.localizedDescription)")
            // Not showing error - user may not have interests set up yet
        }

        isLoading = false
    }

    func saveInterests() async -> Bool {
        guard let userId = UserDefaults.standard.value(forKey: "userId") as? Int64 else {
            errorMessage = "Please sign in first"
            return false
        }
        guard let token = KeychainManager.shared.getAccessToken() else {
            errorMessage = "Please sign in first"
            return false
        }

        isSaving = true
        errorMessage = nil

        do {
            guard let url = URL(string: "\(Constants.API.baseURL)/api/v1/interests") else {
                throw URLError(.badURL)
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(String(userId), forHTTPHeaderField: "X-User-ID")

            var interests = UserInterests()
            interests.activityInterests = Array(selectedActivities)
            interests.lifestyleInterests = Array(selectedLifestyle)
            interests.socialInterests = Array(selectedSocial)
            interests.preferredWeekendPace = weekendPace
            interests.preferredOutingDistance = outingDistance
            interests.budgetPreference = budgetPreference
            interests.setupCompleted = true

            request.httpBody = try JSONEncoder().encode(interests)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("Save interests failed: \(responseStr)")
                }
                throw URLError(.badServerResponse)
            }

            setupCompleted = true
            print("Interests saved successfully")

            isSaving = false
            return true

        } catch {
            errorMessage = "Failed to save interests: \(error.localizedDescription)"
            print("Save interests error: \(error)")
            isSaving = false
            return false
        }
    }

    // MARK: - Computed Properties
    var hasAnySelection: Bool {
        !selectedActivities.isEmpty || !selectedLifestyle.isEmpty || !selectedSocial.isEmpty
    }

    var totalSelected: Int {
        selectedActivities.count + selectedLifestyle.count + selectedSocial.count
    }

    var paceDisplayName: String {
        switch weekendPace {
        case "relaxed": return "Relaxed"
        case "active": return "Active"
        default: return "Balanced"
        }
    }

    var distanceDisplayName: String {
        switch outingDistance {
        case "nearby": return "Nearby (<10 mi)"
        case "willing_to_travel": return "Willing to Travel"
        default: return "Moderate (10-30 mi)"
        }
    }

    var budgetDisplayName: String {
        switch budgetPreference {
        case "budget": return "Budget-Friendly"
        case "premium": return "Premium"
        default: return "Moderate"
        }
    }
}
