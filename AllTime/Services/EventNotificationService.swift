import Foundation
import UserNotifications
import Combine

/// Service for scheduling local notifications before calendar events
@MainActor
class EventNotificationService: ObservableObject {
    static let shared = EventNotificationService()

    /// User's preferred notification time before events (in minutes)
    @Published var notificationMinutesBefore: Int {
        didSet {
            UserDefaults.standard.set(notificationMinutesBefore, forKey: "event_notification_minutes")
        }
    }

    /// Whether event notifications are enabled
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "event_notifications_enabled")
            if !notificationsEnabled {
                Task {
                    await cancelAllEventNotifications()
                }
            }
        }
    }

    private let notificationCenter = UNUserNotificationCenter.current()

    private init() {
        // Load saved preferences
        self.notificationMinutesBefore = UserDefaults.standard.object(forKey: "event_notification_minutes") as? Int ?? 10
        self.notificationsEnabled = UserDefaults.standard.object(forKey: "event_notifications_enabled") as? Bool ?? true
    }

    // MARK: - Public API

    /// Schedule notifications for all upcoming events
    func scheduleNotifications(for events: [CalendarEvent]) async {
        guard notificationsEnabled else {
            print("🔔 EventNotification: Notifications disabled, skipping")
            return
        }

        // Request permission if not already granted
        let granted = await requestNotificationPermission()
        guard granted else {
            print("🔔 EventNotification: Permission not granted")
            return
        }

        // Cancel existing event notifications before scheduling new ones
        await cancelAllEventNotifications()

        let now = Date()
        let cutoffTime = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now

        var scheduledCount = 0

        for event in events {
            // Skip events without start date or already passed
            guard let startDate = event.startDate,
                  startDate > now,
                  startDate <= cutoffTime else {
                continue
            }

            // Skip holidays and all-day events (optional - they usually don't need reminders)
            if event.allDay {
                continue
            }

            // Skip if event type is holiday
            if let eventType = event.eventType, eventType == "holiday" {
                continue
            }

            // Calculate notification time
            let notificationDate = Calendar.current.date(
                byAdding: .minute,
                value: -notificationMinutesBefore,
                to: startDate
            )

            guard let triggerDate = notificationDate, triggerDate > now else {
                continue
            }

            // Create notification
            let content = UNMutableNotificationContent()
            content.title = getNotificationTitle(for: event)
            content.body = getNotificationBody(for: event)
            content.sound = .default
            content.categoryIdentifier = "EVENT_REMINDER"
            content.userInfo = [
                "type": "event_reminder",
                "event_id": event.id,
                "event_title": event.title,
                "start_time": startDate.timeIntervalSince1970
            ]

            // Create trigger
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: triggerDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            // Create request with unique ID based on event
            let requestId = "event_\(event.id)"
            let request = UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)

            do {
                try await notificationCenter.add(request)
                scheduledCount += 1
                print("🔔 EventNotification: Scheduled for '\(event.title)' at \(triggerDate)")
            } catch {
                print("🔔 EventNotification: Failed to schedule for '\(event.title)': \(error.localizedDescription)")
            }
        }

        print("🔔 EventNotification: Scheduled \(scheduledCount) notifications")
    }

    /// Schedule a notification for a single event
    func scheduleNotification(for event: CalendarEvent) async {
        guard notificationsEnabled else { return }

        guard let startDate = event.startDate,
              startDate > Date() else {
            return
        }

        // Skip holidays
        if let eventType = event.eventType, eventType == "holiday" {
            return
        }

        let notificationDate = Calendar.current.date(
            byAdding: .minute,
            value: -notificationMinutesBefore,
            to: startDate
        )

        guard let triggerDate = notificationDate, triggerDate > Date() else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = getNotificationTitle(for: event)
        content.body = getNotificationBody(for: event)
        content.sound = .default
        content.categoryIdentifier = "EVENT_REMINDER"
        content.userInfo = [
            "type": "event_reminder",
            "event_id": event.id,
            "event_title": event.title
        ]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let requestId = "event_\(event.id)"
        let request = UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            print("🔔 EventNotification: Scheduled for '\(event.title)'")
        } catch {
            print("🔔 EventNotification: Failed: \(error.localizedDescription)")
        }
    }

    /// Cancel all event notifications
    func cancelAllEventNotifications() async {
        let requests = await notificationCenter.pendingNotificationRequests()
        let eventIds = requests.filter { $0.identifier.hasPrefix("event_") }.map { $0.identifier }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: eventIds)
        print("🔔 EventNotification: Cancelled \(eventIds.count) notifications")
    }

    /// Cancel notification for a specific event
    func cancelNotification(for eventId: Int64) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["event_\(eventId)"])
    }

    // MARK: - Permission

    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])

            if granted {
                // Register notification categories
                await registerNotificationCategories()
            }

            return granted
        } catch {
            print("🔔 EventNotification: Permission error: \(error.localizedDescription)")
            return false
        }
    }

    private func registerNotificationCategories() async {
        let openAction = UNNotificationAction(
            identifier: "OPEN_EVENT",
            title: "Open",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: [.destructive]
        )

        let category = UNNotificationCategory(
            identifier: "EVENT_REMINDER",
            actions: [openAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([category])
    }

    // MARK: - Notification Content

    private func getNotificationTitle(for event: CalendarEvent) -> String {
        let timeText = notificationMinutesBefore == 1 ? "1 minute" : "\(notificationMinutesBefore) minutes"
        return "Starting in \(timeText)"
    }

    private func getNotificationBody(for event: CalendarEvent) -> String {
        var body = event.title

        if let location = event.location, let locationName = location.name, !locationName.isEmpty {
            body += " at \(locationName)"
        }

        // Add event type indicator
        if let eventType = event.eventType {
            switch eventType {
            case "flight":
                body = "Flight: \(event.title)"
            case "hotel":
                body = "Hotel check-in: \(event.title)"
            case "birthday":
                body = "\(event.title)"
            default:
                break
            }
        }

        return body
    }
}
