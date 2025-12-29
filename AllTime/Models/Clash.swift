import Foundation
import SwiftUI

/// Response from the clashes API
struct ClashResponse: Codable {
    let clashesByDate: [String: [ClashInfo]]
    let totalClashes: Int

    enum CodingKeys: String, CodingKey {
        case clashesByDate = "clashes_by_date"
        case totalClashes = "total_clashes"
    }
}

/// Information about a single clash between two events
struct ClashInfo: Codable, Identifiable {
    let eventA: ClashEventInfo
    let eventB: ClashEventInfo
    let overlapMinutes: Int
    let severity: String

    /// Unique ID for SwiftUI lists
    var id: String {
        "\(eventA.id)-\(eventB.id)"
    }

    enum CodingKeys: String, CodingKey {
        case eventA = "event_a"
        case eventB = "event_b"
        case overlapMinutes = "overlap_minutes"
        case severity
    }

    /// Formatted overlap duration string
    var overlapText: String {
        if overlapMinutes >= 60 {
            let hours = overlapMinutes / 60
            let mins = overlapMinutes % 60
            if mins == 0 {
                return "\(hours)h overlap"
            }
            return "\(hours)h \(mins)m overlap"
        }
        return "\(overlapMinutes)m overlap"
    }

    /// Severity color hex string
    var severityColorHex: String {
        switch severity.lowercased() {
        case "critical", "red":
            return "#EF4444" // Red
        case "high", "orange":
            return "#F97316" // Orange
        case "medium", "yellow":
            return "#EAB308" // Yellow
        default:
            return "#3B82F6" // Blue
        }
    }

    /// Severity color as SwiftUI Color
    var severityColor: Color {
        Color(hex: severityColorHex)
    }

    /// Severity icon
    var severityIcon: String {
        switch severity.lowercased() {
        case "critical", "red":
            return "exclamationmark.triangle.fill"
        case "high", "orange":
            return "exclamationmark.circle.fill"
        default:
            return "info.circle.fill"
        }
    }
}

/// Event information within a clash
struct ClashEventInfo: Codable, Identifiable {
    let id: Int64
    let title: String
    let source: String
    let startTime: String
    let endTime: String

    enum CodingKeys: String, CodingKey {
        case id, title, source
        case startTime = "start_time"
        case endTime = "end_time"
    }

    /// Parsed start date
    var startDate: Date? {
        parseDate(startTime)
    }

    /// Parsed end date
    var endDate: Date? {
        parseDate(endTime)
    }

    /// Formatted time range string
    var formattedTimeRange: String {
        guard let start = startDate, let end = endDate else {
            return startTime
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString)
    }
}

/// Model for displaying clashes grouped by date
struct ClashDay: Identifiable {
    let date: String
    let clashes: [ClashInfo]

    var id: String { date }

    /// Formatted display date
    var displayDate: String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = inputFormatter.date(from: date) else {
            return self.date
        }

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "EEEE, MMM d"
        return outputFormatter.string(from: date)
    }

    /// Whether this is today
    var isToday: Bool {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        guard let parsedDate = inputFormatter.date(from: date) else {
            return false
        }
        return Calendar.current.isDateInToday(parsedDate)
    }

    /// Whether this is tomorrow
    var isTomorrow: Bool {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        guard let parsedDate = inputFormatter.date(from: date) else {
            return false
        }
        return Calendar.current.isDateInTomorrow(parsedDate)
    }
}
