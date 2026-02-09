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

    // MARK: - Creative Notification Content
    // Goal: Be a helpful friend, not a nagging alarm

    private func getNotificationTitle(for event: CalendarEvent) -> String {
        let minutes = notificationMinutesBefore
        let titleLower = event.title.lowercased()
        let hour = Calendar.current.component(.hour, from: Date())
        let weekday = Calendar.current.component(.weekday, from: Date())

        // Special event types
        if let eventType = event.eventType {
            switch eventType {
            case "flight":
                return "✈️ Flight's coming up"
            case "hotel":
                return "🏨 Check-in time soon"
            case "birthday":
                return "🎂 Birthday alert!"
            default:
                break
            }
        }

        // Friday 4pm+ meetings deserve special treatment
        if weekday == 6 && hour >= 16 {
            return [
                "Friday EOD meeting 😅",
                "Late Friday meeting...",
                "Almost weekend, but first..."
            ].randomElement()!
        }

        // Early morning (before 9am) meetings
        if hour < 9 && minutes <= 15 {
            return [
                "Early bird meeting",
                "Morning meeting incoming",
                "Rise and meet"
            ].randomElement()!
        }

        // 1:1 meetings — personal touch
        if titleLower.contains("1:1") || titleLower.contains("1-1") || titleLower.contains("one on one") {
            if titleLower.contains("manager") || titleLower.contains("skip") {
                return "1:1 with leadership soon"
            }
            return [
                "1:1 time",
                "1:1 coming up",
                "Heads up: 1:1"
            ].randomElement()!
        }

        // Standup/daily sync — quick acknowledgment
        if titleLower.contains("standup") || titleLower.contains("stand-up") || titleLower.contains("daily sync") || titleLower.contains("daily scrum") {
            return [
                "Standup time",
                "Daily sync incoming",
                "Standup in \(minutes)"
            ].randomElement()!
        }

        // Interview — supportive
        if titleLower.contains("interview") {
            return "🎯 Interview time — you've got this"
        }

        // All-hands, town hall — FYI energy
        if titleLower.contains("all-hands") || titleLower.contains("town hall") || titleLower.contains("all hands") {
            return [
                "All-hands starting soon",
                "Company meeting incoming",
                "All-hands time"
            ].randomElement()!
        }

        // Lunch/coffee/social — positive
        if titleLower.contains("lunch") || titleLower.contains("coffee") || titleLower.contains("catch up") || titleLower.contains("happy hour") {
            return [
                "Social time ☕",
                "Break incoming",
                "Time for humans"
            ].randomElement()!
        }

        // Training/workshop — heads up it's long
        if titleLower.contains("training") || titleLower.contains("workshop") || titleLower.contains("session") {
            return [
                "Training starting",
                "Workshop time",
                "Learning session ahead"
            ].randomElement()!
        }

        // Long meeting warning (90+ min)
        // Note: duration is in SECONDS (TimeInterval), so 90 min = 5400 seconds
        if let duration = event.duration, duration >= 5400 {
            let hours = duration / 3600
            let displayHours = hours >= 1.5 ? String(format: "%.1fh", hours) : String(format: "%dm", Int(duration / 60))
            return [
                "Long one ahead (\(displayHours))",
                "Buckle up — long meeting",
                "Marathon meeting incoming"
            ].randomElement()!
        }

        // Imminent (5 min or less)
        if minutes <= 5 {
            return [
                "Starting now",
                "It's time",
                "Go time"
            ].randomElement()!
        }

        // Standard timing variations
        if minutes <= 10 {
            return [
                "\(minutes) min warning",
                "Starting soon",
                "Almost time"
            ].randomElement()!
        }

        if minutes == 15 {
            return [
                "15 min heads up",
                "Meeting in 15",
                "Quick heads up"
            ].randomElement()!
        }

        // Default
        return [
            "In \(minutes) minutes",
            "\(minutes) min warning",
            "Coming up"
        ].randomElement()!
    }

    private func getNotificationBody(for event: CalendarEvent) -> String {
        let title = event.title
        let titleLower = title.lowercased()
        let weekday = Calendar.current.component(.weekday, from: Date())
        let hour = Calendar.current.component(.hour, from: Date())

        // Special event types with personality
        if let eventType = event.eventType {
            switch eventType {
            case "flight":
                if let location = event.location, let name = location.name, !name.isEmpty {
                    return "✈️ \(title) → \(name). Gate info ready?"
                }
                return "✈️ \(title). Boarding pass + ID. Let's go."
            case "hotel":
                return "🏨 \(title). Got your confirmation number?"
            case "birthday":
                return "🎂 \(title) — don't forget to say happy birthday!"
            default:
                break
            }
        }

        var body = title

        // Location context with personality
        if let location = event.location, let locationName = location.name, !locationName.isEmpty {
            let locLower = locationName.lowercased()

            if locLower.contains("zoom") {
                body += " 📹 Zoom"
            } else if locLower.contains("meet.google") || locLower.contains("google meet") {
                body += " 📹 Google Meet"
            } else if locLower.contains("teams") {
                body += " 📹 Teams"
            } else if locLower.contains("http") || locLower.contains("://") {
                body += " (virtual)"
            } else {
                // Physical location
                let shortLoc = locationName.prefix(25)
                body += " 📍 \(shortLoc)"
            }
        }

        // Context-aware additions
        // Interview support
        if titleLower.contains("interview") {
            body += ". Deep breath. You're prepared."
        }
        // Presentation/review encouragement
        else if titleLower.contains("presentation") || titleLower.contains("present") {
            body += ". You know your stuff."
        }
        else if titleLower.contains("review") && (titleLower.contains("perf") || titleLower.contains("annual")) {
            body += ". You've got this."
        }
        // Friday late meeting sympathy
        else if weekday == 6 && hour >= 16 {
            body += ". Then: weekend."
        }
        // Early meeting acknowledgment
        else if hour < 9 {
            body += ". Coffee first?"
        }
        // 1:1 with specific person — keep it clean
        else if titleLower.contains("1:1") || titleLower.contains("1-1") {
            // Don't add extra text for 1:1s
        }
        // Long meeting prep (90+ min = 5400 seconds)
        else if let duration = event.duration, duration >= 5400 {
            body += ". It's a long one — snacks recommended."
        }

        return body
    }
}
