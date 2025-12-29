import Foundation
import UserNotifications
import Combine

/// Service for managing evening summary notifications
/// Schedules a daily notification with a recap of the user's day
@MainActor
class EveningSummaryNotificationService: ObservableObject {
    static let shared = EveningSummaryNotificationService()

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
        static let enabled = "evening_summary_enabled"
        static let time = "evening_summary_time"
    }

    private let notificationIdentifier = "evening-summary"

    // MARK: - Engaging Copy Templates

    private let titles = [
        "Day in review",
        "How was your day?",
        "Daily wrap-up",
        "End of day recap",
        "Your day, summarized"
    ]

    private let productiveDayMessages = [
        "Productive day! You completed %d of %d meetings.",
        "Great work today! %d meetings done, %@ focus time used.",
        "You crushed it! %d meetings and stayed focused.",
        "Strong finish! Here's how your day went."
    ]

    private let busyDayMessages = [
        "Busy day done! %d meetings behind you.",
        "Marathon day complete - %d meetings in the books.",
        "You made it through %d meetings today!",
        "Intense day wrapped up. Time to unwind."
    ]

    private let lightDayMessages = [
        "Relaxed day complete. Just %d meetings today.",
        "Easy day in the books - hope you enjoyed the breathing room!",
        "Light schedule wrapped up nicely.",
        "Peaceful day done. Well deserved!"
    ]

    private let fallbackMessages = [
        "See how your day went and reflect.",
        "Your day review is ready.",
        "Review your day and rate how it went.",
        "Time to reflect on your day."
    ]

    // MARK: - Initialization

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: Keys.enabled)

        if let savedTime = UserDefaults.standard.object(forKey: Keys.time) as? Date {
            self.scheduledTime = savedTime
        } else {
            // Default: 8:00 PM
            var components = DateComponents()
            components.hour = 20
            components.minute = 0
            self.scheduledTime = Calendar.current.date(from: components) ?? Date()
        }
    }

    // MARK: - Public Methods

    /// Schedule the evening summary notification
    func scheduleNotification() {
        guard isEnabled else { return }

        // Cancel any existing notification first
        cancelNotification()

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = titles.randomElement() ?? "Day in review"
        content.body = fallbackMessages.randomElement() ?? "Your daily recap is ready."
        content.sound = .default
        content.userInfo = [
            "type": "evening_summary",
            "destination": "day-review"
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
                print("Failed to schedule evening summary notification: \(error.localizedDescription)")
            } else {
                let timeString = self.formattedTime(self.scheduledTime)
                print("Evening summary notification scheduled for \(timeString) daily")
            }
        }
    }

    /// Cancel the evening summary notification
    func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier]
        )
        print("Evening summary notification cancelled")
    }

    /// Update notification content with fresh summary data
    func updateNotificationContent(
        meetingsCompleted: Int,
        totalMeetings: Int,
        focusTimeUsed: String?,
        mood: String?
    ) {
        guard isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = titles.randomElement() ?? "Day in review"
        content.body = generateNotificationBody(
            meetingsCompleted: meetingsCompleted,
            totalMeetings: totalMeetings,
            focusTimeUsed: focusTimeUsed,
            mood: mood
        )
        content.sound = .default
        content.userInfo = [
            "type": "evening_summary",
            "destination": "day-review"
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
                print("Failed to update evening summary notification: \(error.localizedDescription)")
            } else {
                print("Evening summary notification updated with fresh content")
            }
        }
    }

    /// Send a test notification immediately (for debugging/preview)
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = titles.randomElement() ?? "Day in review"
        content.body = "See how your day went and reflect on it."
        content.sound = .default
        content.userInfo = [
            "type": "evening_summary",
            "destination": "day-review"
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)

        let request = UNNotificationRequest(
            identifier: "evening-summary-test",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send test notification: \(error.localizedDescription)")
            } else {
                print("Test evening summary notification sent")
            }
        }
    }

    // MARK: - Private Methods

    private func generateNotificationBody(
        meetingsCompleted: Int,
        totalMeetings: Int,
        focusTimeUsed: String?,
        mood: String?
    ) -> String {
        // Determine day type based on meeting count
        if totalMeetings >= 6 {
            // Busy day
            if let template = busyDayMessages.randomElement() {
                if template.contains("%d") {
                    return String(format: template, meetingsCompleted)
                }
                return template
            }
        } else if totalMeetings <= 2 {
            // Light day
            if let template = lightDayMessages.randomElement() {
                if template.contains("%d") {
                    return String(format: template, meetingsCompleted)
                }
                return template
            }
        } else {
            // Productive/balanced day
            if let template = productiveDayMessages.randomElement() {
                if template.contains("%d") && template.contains("%@") {
                    return String(format: template, meetingsCompleted, focusTimeUsed ?? "some")
                } else if template.contains("%d") {
                    // Check if it needs two %d
                    let count = template.components(separatedBy: "%d").count - 1
                    if count >= 2 {
                        return String(format: template, meetingsCompleted, totalMeetings)
                    }
                    return String(format: template, meetingsCompleted)
                }
                return template
            }
        }

        return fallbackMessages.randomElement() ?? "Your daily recap is ready."
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
        return (components.hour ?? 20, components.minute ?? 0)
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
