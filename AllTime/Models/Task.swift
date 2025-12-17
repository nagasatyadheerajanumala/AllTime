import Foundation
import SwiftUI

// MARK: - Task Model (renamed to avoid conflict with Swift's Task)

struct UserTask: Codable, Identifiable, Equatable {
    let id: Int64?
    var title: String
    var description: String?

    // Duration
    var durationMinutes: Int?
    var learnedDurationMinutes: Int?
    var effectiveDuration: Int?

    // Time preferences
    var preferredTimeSlot: TaskTimeSlot?
    var preferredTime: String? // HH:mm format
    var targetDate: Date?
    var deadline: Date?

    // Deadline preferences
    var deadlineType: TaskDeadlineType?
    var notifyMinutesBefore: Int? // Minutes before deadline to send notification

    // Reminder (sync with iOS Reminders)
    var isReminder: Bool?
    var reminderTime: Date?
    var syncToReminders: Bool? // Whether to sync to iOS Reminders app
    var eventKitReminderId: String? // iOS Reminders app ID for syncing

    // Scheduling
    var scheduledStart: Date?
    var scheduledEnd: Date?
    var aiSuggestedSlot: String?
    var isScheduledOnCalendar: Bool?

    // Priority and categorization
    var priority: TaskPriority?
    var category: String?
    var tags: String?

    // Status
    var status: TaskStatus?
    var completedAt: Date?
    var actualDurationMinutes: Int?

    // Metadata
    var createdAt: Date?
    var updatedAt: Date?
    var source: String?

    // Computed fields from API
    var isOverdue: Bool?
    var needsScheduling: Bool?
    var timeLabel: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case durationMinutes = "duration_minutes"
        case learnedDurationMinutes = "learned_duration_minutes"
        case effectiveDuration = "effective_duration"
        case preferredTimeSlot = "preferred_time_slot"
        case preferredTime = "preferred_time"
        case targetDate = "target_date"
        case deadline
        case deadlineType = "deadline_type"
        case notifyMinutesBefore = "notify_minutes_before"
        case isReminder = "is_reminder"
        case reminderTime = "reminder_time"
        case syncToReminders = "sync_to_reminders"
        case eventKitReminderId = "eventkit_reminder_id"
        case scheduledStart = "scheduled_start"
        case scheduledEnd = "scheduled_end"
        case aiSuggestedSlot = "ai_suggested_slot"
        case isScheduledOnCalendar = "is_scheduled_on_calendar"
        case priority, category, tags, status
        case completedAt = "completed_at"
        case actualDurationMinutes = "actual_duration_minutes"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case source
        case isOverdue = "is_overdue"
        case needsScheduling = "needs_scheduling"
        case timeLabel = "time_label"
    }

    // MARK: - Computed Properties

    var displayDuration: String {
        let duration = effectiveDuration ?? durationMinutes ?? 30
        if duration >= 60 {
            let hours = duration / 60
            let mins = duration % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(duration)m"
    }

    var priorityColor: Color {
        priority?.color ?? .secondary
    }

    var statusIcon: String {
        status?.icon ?? "circle"
    }

    var isComplete: Bool {
        status == .completed
    }

    var displayTimeLabel: String? {
        if let label = timeLabel {
            return label
        }
        if let start = scheduledStart {
            return start.formatted(date: .omitted, time: .shortened)
        }
        if let slot = preferredTimeSlot {
            return slot.displayName
        }
        return nil
    }
}

// MARK: - Task Deadline Type

enum TaskDeadlineType: String, Codable, CaseIterable {
    case endOfDay = "END_OF_DAY"
    case specificTime = "SPECIFIC_TIME"
    case endOfWeek = "END_OF_WEEK"
    case noDeadline = "NO_DEADLINE"

    var displayName: String {
        switch self {
        case .endOfDay: return "End of Day"
        case .specificTime: return "Specific Time"
        case .endOfWeek: return "End of Week"
        case .noDeadline: return "No Deadline"
        }
    }

    var icon: String {
        switch self {
        case .endOfDay: return "sun.horizon.fill"
        case .specificTime: return "clock.fill"
        case .endOfWeek: return "calendar.badge.clock"
        case .noDeadline: return "infinity"
        }
    }
}

// MARK: - Notification Timing Options

enum NotificationTiming: Int, CaseIterable, Identifiable {
    case atTime = 0
    case fiveMinutes = 5
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case twoHours = 120
    case oneDay = 1440

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .atTime: return "At time of deadline"
        case .fiveMinutes: return "5 minutes before"
        case .fifteenMinutes: return "15 minutes before"
        case .thirtyMinutes: return "30 minutes before"
        case .oneHour: return "1 hour before"
        case .twoHours: return "2 hours before"
        case .oneDay: return "1 day before"
        }
    }
}

// MARK: - Task Time Slot

enum TaskTimeSlot: String, Codable, CaseIterable {
    case morning = "MORNING"
    case afternoon = "AFTERNOON"
    case evening = "EVENING"
    case anytime = "ANYTIME"

    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .anytime: return "Flexible"
        }
    }

    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .anytime: return "clock.fill"
        }
    }

    var timeRange: String {
        switch self {
        case .morning: return "6 AM - 12 PM"
        case .afternoon: return "12 PM - 5 PM"
        case .evening: return "5 PM - 10 PM"
        case .anytime: return "Any time"
        }
    }
}

// MARK: - Task Priority

enum TaskPriority: String, Codable, CaseIterable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
    case urgent = "URGENT"

    var displayName: String {
        switch self {
        case .low: return "Flexible"
        case .medium: return "Regular"
        case .high: return "Important"
        case .urgent: return "Time-sensitive"
        }
    }

    var color: Color {
        switch self {
        case .low: return .secondary
        case .medium: return Color(hex: "007AFF")   // Blue
        case .high: return Color(hex: "5856D6")     // Indigo
        case .urgent: return Color(hex: "FF9500")   // Orange
        }
    }

    var icon: String {
        switch self {
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        case .urgent: return "exclamationmark.2"
        }
    }
}

// MARK: - Task Status

enum TaskStatus: String, Codable, CaseIterable {
    case pending = "PENDING"
    case scheduled = "SCHEDULED"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case deferred = "DEFERRED"
    case cancelled = "CANCELLED"

    var displayName: String {
        switch self {
        case .pending: return "To Do"
        case .scheduled: return "Scheduled"
        case .inProgress: return "In Progress"
        case .completed: return "Done"
        case .deferred: return "Deferred"
        case .cancelled: return "Cancelled"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "circle"
        case .scheduled: return "calendar.circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .completed: return "checkmark.circle.fill"
        case .deferred: return "arrow.uturn.right.circle"
        case .cancelled: return "xmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .secondary
        case .scheduled: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        case .deferred: return .purple
        case .cancelled: return .red
        }
    }
}

// MARK: - Task Request (For Create/Update)

struct TaskRequest: Codable {
    var title: String
    var description: String?
    var durationMinutes: Int?
    var preferredTimeSlot: String?
    var preferredTime: String?
    var targetDate: Date?
    var deadline: Date?
    var deadlineType: String?
    var notifyMinutesBefore: Int?
    var isReminder: Bool?
    var reminderTime: Date?
    var syncToReminders: Bool?
    var priority: String?
    var category: String?
    var tags: String?
    var source: String?

    enum CodingKeys: String, CodingKey {
        case title, description
        case durationMinutes = "duration_minutes"
        case preferredTimeSlot = "preferred_time_slot"
        case preferredTime = "preferred_time"
        case targetDate = "target_date"
        case deadline
        case deadlineType = "deadline_type"
        case notifyMinutesBefore = "notify_minutes_before"
        case isReminder = "is_reminder"
        case reminderTime = "reminder_time"
        case syncToReminders = "sync_to_reminders"
        case priority, category, tags, source
    }
}

// MARK: - Quick Add Request

struct QuickAddRequest: Codable {
    let title: String
    let source: String?
    let deadline: Date?
    let deadlineType: TaskDeadlineType?

    enum CodingKeys: String, CodingKey {
        case title
        case source
        case deadline
        case deadlineType = "deadline_type"
    }

    init(title: String, source: String? = nil, deadline: Date? = nil, deadlineType: TaskDeadlineType? = nil) {
        self.title = title
        self.source = source
        self.deadline = deadline
        self.deadlineType = deadlineType
    }
}

// MARK: - Complete Task Request

struct CompleteTaskRequest: Codable {
    let actualDurationMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case actualDurationMinutes = "actual_duration_minutes"
    }
}

// MARK: - Schedule Request

struct ScheduleTasksRequest: Codable {
    let date: String
    let timezone: String
}

// MARK: - Up Next Response

struct UpNextResponse: Codable {
    let tasks: [UserTask]
    let totalCount: Int
    let overdueCount: Int
    let highPriorityCount: Int

    enum CodingKeys: String, CodingKey {
        case tasks
        case totalCount = "totalCount"
        case overdueCount = "overdueCount"
        case highPriorityCount = "highPriorityCount"
    }
}

// MARK: - Schedule Response

struct ScheduleResponse: Codable {
    let scheduledTasks: [UserTask]
    let scheduledCount: Int
    let message: String

    enum CodingKeys: String, CodingKey {
        case scheduledTasks = "scheduledTasks"
        case scheduledCount = "scheduledCount"
        case message
    }
}
