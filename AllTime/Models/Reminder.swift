import Foundation

// MARK: - Reminder Model

struct Reminder: Codable, Identifiable, Equatable {
    let id: Int64
    let userId: Int64
    let title: String
    let description: String?
    let dueDate: Date
    let reminderTime: Date?
    let isCompleted: Bool
    let priority: ReminderPriority?
    let status: ReminderStatus
    let eventId: Int64?
    let recurrenceRule: String?
    let snoozeUntil: Date?
    let notificationEnabled: Bool
    let notificationSound: String?
    let createdAt: Date
    let updatedAt: Date
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case description
        case dueDate = "due_date"
        case reminderTime = "reminder_time"
        case isCompleted = "is_completed"
        case priority
        case status
        case eventId = "event_id"
        case recurrenceRule = "recurrence_rule"
        case snoozeUntil = "snooze_until"
        case notificationEnabled = "notification_enabled"
        case notificationSound = "notification_sound"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case completedAt = "completed_at"
    }

    // Custom decoder to handle backend's LocalDateTime format (yyyy-MM-dd'T'HH:mm:ss without timezone)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int64.self, forKey: .id)
        userId = try container.decode(Int64.self, forKey: .userId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        priority = try container.decodeIfPresent(ReminderPriority.self, forKey: .priority)
        status = try container.decodeIfPresent(ReminderStatus.self, forKey: .status) ?? .pending
        eventId = try container.decodeIfPresent(Int64.self, forKey: .eventId)
        recurrenceRule = try container.decodeIfPresent(String.self, forKey: .recurrenceRule)
        notificationEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationEnabled) ?? true
        notificationSound = try container.decodeIfPresent(String.self, forKey: .notificationSound)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false

        // Helper function to parse date from string in multiple formats
        func parseDate(from string: String?) -> Date? {
            guard let string = string, !string.isEmpty else { return nil }

            // Try formats in order of likelihood
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
                    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                    f.locale = Locale(identifier: "en_US_POSIX")
                    return f
                }()
            ]

            for formatter in formatters {
                if let date = formatter.date(from: string) {
                    return date
                }
            }

            // Try ISO8601 as fallback
            let iso8601 = ISO8601DateFormatter()
            iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601.date(from: string) {
                return date
            }
            iso8601.formatOptions = [.withInternetDateTime]
            return iso8601.date(from: string)
        }

        // Parse required date fields
        if let dueDateString = try container.decodeIfPresent(String.self, forKey: .dueDate),
           let parsedDate = parseDate(from: dueDateString) {
            dueDate = parsedDate
        } else {
            dueDate = Date() // Fallback to now if missing
        }

        // Parse optional date fields
        let reminderTimeString = try container.decodeIfPresent(String.self, forKey: .reminderTime)
        reminderTime = parseDate(from: reminderTimeString)

        let snoozeUntilString = try container.decodeIfPresent(String.self, forKey: .snoozeUntil)
        snoozeUntil = parseDate(from: snoozeUntilString)

        let completedAtString = try container.decodeIfPresent(String.self, forKey: .completedAt)
        completedAt = parseDate(from: completedAtString)

        // Parse createdAt and updatedAt with fallback
        if let createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAt),
           let parsedDate = parseDate(from: createdAtString) {
            createdAt = parsedDate
        } else {
            createdAt = Date()
        }

        if let updatedAtString = try container.decodeIfPresent(String.self, forKey: .updatedAt),
           let parsedDate = parseDate(from: updatedAtString) {
            updatedAt = parsedDate
        } else {
            updatedAt = Date()
        }
    }

    // Manual initializer for creating Reminder instances programmatically
    init(id: Int64, userId: Int64, title: String, description: String? = nil, dueDate: Date,
         reminderTime: Date? = nil, isCompleted: Bool = false, priority: ReminderPriority? = nil,
         status: ReminderStatus = .pending, eventId: Int64? = nil, recurrenceRule: String? = nil,
         snoozeUntil: Date? = nil, notificationEnabled: Bool = true, notificationSound: String? = nil,
         createdAt: Date = Date(), updatedAt: Date = Date(), completedAt: Date? = nil) {
        self.id = id
        self.userId = userId
        self.title = title
        self.description = description
        self.dueDate = dueDate
        self.reminderTime = reminderTime
        self.isCompleted = isCompleted
        self.priority = priority
        self.status = status
        self.eventId = eventId
        self.recurrenceRule = recurrenceRule
        self.snoozeUntil = snoozeUntil
        self.notificationEnabled = notificationEnabled
        self.notificationSound = notificationSound
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }
}

// MARK: - Reminder Priority

enum ReminderPriority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"

    var displayName: String {
        switch self {
        case .low: return "Flexible"
        case .medium: return "Regular"
        case .high: return "Important"
        case .urgent: return "Time-sensitive"
        }
    }

    /// Softer colors for a calmer experience
    var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "blue"
        case .high: return "indigo"
        case .urgent: return "orange"
        }
    }
}

// MARK: - Reminder Status

enum ReminderStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case completed = "completed"
    case snoozed = "snoozed"
    case cancelled = "cancelled"

    var displayName: String {
        switch self {
        case .pending: return "Open"
        case .completed: return "Done"
        case .snoozed: return "Later"
        case .cancelled: return "Skipped"
        }
    }
}

// MARK: - Notification Sound

enum NotificationSound: String, Codable, CaseIterable {
    case `default` = "default"
    case alert = "alert"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .default: return "Default"
        case .alert: return "Alert"
        case .none: return "None"
        }
    }
}

// MARK: - Reminder Request (For Create/Update)

struct ReminderRequest: Codable {
    let title: String?
    let description: String?
    let dueDate: Date?
    let reminderTime: Date?
    let reminderMinutesBefore: Int?
    let priority: ReminderPriority?
    let eventId: Int64?
    let recurrenceRule: String?
    let notificationEnabled: Bool?
    let notificationSound: String?
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case dueDate = "due_date"
        case reminderTime = "reminder_time"
        case reminderMinutesBefore = "reminder_minutes_before"
        case priority
        case eventId = "event_id"
        case recurrenceRule = "recurrence_rule"
        case notificationEnabled = "notification_enabled"
        case notificationSound = "notification_sound"
    }
}

// MARK: - Reminders Response

struct RemindersResponse: Codable {
    let reminders: [Reminder]
    let count: Int
}

// MARK: - Reminders Range Response

struct RemindersRangeResponse: Codable {
    let reminders: [Reminder]
    let count: Int
    let startDate: String
    let endDate: String
    
    enum CodingKeys: String, CodingKey {
        case reminders, count
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

// MARK: - Event Reminders Response

struct EventRemindersResponse: Codable {
    let reminders: [Reminder]
    let count: Int
    let eventId: Int64
    
    enum CodingKeys: String, CodingKey {
        case reminders, count
        case eventId = "event_id"
    }
}

// MARK: - Preview Recurring Instances Response

struct PreviewRecurringInstancesResponse: Codable {
    let reminderId: Int64
    let instances: [Reminder]
    let count: Int
    let startDate: String
    let endDate: String
    
    enum CodingKeys: String, CodingKey {
        case reminderId = "reminder_id"
        case instances, count
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

// MARK: - Date Formatter Extension

extension DateFormatter {
    static let reminderISO8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

