import Foundation
import SwiftUI
import Combine
import CoreLocation

/// ViewModel for Weekend Quick Pick feature
@MainActor
class WeekendQuickPickViewModel: ObservableObject {
    // User's saved interests
    @Published var userInterests: UserInterestsResponse?
    @Published var isLoading = false
    @Published var isGenerating = false
    @Published var showError = false
    @Published var errorMessage: String?

    // Quick pick selections for today
    @Published var selectedActivities: Set<String> = []
    @Published var selectedLifestyle: Set<String> = []
    @Published var selectedSocial: Set<String> = []

    // Mood and preferences
    @Published var selectedMood: WeekendMood = .balanced
    @Published var selectedPace: String = "balanced"
    @Published var selectedDistance: String = "moderate"

    // Available options (filtered from user's saved interests)
    var availableActivities: [InterestOption] = []
    var availableLifestyle: [InterestOption] = []
    var availableSocial: [InterestOption] = []

    private let apiService = APIService()
    private let locationManager = LocationManager.shared

    var hasAnySelection: Bool {
        !selectedActivities.isEmpty || !selectedLifestyle.isEmpty || !selectedSocial.isEmpty
    }

    // MARK: - Load User Interests
    func loadUserInterests() {
        isLoading = true

        Task {
            do {
                let interests = try await apiService.getUserInterests()
                self.userInterests = interests

                // Map user's saved interests to InterestOption objects
                mapInterestsToOptions(interests)

                isLoading = false
            } catch {
                print("Failed to load interests: \(error)")
                isLoading = false
                // Don't show error - just show empty state
            }
        }
    }

    // MARK: - Map Interests to Options
    private func mapInterestsToOptions(_ interests: UserInterestsResponse) {
        // Get full option list
        let allActivityOptions = InterestOptions.activity
        let allLifestyleOptions = InterestOptions.lifestyle
        let allSocialOptions = InterestOptions.social

        // Filter to only user's selected interests
        let userActivities = interests.activityInterests
        availableActivities = allActivityOptions.filter { userActivities.contains($0.id) }

        let userLifestyle = interests.lifestyleInterests
        availableLifestyle = allLifestyleOptions.filter { userLifestyle.contains($0.id) }

        let userSocial = interests.socialInterests
        availableSocial = allSocialOptions.filter { userSocial.contains($0.id) }

        // Pre-select based on mood
        preselectBasedOnMood()
    }

    // MARK: - Preselect Based on Mood
    private func preselectBasedOnMood() {
        // Clear previous selections
        selectedActivities.removeAll()
        selectedLifestyle.removeAll()
        selectedSocial.removeAll()

        // Suggest 1-2 from each category based on mood
        switch selectedMood {
        case .energetic:
            // Suggest active/fitness activities
            let energeticActivities = ["gym", "running", "hiking", "cycling", "crossfit", "dance"]
            if let first = availableActivities.first(where: { energeticActivities.contains($0.id) }) {
                selectedActivities.insert(first.id)
            }

        case .relaxed:
            // Suggest chill activities
            let relaxedLifestyle = ["reading", "meditation", "spa", "gardening", "cooking"]
            if let first = availableLifestyle.first(where: { relaxedLifestyle.contains($0.id) }) {
                selectedLifestyle.insert(first.id)
            }

        case .social:
            // Suggest social activities
            let socialActivities = ["friends", "dining_out", "brunch", "bars", "family_time"]
            if let first = availableSocial.first(where: { socialActivities.contains($0.id) }) {
                selectedSocial.insert(first.id)
            }

        case .adventurous:
            // Suggest outdoor/adventure activities
            let adventureActivities = ["hiking", "camping", "kayaking", "rock_climbing", "surfing", "skiing"]
            if let first = availableActivities.first(where: { adventureActivities.contains($0.id) }) {
                selectedActivities.insert(first.id)
            }
            if let travel = availableSocial.first(where: { $0.id == "travel" }) {
                selectedSocial.insert(travel.id)
            }
        }
    }

    // MARK: - Generate Plan
    func generatePlan() async -> WeekendPlanResponse? {
        guard hasAnySelection else { return nil }

        isGenerating = true

        do {
            // Get current location
            var location: (lat: Double, lng: Double, city: String)?
            if let currentLocation = locationManager.location {
                location = (
                    lat: currentLocation.coordinate.latitude,
                    lng: currentLocation.coordinate.longitude,
                    city: locationManager.locationString ?? "Your Area"
                )
            }

            // Build request
            let request = QuickPickPlanRequest(
                selectedActivities: Array(selectedActivities),
                selectedLifestyle: Array(selectedLifestyle),
                selectedSocial: Array(selectedSocial),
                mood: selectedMood.rawValue,
                pace: selectedPace,
                maxDistance: selectedDistance,
                latitude: location?.lat,
                longitude: location?.lng,
                cityName: location?.city,
                timezone: TimeZone.current.identifier
            )

            let plan = try await apiService.generateQuickPickPlan(request: request)
            isGenerating = false
            return plan

        } catch {
            print("Failed to generate plan: \(error)")
            errorMessage = "Failed to generate your plan. Please try again."
            showError = true
            isGenerating = false
            return nil
        }
    }
}

// MARK: - Extended Mood Enum
extension WeekendMood {
    static var balanced: WeekendMood { .relaxed }
}

// MARK: - Quick Pick Plan Request
struct QuickPickPlanRequest: Codable {
    let selectedActivities: [String]
    let selectedLifestyle: [String]
    let selectedSocial: [String]
    let mood: String
    let pace: String
    let maxDistance: String
    let latitude: Double?
    let longitude: Double?
    let cityName: String?
    let timezone: String?
}

// WeekendPlanResponse and PlannedActivity are defined in AIDayPlannerService.swift
