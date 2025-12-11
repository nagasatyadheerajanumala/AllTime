import Foundation

// MARK: - Block Time Request
struct BlockTimeRequest: Encodable {
    let startTime: String
    let endTime: String
    let title: String?
    let description: String?
    let calendarProvider: String?
    let enableFocusMode: Bool?
    let timezone: String?

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case title, description, timezone
        case calendarProvider = "calendar_provider"
        case enableFocusMode = "enable_focus_mode"
    }

    init(
        start: Date,
        end: Date,
        title: String? = "Focus Time",
        description: String? = nil,
        calendarProvider: String? = "all",
        enableFocusMode: Bool? = true
    ) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        self.startTime = formatter.string(from: start)
        self.endTime = formatter.string(from: end)
        self.title = title
        self.description = description
        self.calendarProvider = calendarProvider
        self.enableFocusMode = enableFocusMode
        self.timezone = TimeZone.current.identifier
    }
}

// MARK: - Block Time Response
struct BlockTimeResponse: Codable {
    let success: Bool
    let message: String?
    let eventId: String?
    let calendarEvents: [CalendarEventResult]?
    let focusMode: FocusModeResult?
    let startTime: String?
    let endTime: String?
    let durationMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case success, message
        case eventId = "event_id"
        case calendarEvents = "calendar_events"
        case focusMode = "focus_mode"
        case startTime = "start_time"
        case endTime = "end_time"
        case durationMinutes = "duration_minutes"
    }
}

struct CalendarEventResult: Codable {
    let provider: String
    let success: Bool
    let eventId: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case provider, success, error
        case eventId = "event_id"
    }
}

struct FocusModeResult: Codable {
    let requested: Bool
    let supported: Bool
    let action: String?
    let shortcutUrl: String?
    let instructions: String?

    enum CodingKeys: String, CodingKey {
        case requested, supported, action, instructions
        case shortcutUrl = "shortcut_url"
    }
}

// MARK: - Connected Calendars Response
struct ConnectedCalendarsResponse: Codable {
    let calendars: [CalendarConnection]
}

struct CalendarConnection: Codable, Identifiable {
    var id: String { provider }

    let provider: String
    let connected: Bool
    let email: String?

    var providerName: String {
        switch provider {
        case "google": return "Google Calendar"
        case "microsoft": return "Microsoft Outlook"
        default: return provider.capitalized
        }
    }

    var providerIcon: String {
        switch provider {
        case "google": return "g.circle.fill"
        case "microsoft": return "m.circle.fill"
        default: return "calendar"
        }
    }
}
