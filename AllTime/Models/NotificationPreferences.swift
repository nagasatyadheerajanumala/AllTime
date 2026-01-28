import Foundation

/// Model for notification preferences synced with backend
struct NotificationPreferences: Codable, Equatable {
    // Master switch
    var notificationsEnabled: Bool?

    // Type toggles
    var morningBriefingEnabled: Bool?
    var eveningSummaryEnabled: Bool?
    var eventRemindersEnabled: Bool?
    var clashAlertsEnabled: Bool?
    var taskRemindersEnabled: Bool?
    var proactiveNudgesEnabled: Bool?
    var lunchRemindersEnabled: Bool?

    // Timing
    var morningBriefingHour: Int?
    var eveningSummaryHour: Int?
    var eventReminderMinutes: Int?

    // Quiet hours
    var quietHoursEnabled: Bool?
    var quietHoursStart: String?  // HH:mm format
    var quietHoursEnd: String?    // HH:mm format

    // Rate limits
    var maxNudgesPerDay: Int?
    var minMinutesBetweenNotifications: Int?

    // Weekend mode
    var weekendReduced: Bool?

    // Timezone
    var timezone: String?

    // MARK: - Defaults

    static var defaults: NotificationPreferences {
        NotificationPreferences(
            notificationsEnabled: true,
            morningBriefingEnabled: true,
            eveningSummaryEnabled: true,
            eventRemindersEnabled: true,
            clashAlertsEnabled: true,
            taskRemindersEnabled: true,
            proactiveNudgesEnabled: true,
            lunchRemindersEnabled: false,
            morningBriefingHour: 7,
            eveningSummaryHour: 20,
            eventReminderMinutes: 15,
            quietHoursEnabled: true,
            quietHoursStart: "22:00",
            quietHoursEnd: "07:00",
            maxNudgesPerDay: 5,
            minMinutesBetweenNotifications: 30,
            weekendReduced: true,
            timezone: TimeZone.current.identifier
        )
    }

    // MARK: - Helper Methods

    /// Convert morning briefing hour to Date for DatePicker
    var morningBriefingTime: Date {
        get {
            let hour = morningBriefingHour ?? 7
            var components = DateComponents()
            components.hour = hour
            components.minute = 0
            return Calendar.current.date(from: components) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour], from: newValue)
            morningBriefingHour = components.hour
        }
    }

    /// Convert evening summary hour to Date for DatePicker
    var eveningSummaryTime: Date {
        get {
            let hour = eveningSummaryHour ?? 20
            var components = DateComponents()
            components.hour = hour
            components.minute = 0
            return Calendar.current.date(from: components) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour], from: newValue)
            eveningSummaryHour = components.hour
        }
    }

    /// Convert quiet hours start string to Date for DatePicker
    var quietHoursStartTime: Date {
        get {
            parseTimeString(quietHoursStart ?? "22:00")
        }
        set {
            quietHoursStart = formatTimeToString(newValue)
        }
    }

    /// Convert quiet hours end string to Date for DatePicker
    var quietHoursEndTime: Date {
        get {
            parseTimeString(quietHoursEnd ?? "07:00")
        }
        set {
            quietHoursEnd = formatTimeToString(newValue)
        }
    }

    private func parseTimeString(_ timeString: String) -> Date {
        let parts = timeString.split(separator: ":")
        var components = DateComponents()
        components.hour = Int(parts.first ?? "0") ?? 0
        components.minute = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
        return Calendar.current.date(from: components) ?? Date()
    }

    private func formatTimeToString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

/// Response for notification history
struct NotificationHistoryResponse: Codable {
    let history: [NotificationHistoryEntry]
    let count: Int
    let days: Int
}

/// Individual notification history entry from backend
struct NotificationHistoryEntry: Codable, Identifiable {
    let id: Int64
    let type: String
    let subtype: String?
    let title: String
    let body: String
    let sentAt: String?
    let opened: Bool
    let clicked: Bool
    let acted: Bool
    let dismissed: Bool
    let outcome: String?
}

/// Response for notification stats
struct NotificationStatsResponse: Codable {
    let totalSent: Int
    let totalOpened: Int
    let totalClicked: Int
    let totalActed: Int
    let overallOpenRate: String
    let overallClickRate: String
    let overallActionRate: String
    let days: Int
    let byType: [String: TypeStats]?

    struct TypeStats: Codable {
        let total: Int
        let opened: Int
        let clicked: Int
        let acted: Int
        let openRate: String
        let clickRate: String
    }
}

/// Response for quiet hours status
struct QuietHoursStatusResponse: Codable {
    let isQuietHours: Bool
    let quietHoursEnabled: Bool
    let quietHoursStart: String?
    let quietHoursEnd: String?
    let timezone: String
}

/// Response for test notification
struct TestNotificationResponse: Codable {
    let message: String
    let type: String?
    let historyId: Int64?
    let variant: String?
    let reason: String?
}
