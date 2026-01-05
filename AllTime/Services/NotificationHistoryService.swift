import Foundation
import Combine

/// Manages notification history storage and retrieval
@MainActor
class NotificationHistoryService: ObservableObject {
    static let shared = NotificationHistoryService()

    private let storageKey = "notification_history"
    private let maxHistoryItems = 50  // Keep last 50 notifications

    @Published private(set) var notifications: [NotificationHistoryItem] = []
    @Published private(set) var unreadCount: Int = 0

    private init() {
        loadHistory()
    }

    // MARK: - Storage

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let items = try? JSONDecoder().decode([NotificationHistoryItem].self, from: data) else {
            notifications = []
            unreadCount = 0
            return
        }
        notifications = items
        unreadCount = items.filter { !$0.isRead }.count
        print("[NotificationHistory] Loaded \(items.count) notifications, \(unreadCount) unread")
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(notifications) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    // MARK: - Public API

    /// Add a notification to history
    func addNotification(_ item: NotificationHistoryItem) {
        notifications.insert(item, at: 0)

        // Trim old notifications
        if notifications.count > maxHistoryItems {
            notifications = Array(notifications.prefix(maxHistoryItems))
        }

        unreadCount = notifications.filter { !$0.isRead }.count
        saveHistory()
        print("[NotificationHistory] Added notification: \(item.type.rawValue) - \(item.title)")
    }

    /// Add a morning briefing notification
    func addMorningBriefing(title: String, body: String, meetingsCount: Int?, focusTime: String?, mood: String?) {
        let data = NotificationData(
            meetingsCount: meetingsCount,
            focusTimeAvailable: focusTime,
            mood: mood,
            destination: "today"
        )

        let item = NotificationHistoryItem(
            type: .morningBriefing,
            title: title,
            body: body,
            data: data
        )

        addNotification(item)
    }

    /// Add an evening summary notification
    func addEveningSummary(title: String, body: String, meetingsCompleted: Int?, totalMeetings: Int?, completionPercentage: Int?) {
        let data = NotificationData(
            meetingsCompleted: meetingsCompleted,
            totalMeetings: totalMeetings,
            completionPercentage: completionPercentage,
            destination: "day-review"
        )

        let item = NotificationHistoryItem(
            type: .eveningSummary,
            title: title,
            body: body,
            data: data
        )

        addNotification(item)
    }

    /// Add an event reminder notification
    func addEventReminder(title: String, body: String, eventId: String?, eventTitle: String?, eventTime: String?) {
        let data = NotificationData(
            eventId: eventId,
            eventTitle: eventTitle,
            eventTime: eventTime,
            destination: "calendar"
        )

        let item = NotificationHistoryItem(
            type: .eventReminder,
            title: title,
            body: body,
            data: data
        )

        addNotification(item)
    }

    /// Mark a notification as read
    func markAsRead(_ item: NotificationHistoryItem) {
        if let index = notifications.firstIndex(where: { $0.id == item.id }) {
            notifications[index].isRead = true
            unreadCount = notifications.filter { !$0.isRead }.count
            saveHistory()
        }
    }

    /// Mark all notifications as read
    func markAllAsRead() {
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        unreadCount = 0
        saveHistory()
    }

    /// Clear all notification history
    func clearHistory() {
        notifications = []
        unreadCount = 0
        saveHistory()
    }

    /// Get notifications grouped by date
    func notificationsGroupedByDate() -> [(date: Date, notifications: [NotificationHistoryItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: notifications) { item in
            calendar.startOfDay(for: item.timestamp)
        }

        return grouped
            .map { (date: $0.key, notifications: $0.value.sorted { $0.timestamp > $1.timestamp }) }
            .sorted { $0.date > $1.date }
    }

    /// Get today's notifications
    var todayNotifications: [NotificationHistoryItem] {
        let calendar = Calendar.current
        return notifications.filter { calendar.isDateInToday($0.timestamp) }
    }

    /// Get yesterday's notifications
    var yesterdayNotifications: [NotificationHistoryItem] {
        let calendar = Calendar.current
        return notifications.filter { calendar.isDateInYesterday($0.timestamp) }
    }
}
