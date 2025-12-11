import Foundation
import SwiftUI
import Combine
import CoreLocation

@MainActor
class OnDemandRecommendationsViewModel: ObservableObject {
    @Published var healthyOptions: [FoodSpot] = []
    @Published var regularOptions: [FoodSpot] = []
    @Published var walkRoutes: [WalkRouteRecommendation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = OnDemandRecommendationsAPI()
    private let locationManager = LocationManager.shared

    func loadRecommendations() async {
        await refreshFood(category: "all", radiusMiles: 1.5)
        await refreshWalks(distanceMiles: 1.0, difficulty: "easy")
    }

    func refreshFood(category: String, radiusMiles: Double = 1.5) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Get current location - required for food recommendations
        var latitude = locationManager.location?.coordinate.latitude
        var longitude = locationManager.location?.coordinate.longitude

        // If no location, request it and wait
        if latitude == nil || longitude == nil {
            locationManager.startLocationUpdates()
            try? await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
            latitude = locationManager.location?.coordinate.latitude
            longitude = locationManager.location?.coordinate.longitude
        }

        do {
            let response = try await api.getFoodRecommendations(
                category: category,
                radiusMiles: radiusMiles,
                latitude: latitude,
                longitude: longitude
            )
            healthyOptions = response.healthyOptions ?? []
            regularOptions = response.regularOptions ?? []
            print("✅ ViewModel: Loaded \(healthyOptions.count) healthy + \(regularOptions.count) regular options")
        } catch {
            print("❌ ViewModel: Failed to load food recommendations: \(error)")
            errorMessage = "Failed to load food options: \(error.localizedDescription)"
        }
    }
    
    func refreshWalks(distanceMiles: Double, difficulty: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let response = try await api.getWalkRecommendations(distanceMiles: distanceMiles, difficulty: difficulty)
            walkRoutes = response.routes ?? []
            print("✅ ViewModel: Loaded \(walkRoutes.count) walk routes")
        } catch {
            print("❌ ViewModel: Failed to load walk recommendations: \(error)")
            errorMessage = "Failed to load walk routes: \(error.localizedDescription)"
        }
    }
}

// FoodCategory and WalkDifficulty enums are defined in RecommendationModels.swift

