import Foundation
import SwiftUI
import Combine

@MainActor
class OnDemandRecommendationsViewModel: ObservableObject {
    @Published var healthyOptions: [FoodSpot] = []
    @Published var regularOptions: [FoodSpot] = []
    @Published var walkRoutes: [OnDemandWalkRoute] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let api = OnDemandRecommendationsAPI()
    
    func loadRecommendations() async {
        await refreshFood(category: "all", radius: 1.5)
        await refreshWalks(distanceMiles: 1.0, difficulty: "easy")
    }
    
    func refreshFood(category: String, radius: Double = 1.5) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let response = try await api.getFoodRecommendations(category: category, radius: radius)
            healthyOptions = response.healthyOptions
            regularOptions = response.regularOptions
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
            walkRoutes = response.routes
            print("✅ ViewModel: Loaded \(walkRoutes.count) walk routes")
        } catch {
            print("❌ ViewModel: Failed to load walk recommendations: \(error)")
            errorMessage = "Failed to load walk routes: \(error.localizedDescription)"
        }
    }
}

enum FoodCategory: String, CaseIterable {
    case all = "all"
    case healthy = "healthy"
    case regular = "regular"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .healthy: return "Healthy"
        case .regular: return "Regular"
        }
    }
}

enum WalkDifficulty: String, CaseIterable {
    case easy = "easy"
    case moderate = "moderate"
    case challenging = "challenging"
    
    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .moderate: return "Moderate"
        case .challenging: return "Challenging"
        }
    }
}

