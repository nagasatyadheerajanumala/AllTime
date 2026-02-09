import Foundation
import SwiftUI

struct DiscoveredEvent: Codable, Identifiable {
    let id: Int64
    let title: String
    let description: String?
    let category: String?
    let suggestedStartTime: String
    let suggestedEndTime: String
    let locationName: String?
    let eventColor: String?
    let status: String
    let interestTag: String?
    let createdAt: String?
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, category, status
        case suggestedStartTime = "suggested_start_time"
        case suggestedEndTime = "suggested_end_time"
        case locationName = "location_name"
        case eventColor = "event_color"
        case interestTag = "interest_tag"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }

    // MARK: - Date parsing

    private static let localDateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        f.timeZone = TimeZone.current
        return f
    }()

    private static let localDateTimeWithSecondsFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.timeZone = TimeZone.current
        return f
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func parseDate(_ str: String) -> Date? {
        // Backend sends LocalDateTime strings like "2026-02-10T18:00" (no Z, no timezone)
        if let date = Self.localDateTimeFormatter.date(from: str) {
            return date
        }
        if let date = Self.localDateTimeWithSecondsFormatter.date(from: str) {
            return date
        }
        // Fallback: ISO 8601 with Z
        if let date = Self.iso8601Formatter.date(from: str) {
            return date
        }
        return nil
    }

    var startDate: Date? { parseDate(suggestedStartTime) }
    var endDate: Date? { parseDate(suggestedEndTime) }

    var displayColor: Color {
        Color(hex: eventColor ?? "#5EEAD4")
    }

    var categoryEmoji: String {
        guard let cat = (interestTag ?? category)?.lowercased() else { return "✨" }
        switch cat {
        case "hiking": return "🥾"
        case "gym", "fitness": return "💪"
        case "yoga": return "🧘"
        case "running": return "🏃"
        case "cycling": return "🚴"
        case "swimming": return "🏊"
        case "golf": return "⛳"
        case "tennis": return "🎾"
        case "basketball": return "🏀"
        case "soccer": return "⚽"
        case "skiing": return "🎿"
        case "reading": return "📚"
        case "cooking": return "👨‍🍳"
        case "gaming": return "🎮"
        case "photography": return "📷"
        case "gardening": return "🌱"
        case "music": return "🎵"
        case "art": return "🎨"
        case "movies", "movies_theater": return "🎬"
        case "podcasts": return "🎙️"
        case "dining_out": return "🍽️"
        case "concerts": return "🎶"
        case "sports_events": return "🏟️"
        case "volunteering": return "🤝"
        case "travel": return "✈️"
        case "museums": return "🏛️"
        case "shopping": return "🛍️"
        case "beach": return "🏖️"
        case "finance": return "💰"
        case "networking": return "🤝"
        default: return "✨"
        }
    }

    var formattedTime: String {
        guard let start = startDate else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none

        var str = formatter.string(from: start)
        if let end = endDate {
            str += " - " + formatter.string(from: end)
        }
        return str
    }

    var formattedDate: String {
        guard let start = startDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: start)
    }
}

struct DiscoveredEventsResponse: Codable {
    let events: [DiscoveredEvent]
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case events
        case totalCount = "total_count"
    }
}
