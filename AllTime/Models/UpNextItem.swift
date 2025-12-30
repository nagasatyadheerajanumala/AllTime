import Foundation
import SwiftUI

// MARK: - Intelligent Up Next Item

/// Represents an intelligent "Up Next" suggestion based on calendar gaps and context.
/// These are NOT stored tasks - they are context-aware suggestions generated from:
/// - Calendar gaps (free time slots)
/// - Time of day (lunch window = lunch, evening = gym)
/// - Health patterns (workout timing based on user history)
struct UpNextItem: Codable, Identifiable {
    let id: String
    let type: UpNextItemType
    let title: String
    let description: String?
    let icon: String?
    let color: String?
    let startTime: Date?
    let endTime: Date?
    let durationMinutes: Int?
    let timeLabel: String?
    let isSuggestion: Bool?
    let confidence: String?
    let reason: String?
    let primaryAction: String?
    let primaryActionLabel: String?
    let metadata: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case id, type, title, description, icon, color
        case startTime = "start_time"
        case endTime = "end_time"
        case durationMinutes = "duration_minutes"
        case timeLabel = "time_label"
        case isSuggestion = "is_suggestion"
        case confidence, reason
        case primaryAction = "primary_action"
        case primaryActionLabel = "primary_action_label"
        case metadata
    }
}

// MARK: - Equatable (manual implementation since AnyCodable doesn't conform)

extension UpNextItem: Equatable {
    static func == (lhs: UpNextItem, rhs: UpNextItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.type == rhs.type &&
        lhs.title == rhs.title &&
        lhs.startTime == rhs.startTime &&
        lhs.endTime == rhs.endTime
    }
}

// MARK: - Computed Properties

extension UpNextItem {
    var displayTimeLabel: String {
        if let label = timeLabel {
            return label
        }
        if let start = startTime {
            return start.formatted(date: .omitted, time: .shortened)
        }
        return ""
    }

    var displayColor: Color {
        guard let colorHex = color else { return .blue }
        // Use existing Color(hex:) from DesignSystem.swift
        return Color(hex: colorHex.replacingOccurrences(of: "#", with: ""))
    }

    var displayIcon: String {
        icon ?? type.defaultIcon
    }

    var displayDuration: String {
        guard let duration = durationMinutes else { return "" }
        if duration >= 60 {
            let hours = duration / 60
            let mins = duration % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(duration)m"
    }

    var confidenceLevel: ConfidenceLevel {
        switch confidence?.lowercased() {
        case "high": return .high
        case "medium": return .medium
        case "low": return .low
        default: return .medium
        }
    }
}

// MARK: - Up Next Item Type

enum UpNextItemType: String, Codable, CaseIterable {
    case lunch = "LUNCH"
    case meetingLunch = "MEETING_LUNCH"
    case gym = "GYM"
    case walk = "WALK"
    case focusWork = "FOCUS_WORK"
    case `break` = "BREAK"
    case task = "TASK"
    case recreation = "RECREATION"

    var displayName: String {
        switch self {
        case .lunch: return "Lunch"
        case .meetingLunch: return "Lunch Near Meeting"
        case .gym: return "Workout"
        case .walk: return "Walk"
        case .focusWork: return "Focus Time"
        case .break: return "Break"
        case .task: return "Task"
        case .recreation: return "Free Time"
        }
    }

    var defaultIcon: String {
        switch self {
        case .lunch: return "fork.knife"
        case .meetingLunch: return "mappin.and.ellipse"
        case .gym: return "figure.run"
        case .walk: return "figure.walk"
        case .focusWork: return "brain.head.profile"
        case .break: return "pause.circle.fill"
        case .task: return "checkmark.circle"
        case .recreation: return "clock"
        }
    }

    var defaultColor: Color {
        switch self {
        case .lunch: return .orange
        case .meetingLunch: return .orange
        case .gym: return .green
        case .walk: return .green
        case .focusWork: return .purple
        case .break: return .blue
        case .task: return .secondary
        case .recreation: return .blue
        }
    }
}

// MARK: - Confidence Level

enum ConfidenceLevel: String, CaseIterable {
    case high
    case medium
    case low

    var color: Color {
        switch self {
        case .high: return .green
        case .medium: return .orange
        case .low: return .secondary
        }
    }
}

// MARK: - Up Next Response

struct UpNextItemsResponse: Codable {
    let items: [UpNextItem]
    let totalFreeMinutes: Int?
    let meetingCount: Int?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case items
        case totalFreeMinutes = "totalFreeMinutes"
        case meetingCount = "meetingCount"
        case message
    }
}

// MARK: - Meeting Spot Recommendations

/// Response from GET /api/v1/recommendations/near-meeting
struct MeetingSpotRecommendations: Codable {
    let hasMeetingWithLocation: Bool
    let meetingTitle: String?
    let meetingTime: String?
    let meetingStart: Date?
    let meetingLocation: String?
    let meetingLat: Double?
    let meetingLng: Double?
    let contextMessage: String?
    let suggestionType: String?
    let spots: [NearbySpot]?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case hasMeetingWithLocation = "has_meeting_with_location"
        case meetingTitle = "meeting_title"
        case meetingTime = "meeting_time"
        case meetingStart = "meeting_start"
        case meetingLocation = "meeting_location"
        case meetingLat = "meeting_lat"
        case meetingLng = "meeting_lng"
        case contextMessage = "context_message"
        case suggestionType = "suggestion_type"
        case spots, message
    }
}

/// Individual spot from Google Places
struct NearbySpot: Codable, Identifiable {
    let placeId: String
    let name: String
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let distanceKm: Double?
    let walkingMinutes: Int?
    let rating: Double?
    let userRatingsTotal: Int?
    let priceLevel: Int?
    let priceLevelDisplay: String?
    let openNow: Bool?
    let photoUrl: String?
    let primaryType: String?

    var id: String { placeId }

    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case name, address, latitude, longitude
        case distanceKm = "distance_km"
        case walkingMinutes = "walking_minutes"
        case rating
        case userRatingsTotal = "user_ratings_total"
        case priceLevel = "price_level"
        case priceLevelDisplay = "price_level_display"
        case openNow = "open_now"
        case photoUrl = "photo_url"
        case primaryType = "primary_type"
    }

    var displayDistance: String {
        if let km = distanceKm {
            let miles = km * 0.621371
            return String(format: "%.1f mi", miles)
        }
        return ""
    }

    var displayWalkingTime: String {
        guard let mins = walkingMinutes else { return "" }
        return "\(mins) min walk"
    }

    var displayRating: String {
        guard let r = rating else { return "" }
        return String(format: "%.1f", r)
    }
}
