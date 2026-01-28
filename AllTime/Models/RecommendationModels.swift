import Foundation
import SwiftUI

// MARK: - Food Recommendations Response

struct FoodRecommendationsResponse: Codable {
    let healthyOptions: [FoodSpot]?
    let regularOptions: [FoodSpot]?
    let userLocation: String?
    let searchRadiusKm: Double?
    let searchRadiusMiles: Double?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case healthyOptions
        case regularOptions
        case userLocation
        case searchRadiusKm
        case searchRadiusMiles
        case message
    }
}

struct FoodSpot: Codable, Identifiable {
    let name: String
    let address: String?
    let distanceKm: Double?
    let distanceMiles: Double?
    let walkingMinutes: Int?
    let rating: Double?
    let reviewCount: Int?
    let priceLevel: String?
    let cuisine: String?
    let category: String?  // "healthy", "fast_food", "fine_dining", "casual", "cafe"
    let openNow: Bool?
    let photoUrl: String?
    let categories: [String]?
    let healthScore: String?
    let dietaryTags: [String]?
    let features: [String]?  // ["Outdoor Seating", "Delivery", "Takeout"]
    let latitude: Double?
    let longitude: Double?
    let placeId: String?
    let mapUrl: String?

    // New dietary flags from backend
    let isHealthy: Bool?
    let isVegan: Bool?
    let isVegetarian: Bool?
    let isGlutenFree: Bool?
    let isOrganic: Bool?
    let isHalal: Bool?
    let isKosher: Bool?
    let hasVeganOptions: Bool?
    let hasVegetarianOptions: Bool?
    let hasGlutenFreeOptions: Bool?

    var id: String { placeId ?? (name + (address ?? "")) }

    enum CodingKeys: String, CodingKey {
        case name, address, rating, cuisine, categories, latitude, longitude, category, features
        case distanceKm = "distance_km"
        case distanceMiles = "distance_miles"
        case walkingMinutes = "walking_minutes"
        case priceLevel = "price_level"
        case reviewCount = "review_count"
        case openNow = "open_now"
        case photoUrl = "photo_url"
        case healthScore = "health_score"
        case dietaryTags = "dietary_tags"
        case placeId = "place_id"
        case mapUrl = "map_url"
        case isHealthy = "is_healthy"
        case isVegan = "is_vegan"
        case isVegetarian = "is_vegetarian"
        case isGlutenFree = "is_gluten_free"
        case isOrganic = "is_organic"
        case isHalal = "is_halal"
        case isKosher = "is_kosher"
        case hasVeganOptions = "has_vegan_options"
        case hasVegetarianOptions = "has_vegetarian_options"
        case hasGlutenFreeOptions = "has_gluten_free_options"
    }

    // Computed properties for UI
    var formattedDistance: String {
        // Prefer distanceMiles if available from API
        if let miles = distanceMiles {
            return String(format: "%.1f mi", miles)
        }
        // Fallback to converting from km
        guard let km = distanceKm else { return "" }
        let miles = km * 0.621371
        return String(format: "%.1f mi", miles)
    }

    var formattedWalkTime: String {
        guard let mins = walkingMinutes else { return "" }
        return "\(mins) min walk"
    }

    var healthScoreColor: Color {
        // Use isHealthy flag if available, fallback to healthScore
        if isHealthy == true {
            return .green
        }
        switch healthScore?.lowercased() {
        case "excellent": return .green
        case "good": return .blue
        case "moderate": return .orange
        case "indulgent": return .red
        default: return .gray
        }
    }

    var priceLevelDisplay: String {
        priceLevel ?? ""
    }

    var formattedReviewCount: String {
        guard let count = reviewCount else { return "" }
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }

    /// Check if spot matches dietary preference
    func matchesDietaryFilter(_ filter: DietaryFilter) -> Bool {
        switch filter {
        case .healthy: return isHealthy == true
        case .vegan: return isVegan == true || hasVeganOptions == true
        case .vegetarian: return isVegetarian == true || hasVegetarianOptions == true
        case .glutenFree: return isGlutenFree == true || hasGlutenFreeOptions == true
        case .organic: return isOrganic == true
        case .halal: return isHalal == true
        case .kosher: return isKosher == true
        }
    }
}

/// Dietary filter options
enum DietaryFilter: String, CaseIterable {
    case healthy = "Healthy"
    case vegan = "Vegan"
    case vegetarian = "Vegetarian"
    case glutenFree = "Gluten-Free"
    case organic = "Organic"
    case halal = "Halal"
    case kosher = "Kosher"

    var icon: String {
        switch self {
        case .healthy: return "leaf.fill"
        case .vegan: return "sparkle"
        case .vegetarian: return "carrot.fill"
        case .glutenFree: return "checkmark.seal.fill"
        case .organic: return "leaf.arrow.circlepath"
        case .halal: return "moon.stars.fill"
        case .kosher: return "star.of.david.fill"
        }
    }

    var color: Color {
        switch self {
        case .healthy: return .green
        case .vegan: return Color(red: 0.2, green: 0.8, blue: 0.6)
        case .vegetarian: return .orange
        case .glutenFree: return .purple
        case .organic: return Color(red: 0.1, green: 0.6, blue: 0.3)
        case .halal: return .teal
        case .kosher: return .blue
        }
    }
}

// MARK: - Walk Recommendations Response

struct WalkRecommendationsResponse: Codable {
    let userLocation: String?
    let requestedDurationMinutes: Int?
    let difficulty: String?
    let routes: [WalkRouteRecommendation]?
    let healthBenefit: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case userLocation
        case requestedDurationMinutes
        case difficulty
        case routes
        case healthBenefit
        case message
    }
}

struct WalkRouteRecommendation: Codable, Identifiable {
    let name: String
    let description: String?
    let distanceKm: Double?
    let distanceMiles: Double?
    let estimatedMinutes: Int?
    let difficulty: String?
    let routeType: String?
    let waypoints: [WalkWaypoint]?
    let mapUrl: String?
    let highlights: [String]?
    let elevationGain: Double?
    let wheelchairAccessible: Bool?
    let bestTimeOfDay: String?

    var id: String { name + (routeType ?? "") }

    enum CodingKeys: String, CodingKey {
        case name, description, difficulty, waypoints, highlights
        case distanceKm
        case distanceMiles
        case estimatedMinutes
        case routeType
        case mapUrl
        case elevationGain
        case wheelchairAccessible
        case bestTimeOfDay
    }

    // Computed properties
    var formattedDistance: String {
        // Prefer distanceMiles if available from API
        if let miles = distanceMiles {
            return String(format: "%.1f mi", miles)
        }
        // Fallback to converting from km
        guard let km = distanceKm else { return "" }
        let miles = km * 0.621371
        return String(format: "%.1f mi", miles)
    }

    var formattedDuration: String {
        guard let mins = estimatedMinutes else { return "" }
        if mins >= 60 {
            let hours = mins / 60
            let remainingMins = mins % 60
            return remainingMins > 0 ? "\(hours)h \(remainingMins)m" : "\(hours)h"
        }
        return "\(mins) min"
    }

    var difficultyColor: Color {
        switch difficulty?.lowercased() {
        case "easy": return .green
        case "moderate": return .orange
        case "challenging", "hard": return .red
        default: return .gray
        }
    }

    var routeTypeIcon: String {
        switch routeType?.lowercased() {
        case "park": return "leaf.fill"
        case "neighborhood": return "house.fill"
        case "urban": return "building.2.fill"
        case "scenic": return "mountain.2.fill"
        default: return "figure.walk"
        }
    }
}

// Waypoint moved to RecommendationModels to avoid duplication
struct WalkWaypoint: Codable {
    let latitude: Double?
    let longitude: Double?
    let name: String?
    let description: String?
}

// MARK: - Walk Difficulty Enum

enum WalkDifficulty: String, CaseIterable {
    case easy = "easy"
    case moderate = "moderate"
    case challenging = "challenging"

    var displayName: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .easy: return .green
        case .moderate: return .orange
        case .challenging: return .red
        }
    }

    var icon: String {
        switch self {
        case .easy: return "figure.walk"
        case .moderate: return "figure.walk.motion"
        case .challenging: return "figure.run"
        }
    }

    var emoji: String {
        switch self {
        case .easy: return "🚶"
        case .moderate: return "🚶‍♂️"
        case .challenging: return "🏃"
        }
    }

    var suggestedDistanceRange: ClosedRange<Double> {
        switch self {
        case .easy: return 0.25...1.0
        case .moderate: return 1.0...2.0
        case .challenging: return 2.0...5.0
        }
    }

    var description: String {
        switch self {
        case .easy: return "Short, flat, casual"
        case .moderate: return "Standard, some variety"
        case .challenging: return "Longer, may have hills"
        }
    }
}

// MARK: - Food Category Enum

enum FoodCategory: String, CaseIterable {
    case all = "all"
    case healthy = "healthy"
    case regular = "regular"

    var displayName: String {
        switch self {
        case .all: return "All Options"
        case .healthy: return "Healthy"
        case .regular: return "Regular"
        }
    }

    var icon: String {
        switch self {
        case .all: return "fork.knife"
        case .healthy: return "leaf.fill"
        case .regular: return "takeoutbag.and.cup.and.straw.fill"
        }
    }

    var color: Color {
        switch self {
        case .all: return .blue
        case .healthy: return .green
        case .regular: return .orange
        }
    }
}
