import Foundation
import SwiftUI

// Calendar Event from backend - matches new structured API response format
struct CalendarEvent: Codable, Identifiable {
    let id: Int64
    let title: String
    let description: String?
    let startTime: String  // ISO 8601 UTC: "2025-11-13T10:00:00Z"
    let endTime: String    // ISO 8601 UTC: "2025-11-13T11:00:00Z"
    let allDay: Bool
    let source: String
    let sourceColor: String?  // "#4285F4" for Google, "#FF6B35" for Microsoft, "#AF52DE" for EventKit
    let location: EventLocation?  // Now an object, not a string
    let attendees: [EventAttendee]?  // Array of attendee objects
    let recurrence: EventRecurrence?  // Recurrence information
    let metadata: [String: Any]?  // Additional metadata (can contain Any type values)
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, source, location, attendees, recurrence, metadata
        case startTime = "start_time"
        case endTime = "end_time"
        case allDay = "all_day"
        case sourceColor = "source_color"
    }
    
    // Custom decoder to handle metadata as [String: Any] and attendees as objects or strings
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int64.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        startTime = try container.decode(String.self, forKey: .startTime)
        endTime = try container.decode(String.self, forKey: .endTime)
        allDay = try container.decode(Bool.self, forKey: .allDay)
        source = try container.decode(String.self, forKey: .source)
        sourceColor = try container.decodeIfPresent(String.self, forKey: .sourceColor)
        location = try container.decodeIfPresent(EventLocation.self, forKey: .location)
        recurrence = try container.decodeIfPresent(EventRecurrence.self, forKey: .recurrence)
        
        // Handle metadata as [String: Any] using AnyCodable
        if let metadataDict = try? container.decode([String: AnyCodable].self, forKey: .metadata) {
            metadata = metadataDict.mapValues { $0.value }
        } else {
            metadata = nil
        }
        
        // Handle attendees: could be array of objects, array of strings, null, or missing
        if container.contains(.attendees) {
            // Check if the value is null first
            if try container.decodeNil(forKey: .attendees) {
                attendees = nil
            } else {
                // Try to decode as array of EventAttendee objects first
                if let attendeesArray = try? container.decode([EventAttendee].self, forKey: .attendees) {
                    attendees = attendeesArray.isEmpty ? nil : attendeesArray
                } else if let emailStrings = try? container.decode([String].self, forKey: .attendees) {
                    // If that fails, try as array of email strings
                    attendees = emailStrings.isEmpty ? nil : emailStrings.map { EventAttendee(email: $0, name: nil, responseStatus: nil) }
                } else {
                    // If both fail, try to decode as a single unkeyed container and handle mixed types
                    var attendeesArray: [EventAttendee] = []
                    if var unkeyedContainer = try? container.nestedUnkeyedContainer(forKey: .attendees) {
                        while !unkeyedContainer.isAtEnd {
                            // Try to decode as EventAttendee object
                            if let attendee = try? unkeyedContainer.decode(EventAttendee.self) {
                                attendeesArray.append(attendee)
                            } else if let emailString = try? unkeyedContainer.decode(String.self) {
                                // If that fails, try as string (email)
                                attendeesArray.append(EventAttendee(email: emailString, name: nil, responseStatus: nil))
                            } else {
                                // Skip invalid entries
                                _ = try? unkeyedContainer.decode(AnyCodable.self)
                            }
                        }
                    }
                    attendees = attendeesArray.isEmpty ? nil : attendeesArray
                }
            }
        } else {
            attendees = nil
        }
    }
    
    // Custom encoder to handle metadata as [String: Any]
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(allDay, forKey: .allDay)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(sourceColor, forKey: .sourceColor)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(attendees, forKey: .attendees)
        try container.encodeIfPresent(recurrence, forKey: .recurrence)
        
        // Handle metadata as [String: Any] using AnyCodable
        if let metadata = metadata {
            let codableMetadata = metadata.mapValues { AnyCodable($0) }
            try container.encode(codableMetadata, forKey: .metadata)
        } else {
            try container.encodeNil(forKey: .metadata)
        }
    }
    
    // Convenience initializer for previews and tests
    init(
        id: Int64,
        title: String,
        description: String? = nil,
        startTime: String,
        endTime: String,
        allDay: Bool,
        source: String,
        sourceColor: String? = nil,
        location: EventLocation? = nil,
        attendees: [EventAttendee]? = nil,
        recurrence: EventRecurrence? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.startTime = startTime
        self.endTime = endTime
        self.allDay = allDay
        self.source = source
        self.sourceColor = sourceColor
        self.location = location
        self.attendees = attendees
        self.recurrence = recurrence
        self.metadata = metadata
    }
    
    // Static formatters (reused, thread-safe, created once)
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private static let iso8601FormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private static let manualDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    // Optimized date parsing (no logging in hot path)
    var startDate: Date? {
        // Try standard ISO8601 format first (most common)
        if let date = Self.iso8601Formatter.date(from: startTime) {
            return applyTimezoneCorrection(date: date)
        }
        
        // Try with fractional seconds
        if let date = Self.iso8601FormatterWithFractional.date(from: startTime) {
            return applyTimezoneCorrection(date: date)
        }
        
        // Last resort: manual parsing
        if let date = Self.manualDateFormatter.date(from: startTime) {
            return applyTimezoneCorrection(date: date)
        }
        
        // Logging removed for performance - only parse errors in DEBUG
        #if DEBUG
        print("⚠️ Event: Failed to parse startDate for '\(title)'")
        #endif
        return nil
    }
    
    var endDate: Date? {
        // Try standard ISO8601 format first
        if let date = Self.iso8601Formatter.date(from: endTime) {
            return applyTimezoneCorrection(date: date)
        }
        
        // Try with fractional seconds
        if let date = Self.iso8601FormatterWithFractional.date(from: endTime) {
            return applyTimezoneCorrection(date: date)
        }
        
        // Last resort: manual parsing
        if let date = Self.manualDateFormatter.date(from: endTime) {
            return applyTimezoneCorrection(date: date)
        }
        
        return nil
    }
    
    var duration: TimeInterval? {
        guard let start = startDate, let end = endDate else { return nil }
        return end.timeIntervalSince(start)
    }
    
    // Timezone handling: Backend should send proper UTC times (ISO8601 with Z suffix)
    // The Date is parsed as UTC and displayed in user's local timezone by iOS automatically
    // No manual correction needed - iOS handles timezone conversion when displaying
    private func applyTimezoneCorrection(date: Date) -> Date {
        // DISABLED: Previous heuristic-based correction was causing incorrect time displays
        // Backend now sends correct UTC times, iOS handles conversion to local timezone
        // If times appear wrong, the issue is on the backend side
        return date
    }
}

// MARK: - Upcoming Events Response (GET /calendars/events/upcoming)
// This endpoint returns the same structure as GET /events
typealias UpcomingEventsResponse = EventsResponse

// Legacy simple response for backward compatibility
struct SimpleUpcomingEventsResponse: Codable {
    let events: [CalendarEvent]
    let count: Int
    let days: Int
}

// Legacy Event model (for compatibility)
typealias Event = CalendarEvent

// MARK: - Convenience Extensions for CalendarEvent

extension CalendarEvent {
    // Convenience property for location name (backward compatibility)
    var locationName: String? {
        location?.name
    }
    
    // Convenience property for location address
    var locationAddress: String? {
        location?.address
    }
    
    // Convenience property for source color (with defaults)
    // According to the guide, sourceColor should always be present, but we handle it being optional for safety
    var sourceColorValue: String {
        if let sourceColor = sourceColor, !sourceColor.isEmpty {
            return sourceColor
        }
        return defaultSourceColor
    }
    
    private var defaultSourceColor: String {
        switch source.lowercased() {
        case "google":
            return "#4285F4"
        case "microsoft":
            return "#FF6B35"
        case "eventkit", "apple":
            return "#AF52DE"
        default:
            return "#808080"
        }
    }
    
    // Convenience property for Color from sourceColor string
    var sourceColorAsColor: Color {
        Color(hex: sourceColorValue)
    }
}

// MARK: - Event Creation Models

struct CreateEventRequest: Codable {
    let title: String
    let description: String?
    let location: String?
    let startTime: String  // ISO 8601 UTC format: "2025-11-05T14:30:00Z"
    let endTime: String    // ISO 8601 UTC format: "2025-11-05T15:30:00Z"
    let allDay: Bool
    let provider: String?  // "google" or "microsoft" - which calendar to use. nil = local only
    let attendees: [String]?  // Array of email addresses for invites
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case location
        case startTime = "start_time"
        case endTime = "end_time"
        case allDay = "all_day"
        case provider
        case attendees
    }
}

struct CreateEventResponse: Codable {
    let id: Int64
    let title: String
    let description: String?
    let location: String?
    let startTime: String
    let endTime: String
    let allDay: Bool
    let source: String
    let userId: Int64
    let createdAt: String
    let syncStatus: SyncStatus
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case location
        case startTime = "start_time"
        case endTime = "end_time"
        case allDay = "all_day"
        case source
        case userId = "user_id"
        case createdAt = "created_at"
        case syncStatus = "sync_status"
    }
}

struct SyncStatus: Codable {
    let provider: String  // "google" or "microsoft"
    let synced: Bool
    let eventId: String?
    let attendeesCount: Int?
    let attendees: [String]?
    let meetingLink: String?  // Google Meet or Teams link (automatically added when attendees provided)
    let meetingType: String?  // "google_meet" or "microsoft_teams"
    
    enum CodingKeys: String, CodingKey {
        case provider
        case synced
        case eventId = "event_id"
        case attendeesCount = "attendees_count"
        case attendees
        case meetingLink = "meeting_link"
        case meetingType = "meeting_type"
    }
}

// MARK: - Event Details Models (GET /calendars/events/{eventId})

struct EventDetails: Codable, Identifiable {
    let id: Int64
    let title: String?
    let description: String?
    let location: String?
    let startTime: String  // ISO 8601 UTC format: "2025-11-05T20:00:00Z"
    let endTime: String
    let allDay: Bool
    let source: String
    let sourceEventId: String
    let attendees: [Attendee]?
    let isCancelled: Bool
    let createdAt: String
    let userId: Int64
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case location
        case startTime = "start_time"
        case endTime = "end_time"
        case allDay = "all_day"
        case source
        case sourceEventId = "source_event_id"
        case attendees
        case isCancelled = "is_cancelled"
        case createdAt = "created_at"
        case userId = "user_id"
    }
    
    // Custom decoder to handle attendees as either objects or strings
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int64.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        startTime = try container.decode(String.self, forKey: .startTime)
        endTime = try container.decode(String.self, forKey: .endTime)
        allDay = try container.decode(Bool.self, forKey: .allDay)
        source = try container.decode(String.self, forKey: .source)
        sourceEventId = try container.decode(String.self, forKey: .sourceEventId)
        isCancelled = try container.decode(Bool.self, forKey: .isCancelled)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        userId = try container.decode(Int64.self, forKey: .userId)
        
        // Handle attendees: could be array of objects, array of strings, null, or missing
        if container.contains(.attendees) {
            // Check if the value is null first
            if try container.decodeNil(forKey: .attendees) {
                attendees = nil
            } else {
                // Try to decode as array of Attendee objects first
                if let attendeesArray = try? container.decode([Attendee].self, forKey: .attendees) {
                    attendees = attendeesArray.isEmpty ? nil : attendeesArray
                } else if let emailStrings = try? container.decode([String].self, forKey: .attendees) {
                    // If that fails, try as array of email strings
                    attendees = emailStrings.isEmpty ? nil : emailStrings.map { Attendee(email: $0, displayName: nil, responseStatus: nil) }
                } else {
                    // If both fail, try to decode as a single unkeyed container and handle mixed types
                    var attendeesArray: [Attendee] = []
                    if var unkeyedContainer = try? container.nestedUnkeyedContainer(forKey: .attendees) {
                        while !unkeyedContainer.isAtEnd {
                            // Try to decode as Attendee object
                            if let attendee = try? unkeyedContainer.decode(Attendee.self) {
                                attendeesArray.append(attendee)
                            } else if let emailString = try? unkeyedContainer.decode(String.self) {
                                // If that fails, try as string (email)
                                attendeesArray.append(Attendee(email: emailString, displayName: nil, responseStatus: nil))
                            } else {
                                // Skip invalid entries
                                _ = try? unkeyedContainer.decode(AnyCodable.self)
                            }
                        }
                    }
                    attendees = attendeesArray.isEmpty ? nil : attendeesArray
                }
            }
        } else {
            attendees = nil
        }
    }
    
    // Computed properties for formatted dates
    var startDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        
        if let date = formatter.date(from: startTime) {
            return date
        }
        
        // Fallback: try without fractional seconds
        let simpleFormatter = ISO8601DateFormatter()
        simpleFormatter.formatOptions = [.withInternetDateTime]
        simpleFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return simpleFormatter.date(from: startTime)
    }
    
    var endDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        
        if let date = formatter.date(from: endTime) {
            return date
        }
        
        // Fallback: try without fractional seconds
        let simpleFormatter = ISO8601DateFormatter()
        simpleFormatter.formatOptions = [.withInternetDateTime]
        simpleFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return simpleFormatter.date(from: endTime)
    }
    
    var formattedStartTime: String {
        guard let date = startDate else { return startTime }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
    
    var formattedEndTime: String {
        guard let date = endDate else { return endTime }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
    
    var duration: String {
        guard let start = startDate, let end = endDate else { return "" }
        
        if allDay {
            let calendar = Calendar.current
            let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
            return days == 1 ? "All Day" : "\(days) days"
        }
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: start, to: end) ?? ""
    }
}

struct Attendee: Codable, Identifiable {
    let email: String?
    let displayName: String?
    let responseStatus: String?
    
    // Use email as ID if available, otherwise use a hash
    var id: String {
        email ?? displayName ?? UUID().uuidString
    }
    
    // Public initializer for creating Attendee instances manually
    init(email: String?, displayName: String?, responseStatus: String?) {
        self.email = email
        self.displayName = displayName
        self.responseStatus = responseStatus
    }
    
    // Backend may send either camelCase (displayName, responseStatus) or snake_case (display_name, response_status)
    // Also may use "name" instead of "displayName"
    // Custom decoder to handle all formats
    enum CodingKeys: String, CodingKey {
        case email
        case displayName
        case display_name  // snake_case variant
        case name  // Alternative field name
        case responseStatus
        case response_status  // snake_case variant
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Email is always the same
        email = try container.decodeIfPresent(String.self, forKey: .email)
        
        // Handle both camelCase and snake_case for displayName
        // Also check for "name" field (backend might use this instead of displayName)
        // Try in order of preference: displayName -> display_name -> name
        if let name = try container.decodeIfPresent(String.self, forKey: .displayName), !name.isEmpty {
            displayName = name
        } else if let name = try container.decodeIfPresent(String.self, forKey: .display_name), !name.isEmpty {
            displayName = name
        } else if let name = try container.decodeIfPresent(String.self, forKey: .name), !name.isEmpty {
            displayName = name
        } else {
            displayName = nil
        }
        
        // Handle both camelCase and snake_case for responseStatus
        if let status = try container.decodeIfPresent(String.self, forKey: .responseStatus), !status.isEmpty {
            responseStatus = status
        } else if let status = try container.decodeIfPresent(String.self, forKey: .response_status), !status.isEmpty {
            responseStatus = status
        } else {
            responseStatus = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(responseStatus, forKey: .responseStatus)
    }
}

