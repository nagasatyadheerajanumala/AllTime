import Foundation

/// Represents a notification that was shown to the user
struct NotificationHistoryItem: Codable, Identifiable {
    let id: UUID
    let type: NotificationType
    let title: String
    let body: String
    let timestamp: Date
    let data: NotificationData?
    var isRead: Bool

    init(
        id: UUID = UUID(),
        type: NotificationType,
        title: String,
        body: String,
        timestamp: Date = Date(),
        data: NotificationData? = nil,
        isRead: Bool = false
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.timestamp = timestamp
        self.data = data
        self.isRead = isRead
    }

    enum NotificationType: String, Codable {
        case morningBriefing = "morning_briefing"
        case eveningSummary = "evening_summary"
        case eventReminder = "event_reminder"
        case reminderDue = "reminder_due"
        case reminder = "reminder"           // Generic reminder from backend schedulers
        case calendarSync = "calendar_sync"
        case nudge = "nudge"                 // Proactive nudge notifications
        case dailySummary = "daily_summary"  // Alternative daily summary
        case test = "test"                   // Test notifications
        case system = "system"

        var icon: String {
            switch self {
            case .morningBriefing: return "sun.horizon.fill"
            case .eveningSummary: return "moon.stars.fill"
            case .eventReminder: return "calendar.badge.clock"
            case .reminderDue: return "bell.fill"
            case .reminder: return "bell.badge"
            case .calendarSync: return "arrow.triangle.2.circlepath"
            case .nudge: return "lightbulb.fill"
            case .dailySummary: return "doc.text.fill"
            case .test: return "checkmark.circle.fill"
            case .system: return "gear"
            }
        }

        var displayName: String {
            switch self {
            case .morningBriefing: return "Morning Briefing"
            case .eveningSummary: return "Evening Summary"
            case .eventReminder: return "Event Reminder"
            case .reminderDue: return "Reminder"
            case .reminder: return "Reminder"
            case .calendarSync: return "Calendar Sync"
            case .nudge: return "Smart Nudge"
            case .dailySummary: return "Daily Summary"
            case .test: return "Test"
            case .system: return "System"
            }
        }
    }
}

/// Additional data associated with a notification
struct NotificationData: Codable {
    // Morning briefing data
    var meetingsCount: Int?
    var focusTimeAvailable: String?
    var mood: String?

    // Evening summary data
    var meetingsCompleted: Int?
    var totalMeetings: Int?
    var completionPercentage: Int?

    // Event/Reminder data
    var eventId: String?
    var reminderId: Int64?
    var eventTitle: String?
    var eventTime: String?

    // Nudge data
    var nudgeType: String?
    var actionUrl: String?

    // Deep link destination
    var destination: String?
}
