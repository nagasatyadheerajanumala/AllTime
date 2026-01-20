import Foundation

// MARK: - Day Suggestions Response

struct DaySuggestionsResponse: Codable {
    let date: String
    let dayType: String
    let dayTypeLabel: String
    let isRestDay: Bool
    let message: String?
    let needsSetup: Bool?
    let suggestions: [ActivitySuggestion]?

    enum CodingKeys: String, CodingKey {
        case date
        case dayType = "day_type"
        case dayTypeLabel = "day_type_label"
        case isRestDay = "is_rest_day"
        case message
        case needsSetup = "needs_setup"
        case suggestions
    }
}

// MARK: - Activity Suggestion

struct ActivitySuggestion: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let category: String
    let icon: String
    let color: String?
    let recommendedTime: String?
    let durationMinutes: Int?
    let location: PlaceInfo?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case category
        case icon
        case color
        case recommendedTime = "recommended_time"
        case durationMinutes = "duration_minutes"
        case location
    }

    var categoryColor: Color {
        guard let hex = color else {
            return .blue
        }
        return Color(hex: hex)
    }

    var formattedDuration: String? {
        guard let mins = durationMinutes else { return nil }
        if mins < 60 {
            return "\(mins) min"
        } else {
            let hours = mins / 60
            let remaining = mins % 60
            if remaining == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(remaining)m"
        }
    }

    var formattedTime: String? {
        guard let time = recommendedTime else { return nil }
        // Convert "09:00" to "9:00 AM"
        let parts = time.split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]) else { return time }
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return "\(displayHour):\(parts[1]) \(period)"
    }
}

// MARK: - Place Info

struct PlaceInfo: Codable {
    let name: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let distanceMiles: Double?
    let rating: Double?
    let mapUrl: String?

    enum CodingKeys: String, CodingKey {
        case name
        case address
        case latitude
        case longitude
        case distanceMiles = "distance_miles"
        case rating
        case mapUrl = "map_url"
    }
}

// MARK: - Itinerary Response

struct ItineraryResponse: Codable {
    let startDate: String
    let endDate: String
    let message: String?
    let days: [DayPlan]

    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
        case message
        case days
    }
}

// MARK: - Day Plan

struct DayPlan: Codable, Identifiable {
    let date: String
    let dayType: String?
    let dayTypeLabel: String?
    let timeSlots: [ItineraryTimeSlot]?
    let meals: [MealSuggestion]?
    let summary: String?

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case date
        case dayType = "day_type"
        case dayTypeLabel = "day_type_label"
        case timeSlots = "time_slots"
        case meals
        case summary
    }

    var dateObject: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }

    var formattedDate: String {
        guard let dateObj = dateObject else { return date }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: dateObj)
    }
}

// MARK: - Itinerary Time Slot

struct ItineraryTimeSlot: Codable, Identifiable {
    let startTime: String
    let endTime: String?
    let activity: String
    let category: String?
    let location: PlaceInfo?

    var id: String { "\(startTime)-\(activity)" }

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case activity
        case category
        case location
    }

    var formattedTimeRange: String {
        let start = formatTime(startTime)
        if let end = endTime {
            return "\(start) - \(formatTime(end))"
        }
        return start
    }

    private func formatTime(_ time: String) -> String {
        let parts = time.split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]) else { return time }
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return "\(displayHour):\(parts[1]) \(period)"
    }

    var categoryColor: Color {
        switch category {
        case "activity": return DesignSystem.Colors.emerald
        case "lifestyle": return DesignSystem.Colors.violet
        case "social": return DesignSystem.Colors.amber
        default: return DesignSystem.Colors.blue
        }
    }

    var categoryIcon: String {
        switch category {
        case "activity": return "figure.run"
        case "lifestyle": return "book.fill"
        case "social": return "person.3.fill"
        default: return "star.fill"
        }
    }
}

// MARK: - Meal Suggestion

struct MealSuggestion: Codable, Identifiable {
    let mealType: String
    let suggestion: String?
    let time: String?
    let place: PlaceInfo?

    var id: String { mealType }

    enum CodingKeys: String, CodingKey {
        case mealType = "meal_type"
        case suggestion
        case time
        case place
    }

    var mealIcon: String {
        switch mealType.lowercased() {
        case "breakfast": return "sunrise.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.fill"
        default: return "fork.knife"
        }
    }
}

// MARK: - Itinerary Request

struct ItineraryRequest: Codable {
    let startDate: String
    let endDate: String?
    let preferences: ItineraryPreferences?

    // Note: Backend expects camelCase keys (startDate, endDate), not snake_case
}

struct ItineraryPreferences: Codable {
    var pace: String?
    var includeMeals: Bool?
    var budget: String?

    enum CodingKeys: String, CodingKey {
        case pace
        case includeMeals = "include_meals"
        case budget
    }
}

// MARK: - Day Type Info

struct DayTypeInfo: Codable {
    let date: String
    let dayType: String
    let dayTypeLabel: String
    let isWeekend: Bool
    let isHoliday: Bool
    let isRestDay: Bool
    let holidayName: String?

    enum CodingKeys: String, CodingKey {
        case date
        case dayType = "day_type"
        case dayTypeLabel = "day_type_label"
        case isWeekend = "is_weekend"
        case isHoliday = "is_holiday"
        case isRestDay = "is_rest_day"
        case holidayName = "holiday_name"
    }
}

// MARK: - Import SwiftUI for Color
import SwiftUI
