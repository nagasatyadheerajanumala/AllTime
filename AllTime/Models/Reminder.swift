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
}

// MARK: - Reminder Priority

enum ReminderPriority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "blue"
        case .medium: return "orange"
        case .high: return "red"
        case .urgent: return "purple"
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
        case .pending: return "Pending"
        case .completed: return "Completed"
        case .snoozed: return "Snoozed"
        case .cancelled: return "Cancelled"
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

