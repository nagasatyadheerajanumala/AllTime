import Foundation
import CoreLocation
import Combine

/// Service for AI-powered weekend and day planning
/// Uses user interests, location, and OpenAI to generate personalized itineraries
@MainActor
class AIDayPlannerService: ObservableObject {
    static let shared = AIDayPlannerService()

    // MARK: - Published Properties
    @Published var isGenerating = false
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let apiService = APIService.shared
    private let locationManager = LocationManager.shared
    private let baseURL = Constants.API.baseURL

    private init() {}

    // MARK: - Generate Weekend Plan

    /// Generate an AI-powered weekend plan based on user interests and location
    func generateWeekendPlan(
        date: Date,
        interests: UserInterests,
        location: CLLocation?,
        locationName: String?
    ) async throws -> WeekendPlanResponse {
        isGenerating = true
        errorMessage = nil

        defer { isGenerating = false }

        guard let token = KeychainManager.shared.getAccessToken() else {
            throw AIPlannerError.notAuthenticated
        }

        guard let userId = UserDefaults.standard.value(forKey: "userId") as? Int64 else {
            throw AIPlannerError.notAuthenticated
        }

        // Build the request
        guard let url = URL(string: "\(baseURL)/api/v1/planning/weekend-plan") else {
            throw AIPlannerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(String(userId), forHTTPHeaderField: "X-User-ID")
        request.timeoutInterval = 60 // AI generation can take longer

        // Create request body
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let requestBody = WeekendPlanRequest(
            date: formatter.string(from: date),
            interests: InterestsPayload(
                activities: interests.activityInterests,
                lifestyle: interests.lifestyleInterests,
                social: interests.socialInterests
            ),
            preferences: PlanPreferences(
                pace: interests.preferredWeekendPace ?? "balanced",
                maxDistance: interests.preferredOutingDistance ?? "moderate",
                budget: interests.budgetPreference ?? "moderate",
                maxActivities: interests.maxDailyActivities ?? 4,
                startTime: interests.preferredStartTime ?? "09:00"
            ),
            location: location != nil ? LocationPayload(
                latitude: location!.coordinate.latitude,
                longitude: location!.coordinate.longitude,
                cityName: locationName
            ) : nil,
            timezone: TimeZone.current.identifier
        )

        request.httpBody = try JSONEncoder().encode(requestBody)

        print("🤖 AIDayPlanner: Generating weekend plan for \(formatter.string(from: date))...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIPlannerError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let planResponse = try JSONDecoder().decode(WeekendPlanResponse.self, from: data)
            print("✅ AIDayPlanner: Generated plan with \(planResponse.activities.count) activities")
            return planResponse
        } else if httpResponse.statusCode == 503 || httpResponse.statusCode == 504 {
            // Service unavailable - generate local plan
            print("⚠️ AIDayPlanner: Backend unavailable, generating local plan...")
            return try await generateLocalPlan(date: date, interests: interests, locationName: locationName)
        } else {
            if let errorData = String(data: data, encoding: .utf8) {
                print("❌ AIDayPlanner: Error response: \(errorData)")
            }
            throw AIPlannerError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Generate Local Plan (Fallback)

    /// Generate a local plan when backend is unavailable
    private func generateLocalPlan(
        date: Date,
        interests: UserInterests,
        locationName: String?
    ) async throws -> WeekendPlanResponse {
        let calendar = Calendar.current
        let isWeekend = calendar.isDateInWeekend(date)
        let dayOfWeek = calendar.component(.weekday, from: date)
        let isSaturday = dayOfWeek == 7
        let isSunday = dayOfWeek == 1

        var activities: [PlannedActivity] = []
        var currentHour = 9 // Start at 9 AM

        // Morning activity based on interests
        if interests.activityInterests.contains("yoga") || interests.activityInterests.contains("gym") {
            activities.append(PlannedActivity(
                id: UUID().uuidString,
                title: interests.activityInterests.contains("yoga") ? "Morning Yoga Session" : "Morning Workout",
                description: "Start your day with some energizing exercise",
                category: "fitness",
                startTime: "\(String(format: "%02d", currentHour)):00",
                endTime: "\(String(format: "%02d", currentHour + 1)):00",
                duration: 60,
                location: interests.activityInterests.contains("yoga") ? "Local yoga studio or at home" : "Gym",
                icon: interests.activityInterests.contains("yoga") ? "figure.yoga" : "dumbbell.fill",
                estimatedCost: interests.activityInterests.contains("yoga") ? "$15-20" : "$0-20",
                notes: nil
            ))
            currentHour += 1
        }

        // Brunch/Breakfast (10-11 AM)
        currentHour = max(currentHour, 10)
        if interests.socialInterests.contains("dining_out") {
            activities.append(PlannedActivity(
                id: UUID().uuidString,
                title: isSaturday ? "Weekend Brunch" : "Relaxed Breakfast",
                description: "Enjoy a leisurely meal at a local spot",
                category: "dining",
                startTime: "\(String(format: "%02d", currentHour)):30",
                endTime: "\(String(format: "%02d", currentHour + 1)):30",
                duration: 60,
                location: locationName != nil ? "Popular brunch spots in \(locationName!)" : "Local cafe or restaurant",
                icon: "fork.knife.circle.fill",
                estimatedCost: "$15-30",
                notes: "Consider making a reservation for popular places"
            ))
            currentHour += 2
        } else {
            currentHour += 1
        }

        // Mid-day activity based on interests
        if interests.activityInterests.contains("hiking") && isSaturday {
            activities.append(PlannedActivity(
                id: UUID().uuidString,
                title: "Nature Hike",
                description: "Explore local trails and enjoy the outdoors",
                category: "outdoor",
                startTime: "\(String(format: "%02d", currentHour)):00",
                endTime: "\(String(format: "%02d", currentHour + 3)):00",
                duration: 180,
                location: locationName != nil ? "Trails near \(locationName!)" : "Local hiking trails",
                icon: "figure.hiking",
                estimatedCost: "Free",
                notes: "Bring water and snacks, check weather beforehand"
            ))
            currentHour += 3
        } else if interests.socialInterests.contains("museums") {
            activities.append(PlannedActivity(
                id: UUID().uuidString,
                title: "Museum Visit",
                description: "Explore art, history, or science exhibits",
                category: "culture",
                startTime: "\(String(format: "%02d", currentHour)):00",
                endTime: "\(String(format: "%02d", currentHour + 2)):00",
                duration: 120,
                location: locationName != nil ? "Museums in \(locationName!)" : "Local museum",
                icon: "building.columns.fill",
                estimatedCost: "$10-25",
                notes: "Check for free admission days or times"
            ))
            currentHour += 2
        } else if interests.socialInterests.contains("shopping") {
            activities.append(PlannedActivity(
                id: UUID().uuidString,
                title: "Shopping Trip",
                description: "Browse local shops or mall",
                category: "shopping",
                startTime: "\(String(format: "%02d", currentHour)):00",
                endTime: "\(String(format: "%02d", currentHour + 2)):00",
                duration: 120,
                location: locationName != nil ? "Shopping areas in \(locationName!)" : "Local mall or downtown shops",
                icon: "bag.fill",
                estimatedCost: "Varies",
                notes: nil
            ))
            currentHour += 2
        }

        // Afternoon break/activity
        currentHour = max(currentHour, 14)
        if interests.lifestyleInterests.contains("reading") || interests.lifestyleInterests.contains("podcasts") {
            activities.append(PlannedActivity(
                id: UUID().uuidString,
                title: "Relaxation Time",
                description: interests.lifestyleInterests.contains("reading") ? "Read a book at a cozy cafe" : "Listen to podcasts while walking",
                category: "relaxation",
                startTime: "\(String(format: "%02d", currentHour)):00",
                endTime: "\(String(format: "%02d", currentHour + 1)):30",
                duration: 90,
                location: "Local cafe or park",
                icon: interests.lifestyleInterests.contains("reading") ? "book.fill" : "headphones",
                estimatedCost: "$5-10",
                notes: nil
            ))
            currentHour += 2
        }

        // Dinner
        currentHour = max(currentHour, 18)
        activities.append(PlannedActivity(
            id: UUID().uuidString,
            title: "Dinner",
            description: interests.socialInterests.contains("family_time") ? "Family dinner at a nice restaurant" : "Dinner with friends or solo",
            category: "dining",
            startTime: "\(String(format: "%02d", currentHour)):30",
            endTime: "\(String(format: "%02d", currentHour + 2)):00",
            duration: 90,
            location: locationName != nil ? "Restaurants in \(locationName!)" : "Local restaurant",
            icon: "fork.knife",
            estimatedCost: "$25-50",
            notes: "Make reservations for popular spots"
        ))
        currentHour += 2

        // Evening activity
        if interests.socialInterests.contains("movies_theater") {
            activities.append(PlannedActivity(
                id: UUID().uuidString,
                title: "Movie Night",
                description: "Catch a new release at the theater",
                category: "entertainment",
                startTime: "\(String(format: "%02d", currentHour)):00",
                endTime: "\(String(format: "%02d", currentHour + 2)):30",
                duration: 150,
                location: "Local movie theater",
                icon: "film.fill",
                estimatedCost: "$15-20",
                notes: "Book tickets online for best seats"
            ))
        } else if interests.socialInterests.contains("concerts") {
            activities.append(PlannedActivity(
                id: UUID().uuidString,
                title: "Live Music",
                description: "Check out local live music venues",
                category: "entertainment",
                startTime: "\(String(format: "%02d", currentHour)):00",
                endTime: "\(String(format: "%02d", currentHour + 2)):00",
                duration: 120,
                location: "Local music venue or bar",
                icon: "music.mic",
                estimatedCost: "$20-50",
                notes: "Check local event listings"
            ))
        }

        // Calculate totals
        let totalDuration = activities.reduce(0) { $0 + $1.duration }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"

        return WeekendPlanResponse(
            date: formatter.string(from: date),
            dayType: isWeekend ? "weekend" : "weekday",
            summary: "Your personalized \(isSaturday ? "Saturday" : isSunday ? "Sunday" : "day") plan based on your interests",
            activities: activities,
            totalDuration: totalDuration,
            estimatedBudget: calculateBudget(activities: activities),
            tips: generateTips(interests: interests, isWeekend: isWeekend),
            generatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    private func calculateBudget(activities: [PlannedActivity]) -> String {
        // Simple budget estimation
        let count = activities.count
        if count <= 2 { return "$30-50" }
        if count <= 4 { return "$50-100" }
        return "$100-150"
    }

    private func generateTips(interests: UserInterests, isWeekend: Bool) -> [String] {
        var tips: [String] = []

        if isWeekend {
            tips.append("Popular spots fill up fast on weekends - consider making reservations")
        }

        if interests.activityInterests.contains("hiking") || interests.activityInterests.contains("beach") {
            tips.append("Check the weather forecast before outdoor activities")
        }

        if interests.socialInterests.contains("dining_out") {
            tips.append("Consider trying a new restaurant you've been wanting to visit")
        }

        tips.append("Stay flexible - the best days often have room for spontaneity!")

        return tips
    }

    // MARK: - Get Nearby Places

    /// Fetch nearby places based on interests and location
    func getNearbyPlaces(
        location: CLLocation,
        interests: UserInterests,
        radius: Int = 5000
    ) async throws -> [NearbyPlace] {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw AIPlannerError.notAuthenticated
        }

        guard let url = URL(string: "\(baseURL)/api/v1/places/nearby") else {
            throw AIPlannerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let requestBody: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "radius": radius,
            "interests": interests.activityInterests + interests.lifestyleInterests + interests.socialInterests
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return [] // Return empty if places API fails
        }

        return try JSONDecoder().decode([NearbyPlace].self, from: data)
    }
}

// MARK: - Request Models

struct WeekendPlanRequest: Codable {
    let date: String
    let interests: InterestsPayload
    let preferences: PlanPreferences
    let location: LocationPayload?
    let timezone: String
}

struct InterestsPayload: Codable {
    let activities: [String]
    let lifestyle: [String]
    let social: [String]
}

struct PlanPreferences: Codable {
    let pace: String
    let maxDistance: String
    let budget: String
    let maxActivities: Int
    let startTime: String

    enum CodingKeys: String, CodingKey {
        case pace
        case maxDistance = "max_distance"
        case budget
        case maxActivities = "max_activities"
        case startTime = "start_time"
    }
}

struct LocationPayload: Codable {
    let latitude: Double
    let longitude: Double
    let cityName: String?

    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case cityName = "city_name"
    }
}

// MARK: - Response Models

struct WeekendPlanResponse: Codable {
    let date: String
    let dayType: String
    let summary: String
    let activities: [PlannedActivity]
    let totalDuration: Int
    let estimatedBudget: String
    let tips: [String]
    let generatedAt: String

    enum CodingKeys: String, CodingKey {
        case date
        case dayType = "day_type"
        case summary
        case activities
        case totalDuration = "total_duration"
        case estimatedBudget = "estimated_budget"
        case tips
        case generatedAt = "generated_at"
    }
}

struct PlannedActivity: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let category: String
    let startTime: String
    let endTime: String
    let duration: Int
    let location: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let googlePlaceId: String?
    let icon: String
    let estimatedCost: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case category
        case startTime = "start_time"
        case endTime = "end_time"
        case duration
        case location
        case address
        case latitude
        case longitude
        case googlePlaceId = "google_place_id"
        case icon
        case estimatedCost = "estimated_cost"
        case notes
    }

    // Custom initializer with default values for new optional fields
    init(
        id: String,
        title: String,
        description: String,
        category: String,
        startTime: String,
        endTime: String,
        duration: Int,
        location: String?,
        address: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        googlePlaceId: String? = nil,
        icon: String,
        estimatedCost: String?,
        notes: String?
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.location = location
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.googlePlaceId = googlePlaceId
        self.icon = icon
        self.estimatedCost = estimatedCost
        self.notes = notes
    }

    var categoryColor: Color {
        switch category.lowercased() {
        case "fitness", "outdoor": return .green
        case "dining": return .orange
        case "culture", "entertainment": return .purple
        case "shopping": return .pink
        case "relaxation": return .teal
        default: return .blue
        }
    }

    /// Check if this activity has valid coordinates for map navigation
    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }
}

struct NearbyPlace: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let address: String?
    let rating: Double?
    let distance: Int?
    let priceLevel: Int?
    let photoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case address
        case rating
        case distance
        case priceLevel = "price_level"
        case photoUrl = "photo_url"
    }
}

// MARK: - Errors

enum AIPlannerError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case noInterests
    case locationRequired

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to generate a plan"
        case .invalidURL:
            return "Invalid request URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error (\(code))"
        case .noInterests:
            return "Please set up your interests first"
        case .locationRequired:
            return "Location is required for personalized recommendations"
        }
    }
}

// Import Color for the categoryColor property
import SwiftUI
