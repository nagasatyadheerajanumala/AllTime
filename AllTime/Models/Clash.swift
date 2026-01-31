import Foundation
import SwiftUI

/// Response from the clashes API
struct ClashResponse: Codable {
    let clashesByDate: [String: [ClashInfo]]
    let totalClashes: Int?

    enum CodingKeys: String, CodingKey {
        case clashesByDate = "clashes_by_date"
        case totalClashes = "total_clashes"
    }

    /// Computed total if not provided by API
    var effectiveTotalClashes: Int {
        if let total = totalClashes {
            return total
        }
        return clashesByDate.values.reduce(0) { $0 + $1.count }
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

/// Resolution option for a meeting clash - actionable choice
struct ResolutionOption: Codable, Identifiable {
    /// Type: decline_a, decline_b, reschedule_a, reschedule_b, shorten, keep_both
    let type: String

    /// Human-readable label: "Decline Team Sync"
    let label: String

    /// Why this option: "Lower priority, can be async"
    let reason: String?

    /// Which event this action targets
    let targetEventId: Int64?

    /// Is this the recommended option?
    let recommended: Bool?

    var id: String { type }

    enum CodingKeys: String, CodingKey {
        case type, label, reason
        case targetEventId = "target_event_id"
        case recommended
    }

    /// Icon for this resolution type
    var icon: String {
        switch type {
        case "decline_a", "decline_b":
            return "xmark.circle"
        case "reschedule_a", "reschedule_b":
            return "calendar.badge.clock"
        case "keep_both":
            return "person.2"
        case "shorten":
            return "arrow.left.and.right"
        default:
            return "questionmark.circle"
        }
    }

    /// Whether this is a decline action
    var isDecline: Bool {
        type.hasPrefix("decline")
    }

    /// Whether this is a reschedule action
    var isReschedule: Bool {
        type.hasPrefix("reschedule")
    }
}

/// Information about a single clash between two events
struct ClashInfo: Codable, Identifiable {
    let eventA: ClashEventInfo
    let eventB: ClashEventInfo
    let overlapMinutes: Int
    let severity: String

    // === Actionable Intelligence Fields ===

    /// 1-10 score: higher = needs attention first
    let importanceScore: Int?

    /// Why this clash matters: "External commitment conflicts with internal meeting"
    let impactContext: String?

    /// What to do: "Decline Team Sync — it's lower stakes"
    let suggestedAction: String?

    /// Which event Clara recommends keeping (event_a or event_b ID)
    let recommendedKeep: Int64?

    /// Specific resolution options the user can take
    let resolutionOptions: [ResolutionOption]?

    /// Unique ID for SwiftUI lists
    var id: String {
        "\(eventA.id)-\(eventB.id)"
    }

    enum CodingKeys: String, CodingKey {
        case eventA = "event_a"
        case eventB = "event_b"
        case overlapMinutes = "overlap_minutes"
        case severity
        case importanceScore = "importance_score"
        case impactContext = "impact_context"
        case suggestedAction = "suggested_action"
        case recommendedKeep = "recommended_keep"
        case resolutionOptions = "resolution_options"
    }

    /// The event Clara recommends keeping
    var recommendedEvent: ClashEventInfo? {
        guard let keepId = recommendedKeep else { return nil }
        if eventA.id == keepId { return eventA }
        if eventB.id == keepId { return eventB }
        return nil
    }

    /// The event Clara recommends declining/rescheduling
    var otherEvent: ClashEventInfo? {
        guard let keepId = recommendedKeep else { return nil }
        if eventA.id == keepId { return eventB }
        if eventB.id == keepId { return eventA }
        return nil
    }

    /// Get the recommended resolution option
    var recommendedResolution: ResolutionOption? {
        resolutionOptions?.first { $0.recommended == true }
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

/// Response from resolving a clash
struct ClashResolutionResponse: Codable {
    let success: Bool
    let message: String?
    let action: String?
    let eventId: Int64?
    let eventTitle: String?
    let error: String?
    let hint: String?

    enum CodingKeys: String, CodingKey {
        case success, message, action, error, hint
        case eventId = "event_id"
        case eventTitle = "event_title"
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
