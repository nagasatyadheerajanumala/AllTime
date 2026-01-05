import Foundation
import UserNotifications
import Combine

/// Service for managing morning briefing notifications
/// Schedules a daily notification with a preview of the user's day
@MainActor
class MorningBriefingNotificationService: ObservableObject {
    static let shared = MorningBriefingNotificationService()

    private let historyService = NotificationHistoryService.shared

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

    /// Generate a personalized title using the user's first name
    private func getPersonalizedTitle() -> String {
        let firstName = UserDefaults.standard.string(forKey: "user_first_name")
        let hour = Calendar.current.component(.hour, from: Date())

        let timeGreeting: String
        if hour < 12 {
            timeGreeting = "Good morning"
        } else if hour < 17 {
            timeGreeting = "Good afternoon"
        } else {
            timeGreeting = "Good evening"
        }

        if let name = firstName, !name.isEmpty {
            // Personalized greetings with name
            let personalizedOptions = [
                "\(timeGreeting), \(name)!",
                "Rise and shine, \(name)!",
                "Ready for today, \(name)?",
                "\(name), your day awaits"
            ]
            return personalizedOptions.randomElement() ?? "\(timeGreeting), \(name)!"
        } else {
            // Fallback to generic titles
            let genericOptions = [
                "Rise and shine!",
                "\(timeGreeting)!",
                "Ready for today?",
                "Your day awaits"
            ]
            return genericOptions.randomElement() ?? "\(timeGreeting)!"
        }
    }

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

    /// Generate personalized fallback messages
    private func getPersonalizedFallbackMessage() -> String {
        let firstName = UserDefaults.standard.string(forKey: "user_first_name")
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())

        // Weekend-specific messages
        if dayOfWeek == 1 || dayOfWeek == 7 {
            if let name = firstName, !name.isEmpty {
                let weekendMessages = [
                    "\(name), enjoy your weekend! Here's what's on your radar.",
                    "Weekend vibes, \(name)! See your day ahead.",
                    "Happy weekend, \(name)! Your day is looking good."
                ]
                return weekendMessages.randomElement() ?? "Your weekend briefing is ready."
            }
            return "Weekend mode activated! Here's your day."
        }

        // Weekday personalized messages
        if let name = firstName, !name.isEmpty {
            let personalizedMessages = [
                "\(name), here's your day at a glance.",
                "Ready to make today great, \(name)?",
                "\(name), let's see what's ahead today.",
                "Your day is planned and ready, \(name)!"
            ]
            return personalizedMessages.randomElement() ?? "Your briefing is ready, \(name)."
        }

        // Generic fallback
        let genericMessages = [
            "Tap to see what's on your agenda today.",
            "Your daily briefing is ready.",
            "See how your day looks at a glance.",
            "Ready to take on the day? Here's your plan."
        ]
        return genericMessages.randomElement() ?? "Your daily briefing is ready."
    }

    private let fallbackMessages = [
        "Tap to see what's on your agenda today.",
        "Your daily briefing is ready.",
        "See how your day looks at a glance."
    ]

    // MARK: - Initialization

    private init() {
        // Load saved enabled state, default to true for new users
        let hasBeenConfigured = UserDefaults.standard.object(forKey: Keys.enabled) != nil
        self.isEnabled = hasBeenConfigured ? UserDefaults.standard.bool(forKey: Keys.enabled) : true

        if let savedTime = UserDefaults.standard.object(forKey: Keys.time) as? Date {
            self.scheduledTime = savedTime
        } else {
            // Default: 7:30 AM
            var components = DateComponents()
            components.hour = 7
            components.minute = 30
            self.scheduledTime = Calendar.current.date(from: components) ?? Date()
        }

        // Save default enabled state for new users
        if !hasBeenConfigured {
            UserDefaults.standard.set(true, forKey: Keys.enabled)
        }

        // Schedule notification on init if enabled (didSet doesn't fire during init)
        if self.isEnabled {
            Task { @MainActor in
                self.scheduleNotification()
            }
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
        content.title = getPersonalizedTitle()
        content.body = getPersonalizedFallbackMessage()
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

        let title = getPersonalizedTitle()
        let body = generateNotificationBody(from: briefing)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
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

        // Save to notification history
        let meetingsCount = briefing.quickStats?.meetingsCount ?? briefing.keyMetrics?.effectiveMeetingsCount
        let focusTime = briefing.quickStats?.focusTimeAvailable
        let mood = briefing.mood

        historyService.addMorningBriefing(
            title: title,
            body: body,
            meetingsCount: meetingsCount,
            focusTime: focusTime,
            mood: mood
        )
    }

    /// Send a test notification immediately (for debugging/preview)
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = getPersonalizedTitle()
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
        return getPersonalizedFallbackMessage()
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
