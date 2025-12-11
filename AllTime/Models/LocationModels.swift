import Foundation

// MARK: - Complete Daily Summary Response (from /api/v1/daily-summary)
// Note: This response type uses the DailySummary types defined in DailySummary.swift
// to avoid duplicate type definitions.

// MARK: - API Health Based Suggestion (different from DailySummarySuggestion)
// Used by specific location API endpoints
struct APIHealthBasedSuggestion: Codable, Identifiable {
    var id: String { type + (timestamp ?? "") }
    let type: String
    let priority: String
    let message: String
    let action: String
    let timestamp: String?
}

// MARK: - Lunch Spot (used by location API)
struct LunchSpot: Codable, Identifiable {
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

    enum CodingKeys: String, CodingKey {
        case name, address, rating, cuisine
        case distanceKm = "distance_km"
        case walkingMinutes = "walking_minutes"
        case priceLevel = "price_level"
        case openNow = "open_now"
        case photoUrl = "photo_url"
    }
}

// MARK: - Legacy Support (for old endpoints if needed)
struct LunchRecommendations: Codable {
    let recommendationTime: String?
    let minutesUntilLunch: Int?
    let message: String
    let nearbySpots: [LunchSpot]

    enum CodingKeys: String, CodingKey {
        case recommendationTime = "recommendationTime"
        case minutesUntilLunch = "minutesUntilLunch"
        case message
        case nearbySpots = "nearbySpots"
    }
}

struct WalkRoutes: Codable {
    let suggestedTime: String?
    let durationMinutes: Int
    let distanceKm: Double
    let routeType: String
    let healthBenefit: String
    let routes: [WalkRoute]

    enum CodingKeys: String, CodingKey {
        case suggestedTime = "suggestedTime"
        case durationMinutes = "durationMinutes"
        case distanceKm = "distanceKm"
        case routeType = "routeType"
        case healthBenefit = "healthBenefit"
        case routes
    }
}
