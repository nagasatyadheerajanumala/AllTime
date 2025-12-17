import Foundation

// MARK: - Predictions Response

struct PredictionsResponse: Codable {
    let date: String
    let generatedAt: String
    let travelPredictions: [TravelPrediction]
    let capacity: CapacityPrediction?
    let patterns: [EventPattern]
    let upcomingEventsWithTravel: Int
    let hasWarnings: Bool
    let warningCount: Int

    enum CodingKeys: String, CodingKey {
        case date
        case generatedAt = "generated_at"
        case travelPredictions = "travel_predictions"
        case capacity
        case patterns
        case upcomingEventsWithTravel = "upcoming_events_with_travel"
        case hasWarnings = "has_warnings"
        case warningCount = "warning_count"
    }
}

// MARK: - Travel Prediction

struct TravelPrediction: Codable, Identifiable {
    let eventId: Int64
    let eventTitle: String?
    let eventLocation: String?
    let eventStartTime: String?
    let leaveBy: String?
    let travelMinutes: Int
    let bufferMinutes: Int
    let trafficLevel: String?
    let transportMode: String?
    let distanceKm: Double?
    let confidence: Double

    var id: Int64 { eventId }

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case eventTitle = "event_title"
        case eventLocation = "event_location"
        case eventStartTime = "event_start_time"
        case leaveBy = "leave_by"
        case travelMinutes = "travel_minutes"
        case bufferMinutes = "buffer_minutes"
        case trafficLevel = "traffic_level"
        case transportMode = "transport_mode"
        case distanceKm = "distance_km"
        case confidence
    }

    // Computed properties for display
    var eventStartDate: Date? {
        guard let dateString = eventStartTime else { return nil }
        return PredictionDateFormatter.parse(dateString)
    }

    var leaveByDate: Date? {
        guard let dateString = leaveBy else { return nil }
        return PredictionDateFormatter.parse(dateString)
    }

    var formattedLeaveBy: String {
        guard let date = leaveByDate else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    var formattedEventTime: String {
        guard let date = eventStartDate else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    var trafficIcon: String {
        switch trafficLevel {
        case "light": return "car.fill"
        case "moderate": return "car.fill"
        case "heavy": return "car.fill"
        default: return "car.fill"
        }
    }

    var trafficColor: String {
        switch trafficLevel {
        case "light": return "10B981" // Green
        case "moderate": return "F59E0B" // Orange
        case "heavy": return "EF4444" // Red
        default: return "6B7280" // Gray
        }
    }
}

// MARK: - Capacity Prediction

struct CapacityPrediction: Codable {
    let date: String
    let totalMeetingMinutes: Int
    let meetingCount: Int
    let backToBackCount: Int
    let longestMeetingStreakMinutes: Int
    let capacityPercentage: Double
    let capacityLevel: String
    let warnings: [CapacityWarning]
    let recommendations: [String]
    let freeBlocksCount: Int
    let largestFreeBlockMinutes: Int

    enum CodingKeys: String, CodingKey {
        case date
        case totalMeetingMinutes = "total_meeting_minutes"
        case meetingCount = "meeting_count"
        case backToBackCount = "back_to_back_count"
        case longestMeetingStreakMinutes = "longest_meeting_streak_minutes"
        case capacityPercentage = "capacity_percentage"
        case capacityLevel = "capacity_level"
        case warnings
        case recommendations
        case freeBlocksCount = "free_blocks_count"
        case largestFreeBlockMinutes = "largest_free_block_minutes"
    }

    // Computed properties for display
    var formattedDuration: String {
        let hours = totalMeetingMinutes / 60
        let minutes = totalMeetingMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    var capacityIcon: String {
        switch capacityLevel {
        case "light": return "gauge.with.dots.needle.0percent"
        case "moderate": return "gauge.with.dots.needle.33percent"
        case "busy": return "gauge.with.dots.needle.67percent"
        case "overloaded": return "gauge.with.dots.needle.100percent"
        default: return "gauge.with.dots.needle.50percent"
        }
    }

    var capacityColor: String {
        switch capacityLevel {
        case "light": return "10B981" // Green
        case "moderate": return "3B82F6" // Blue
        case "busy": return "F59E0B" // Orange
        case "overloaded": return "EF4444" // Red
        default: return "6B7280" // Gray
        }
    }

    var capacityDisplayText: String {
        switch capacityLevel {
        case "light": return "Light"
        case "moderate": return "Moderate"
        case "busy": return "Busy"
        case "overloaded": return "Overloaded"
        default: return "Unknown"
        }
    }
}

// MARK: - Capacity Warning

struct CapacityWarning: Codable, Identifiable {
    let type: String
    let severity: String
    let message: String

    var id: String { type + message }

    var severityIcon: String {
        switch severity {
        case "critical": return "exclamationmark.triangle.fill"
        case "warning": return "exclamationmark.circle.fill"
        case "info": return "info.circle.fill"
        default: return "info.circle"
        }
    }

    var severityColor: String {
        switch severity {
        case "critical": return "EF4444" // Red
        case "warning": return "F59E0B" // Orange
        case "info": return "3B82F6" // Blue
        default: return "6B7280" // Gray
        }
    }
}

// MARK: - Event Pattern

struct EventPattern: Codable, Identifiable {
    let patternId: String
    let title: String
    let patternType: String
    let daysOfWeek: [String]
    let typicalTime: String?
    let typicalDurationMinutes: Int
    let occurrenceCount: Int
    let confidence: Double
    let lastOccurrence: String?
    let suggestedNext: String?
    let location: String?
    let isActive: Bool

    var id: String { patternId }

    enum CodingKeys: String, CodingKey {
        case patternId = "pattern_id"
        case title
        case patternType = "pattern_type"
        case daysOfWeek = "days_of_week"
        case typicalTime = "typical_time"
        case typicalDurationMinutes = "typical_duration_minutes"
        case occurrenceCount = "occurrence_count"
        case confidence
        case lastOccurrence = "last_occurrence"
        case suggestedNext = "suggested_next"
        case location
        case isActive = "is_active"
    }

    var formattedDaysOfWeek: String {
        if daysOfWeek.count == 7 {
            return "Every day"
        } else if daysOfWeek.count == 5 && !daysOfWeek.contains("SATURDAY") && !daysOfWeek.contains("SUNDAY") {
            return "Weekdays"
        } else {
            return daysOfWeek.map { day in
                String(day.prefix(3).capitalized)
            }.joined(separator: ", ")
        }
    }

    var confidenceText: String {
        if confidence >= 0.8 {
            return "High confidence"
        } else if confidence >= 0.5 {
            return "Medium confidence"
        } else {
            return "Low confidence"
        }
    }
}

// MARK: - Week Capacity Response

struct WeekCapacityResponse: Codable {
    let startDate: String
    let endDate: String
    let capacityByDay: [CapacityPrediction]

    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
        case capacityByDay = "capacity_by_day"
    }
}

// MARK: - Patterns Response

struct PatternsResponse: Codable {
    let patterns: [EventPattern]
    let count: Int
}

// MARK: - Travel Predictions Response

struct TravelPredictionsResponse: Codable {
    let date: String
    let travelPredictions: [TravelPrediction]
    let count: Int

    enum CodingKeys: String, CodingKey {
        case date
        case travelPredictions = "travel_predictions"
        case count
    }
}

// MARK: - Date Formatter Helper

struct PredictionDateFormatter {
    static func parse(_ dateString: String) -> Date? {
        // Try multiple formats
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        // Try ISO8601 as fallback
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601.date(from: dateString) {
            return date
        }
        iso8601.formatOptions = [.withInternetDateTime]
        return iso8601.date(from: dateString)
    }
}
