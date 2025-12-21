import Foundation
import UserNotifications
import Combine

/// Service for managing morning briefing notifications
/// Schedules a daily notification with a preview of the user's day
@MainActor
class MorningBriefingNotificationService: ObservableObject {
    static let shared = MorningBriefingNotificationService()

    // MARK: - Published Properties

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            if isEnabled {
                scheduleNotification()
            } else {
                cancelNotification()
            }
        }
    }

    @Published var scheduledTime: Date {
        didSet {
            UserDefaults.standard.set(scheduledTime, forKey: Keys.time)
            if isEnabled {
                scheduleNotification()
            }
        }
    }

    // MARK: - Constants

    private enum Keys {
        static let enabled = "morning_briefing_enabled"
        static let time = "morning_briefing_time"
    }

    private let notificationIdentifier = "morning-briefing"

    // MARK: - Engaging Copy Templates

    private let titles = [
        "Rise and shine!",
        "Good morning!",
        "Ready for today?",
        "Your day awaits"
    ]

    private let moodTemplates: [String: [String]] = [
        "focus_day": [
            "%d meetings, %@ focus time available. Let's do this!",
            "Perfect focus day ahead - %@ of uninterrupted time!",
            "Deep work day! %@ focus time between %d meetings."
        ],
        "light_day": [
            "Light schedule today - %@ of free time to use wisely!",
            "Easy day ahead with just %d meetings. Enjoy!",
            "Calm day: %d meetings, plenty of breathing room."
        ],
        "intense_meetings": [
            "Heads up: %d meetings today. Pace yourself!",
            "Busy day ahead! %d meetings on the calendar.",
            "Meeting marathon: %d scheduled. Stay energized!"
        ],
        "rest_day": [
            "Quiet day ahead. Just %d meeting(s) scheduled.",
            "Low-key day - perfect for catching up!",
            "Relaxed schedule today. Make it count!"
        ],
        "balanced": [
            "%d meetings balanced with %@ focus time.",
            "Well-balanced day: %d meetings, %@ free.",
            "Good mix today - meetings and focus time in harmony."
        ]
    ]

    private let fallbackMessages = [
        "Tap to see what's on your agenda today.",
        "Your daily briefing is ready.",
        "See how your day looks at a glance."
    ]

    // MARK: - Initialization

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: Keys.enabled)

        if let savedTime = UserDefaults.standard.object(forKey: Keys.time) as? Date {
            self.scheduledTime = savedTime
        } else {
            // Default: 7:30 AM
            var components = DateComponents()
            components.hour = 7
            components.minute = 30
            self.scheduledTime = Calendar.current.date(from: components) ?? Date()
        }
    }

    // MARK: - Public Methods

    /// Schedule the morning briefing notification
    func scheduleNotification() {
        guard isEnabled else { return }

        // Cancel any existing notification first
        cancelNotification()

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = titles.randomElement() ?? "Good morning!"
        content.body = fallbackMessages.randomElement() ?? "Your daily briefing is ready."
        content.sound = .default
        content.userInfo = [
            "type": "morning_briefing",
            "destination": "today"
        ]

        // Create calendar trigger for the scheduled time (repeating daily)
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.hour, .minute], from: scheduledTime)
        dateComponents.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        // Create and add the request
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule morning briefing notification: \(error.localizedDescription)")
            } else {
                let timeString = self.formattedTime(self.scheduledTime)
                print("Morning briefing notification scheduled for \(timeString) daily")
            }
        }
    }

    /// Cancel the morning briefing notification
    func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier]
        )
        print("Morning briefing notification cancelled")
    }

    /// Update notification content with fresh briefing data
    /// Call this when the app fetches new briefing data
    func updateNotificationContent(briefing: DailyBriefingResponse) {
        guard isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = titles.randomElement() ?? "Good morning!"
        content.body = generateNotificationBody(from: briefing)
        content.sound = .default
        content.userInfo = [
            "type": "morning_briefing",
            "destination": "today"
        ]

        // Re-schedule with updated content
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.hour, .minute], from: scheduledTime)
        dateComponents.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )

        // Remove old and add new
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier]
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to update morning briefing notification: \(error.localizedDescription)")
            } else {
                print("Morning briefing notification updated with fresh content")
            }
        }
    }

    /// Send a test notification immediately (for debugging/preview)
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = titles.randomElement() ?? "Good morning!"
        content.body = "3 meetings, 2h focus time available. Let's do this!"
        content.sound = .default
        content.userInfo = [
            "type": "morning_briefing",
            "destination": "today"
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)

        let request = UNNotificationRequest(
            identifier: "morning-briefing-test",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send test notification: \(error.localizedDescription)")
            } else {
                print("Test morning briefing notification sent")
            }
        }
    }

    // MARK: - Private Methods

    private func generateNotificationBody(from briefing: DailyBriefingResponse) -> String {
        let mood = briefing.mood.lowercased()
        let meetingsCount = briefing.quickStats?.meetingsCount ?? briefing.keyMetrics?.effectiveMeetingsCount ?? 0
        let focusTime = briefing.quickStats?.focusTimeAvailable ?? "some"

        // Try to use mood-specific template
        if let templates = moodTemplates[mood], let template = templates.randomElement() {
            // Format the template based on available placeholders
            if template.contains("%d") && template.contains("%@") {
                return String(format: template, meetingsCount, focusTime)
            } else if template.contains("%d") {
                return String(format: template, meetingsCount)
            } else if template.contains("%@") {
                return String(format: template, focusTime)
            }
            return template
        }

        // Fallback: use summary line from API if available
        if !briefing.summaryLine.isEmpty && briefing.summaryLine.count < 100 {
            return briefing.summaryLine
        }

        // Final fallback
        return fallbackMessages.randomElement() ?? "Your daily briefing is ready."
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Get the hour and minute components for display
    var timeComponents: (hour: Int, minute: Int) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: scheduledTime)
        return (components.hour ?? 7, components.minute ?? 30)
    }

    /// Set time from hour and minute components
    func setTime(hour: Int, minute: Int) {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        if let newDate = Calendar.current.date(from: components) {
            scheduledTime = newDate
        }
    }
}
