import Foundation

// MARK: - On-Demand Food Recommendations

// Backend uses camelCase for food/walk APIs!
struct FoodRecommendationsResponse: Codable {
    let healthyOptions: [FoodSpot]
    let regularOptions: [FoodSpot]
    let userLocation: String
    let searchRadiusKm: Double
    let message: String
}

struct FoodSpot: Codable, Identifiable {
    var id: String { name + (address ?? "") }
    let name: String
    let address: String?
    let distanceKm: Double
    let walkingMinutes: Int
    let rating: Double?
    let priceLevel: String?
    let cuisine: String?
    let openNow: Bool?
    let photoUrl: String?
    let categories: [String]?
    let healthScore: String?
    let dietaryTags: [String]?
}

// MARK: - On-Demand Walk Recommendations

// Backend uses camelCase for walk recommendations!
struct WalkRecommendationsResponse: Codable {
    let userLocation: String
    let requestedDurationMinutes: Int
    let difficulty: String
    let healthBenefit: String
    let message: String
    let routes: [OnDemandWalkRoute]
}

struct OnDemandWalkRoute: Codable, Identifiable {
    var id: String { name }
    let name: String
    let description: String
    let distanceKm: Double
    let estimatedMinutes: Int
    let difficulty: String
    let routeType: String
    let waypoints: [Waypoint]
    let mapUrl: String
    let highlights: [String]
    let elevationGain: Double
    let wheelchairAccessible: Bool?
    let bestTimeOfDay: String?
}

