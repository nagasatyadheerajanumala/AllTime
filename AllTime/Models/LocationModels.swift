import Foundation

// Backward compatibility aliases
typealias HealthBasedSuggestion = DailyHealthSuggestion

// MARK: - Complete Daily Summary Response (v2 spec, /api/v1/daily-summary)
struct DailySummaryResponse: Codable {
    // Arrays are always present (non-null) per backend contract
    let daySummary: [String]
    let healthSummary: [String]
    let focusRecommendations: [String]
    let alerts: [String]
    let healthBasedSuggestions: [DailyHealthSuggestion]
    
    // Objects can be null
    let locationRecommendations: LocationRecommendations?
    let breakRecommendations: DailyBreakRecommendations?
    
    enum CodingKeys: String, CodingKey {
        case daySummary = "day_summary"
        case healthSummary = "health_summary"
        case focusRecommendations = "focus_recommendations"
        case alerts
        case healthBasedSuggestions = "health_based_suggestions"
        case locationRecommendations = "location_recommendations"
        case breakRecommendations = "break_recommendations"
    }
}

// MARK: - Health Suggestion (v2 spec)
struct DailyHealthSuggestion: Codable, Identifiable {
    var id: String { title + description }
    
    let title: String
    let description: String
    let category: String   // hydration, sleep, exercise, stress
    let priority: String   // low, medium, high, urgent
    let icon: String?
}

// MARK: - Location Recommendations (v2 spec)
struct LocationRecommendations: Codable {
    let lunchSuggestions: [LunchPlace]?
    let walkRoutes: [WalkRoute]?
    
    enum CodingKeys: String, CodingKey {
        case lunchSuggestions = "lunch_suggestions"
        case walkRoutes = "walk_routes"
    }
}

// Backward compatibility for older screens expecting LunchRecommendation / LunchSpot
typealias LunchSpot = LunchPlace

struct LunchRecommendation: Codable {
    let recommendationTime: String?
    let minutesUntilLunch: Int?
    let message: String?
    let nearbySpots: [LunchPlace]?
    
    enum CodingKeys: String, CodingKey {
        case recommendationTime = "recommendation_time"
        case minutesUntilLunch = "minutes_until_lunch"
        case message
        case nearbySpots = "nearby_spots"
    }
}

// MARK: - Lunch Place (v2 spec)
struct LunchPlace: Codable, Identifiable {
    var id: String { name + (address ?? "") }
    
    let name: String
    let address: String?
    let rating: Double?
    let priceLevel: String?
    let cuisine: String?
    let distanceKm: Double?
    let walkingMinutes: Int?
    let isOpenNow: Bool?
    let quickGrab: Bool?
    let photoUrl: String?
    
    // Backend returns camelCase for these fields
    enum CodingKeys: String, CodingKey {
        case name, address, rating, cuisine, quickGrab, photoUrl, priceLevel, isOpenNow, walkingMinutes, distanceKm
    }
}

// MARK: - Walk Route (v2 spec)
struct WalkRoute: Codable, Identifiable {
    var id: String { name }
    
    let name: String
    let description: String
    let distanceKm: Double
    let estimatedMinutes: Int
    let difficulty: String
    let routeType: String?
    let waypoints: [Waypoint]?
    let mapUrl: String?
    let highlights: [String]?
    let elevationGain: Double?
    let wheelchairAccessible: Bool?
    let bestTimeOfDay: String?
    
    // Backward-compatibility helper for callers expecting durationMinutes
    var durationMinutes: Int { estimatedMinutes }
    
    // Backend returns camelCase for these fields
    enum CodingKeys: String, CodingKey {
        case name, description, difficulty, waypoints, highlights, distanceKm, estimatedMinutes, routeType, mapUrl, elevationGain, wheelchairAccessible, bestTimeOfDay
    }
}

// MARK: - Waypoint (v2 spec)
struct Waypoint: Codable {
    let latitude: Double
    let longitude: Double
    let label: String?
}

// MARK: - Break Recommendations (v2 spec)
struct DailyBreakRecommendations: Codable {
    let strategy: String?
    let overallBreakStrategy: String?
    let suggestedBreaks: [DailyBreakWindow]?
    let minutesUntilLunch: Int?
    
    enum CodingKeys: String, CodingKey {
        case strategy
        case overallBreakStrategy = "overall_break_strategy"
        case suggestedBreaks = "suggested_breaks"
        case minutesUntilLunch = "minutes_until_lunch"
    }
}

// MARK: - Break Window (v2 spec)
struct DailyBreakWindow: Codable, Identifiable {
    var id: String { (suggestedTime ?? "") + purpose }
    
    let purpose: String            // hydration, meal, rest, movement, prep
    let suggestedTime: String?     // "10:30 AM"
    let durationMinutes: Int?
    let reasoning: String
    
    enum CodingKeys: String, CodingKey {
        case purpose
        case suggestedTime = "suggested_time"
        case durationMinutes = "duration_minutes"
        case reasoning
    }
}

