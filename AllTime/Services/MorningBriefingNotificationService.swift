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

    /// Generate an engaging title based on briefing data
    /// Uses insights to create curiosity-driven titles
    private func getEngagingTitle(from briefing: DailyBriefingResponse?) -> String {
        let firstName = UserDefaults.standard.string(forKey: "user_first_name")
        let name = firstName ?? ""
        let hasName = !name.isEmpty

        // If we have briefing data, create insight-driven titles
        if let briefing = briefing {
            // Based on energy trajectory
            if let energy = briefing.energyBudget, let trajectory = energy.trajectory?.lowercased() {
                if trajectory == "declining" {
                    return hasName ? "\(name), heads up about today" : "Heads up about today"
                }
            }

            // Based on meeting load
            if let metrics = briefing.keyMetrics {
                let meetings = metrics.effectiveMeetingsCount
                if meetings == 0 {
                    return hasName ? "\(name), today's different" : "Today's different"
                } else if meetings >= 6 {
                    return hasName ? "\(name), brace yourself" : "Brace yourself"
                }
            }

            // Based on day mood/type
            let mood = briefing.mood.lowercased()
            switch mood {
            case "focus_day":
                return hasName ? "Deep work day, \(name)" : "Deep work day ahead"
            case "rest_day":
                return hasName ? "Easy day, \(name)" : "Easy day ahead"
            case "intense_meetings":
                return hasName ? "\(name), marathon day" : "Marathon day ahead"
            default:
                break
            }

            // Based on primary recommendation urgency
            if let rec = briefing.primaryRecommendation, let urgency = rec.urgency?.lowercased() {
                if urgency == "now" {
                    return hasName ? "\(name), act now" : "Before you start"
                }
            }
        }

        // Fallback to simple personalized greeting
        return hasName ? "Morning, \(name)" : "Your morning brief"
    }

    /// Simple personalized title without briefing data
    private func getPersonalizedTitle() -> String {
        let firstName = UserDefaults.standard.string(forKey: "user_first_name")
        if let name = firstName, !name.isEmpty {
            return "Morning, \(name)"
        }
        return "Your morning brief"
    }

    // MARK: - Insight-Driven Notification Generation
    // The goal: Tell them something they DON'T already know
    // Not "you have 3 meetings" but WHY that matters

    /// Generate personalized fallback messages
    /// Note: For repeating notifications, we use day-agnostic messages since content is
    /// set at schedule time, not fire time. Day-specific content is set via updateNotificationContent.
    private func getPersonalizedFallbackMessage() -> String {
        let firstName = UserDefaults.standard.string(forKey: "user_first_name")

        // Use day-agnostic messages for repeating notifications
        // The notification content will be updated with day-specific info when the app refreshes
        if let name = firstName, !name.isEmpty {
            let personalizedMessages = [
                "\(name), here's your day at a glance.",
                "Ready to make today great, \(name)?",
                "\(name), let's see what's ahead today.",
                "Your day is planned and ready, \(name)!",
                "\(name), tap to see your schedule."
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

        let title = getEngagingTitle(from: briefing)
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
        // PRIORITY 1: Day Narrative headline - AI-generated insight about the day
        // This is the most valuable piece of content
        if let narrative = briefing.dayNarrative, !narrative.headline.isEmpty {
            return narrative.headline
        }

        // PRIORITY 2: Primary recommendation with consequence
        // Tell them THE one thing they should do and why
        if let rec = briefing.primaryRecommendation {
            if let consequence = rec.ignoredConsequence, !consequence.isEmpty {
                // e.g., "Block 90 min for deep work or you'll hit afternoon with nothing done"
                return "\(rec.action) — \(consequence.lowercased())"
            }
            if let reason = rec.reason, !reason.isEmpty && reason.count < 80 {
                return "\(rec.action): \(reason)"
            }
            return rec.action
        }

        // PRIORITY 3: Energy-based insights - what they don't know about their day
        if let energy = briefing.energyBudget {
            // Peak energy window insight
            if let peak = energy.peakWindow, let startTime = peak.startTime {
                let timeStr = formatTimeString(startTime)
                return "Your energy peaks at \(timeStr) — that's your best window for important work."
            }
            // Energy trajectory warning
            if let trajectory = energy.trajectory?.lowercased(), trajectory == "declining" {
                if let recovery = energy.recoveryRecommendation, !recovery.isEmpty {
                    return "Energy declining today. \(recovery)"
                }
                return "Energy will decline through the day. Front-load your important tasks."
            }
            // Recovery needed
            if energy.recoveryNeeded == true, let recovery = energy.recoveryRecommendation {
                return recovery
            }
        }

        // PRIORITY 4: Comparison-based insights - how today differs
        if let metrics = briefing.keyMetrics {
            // Sleep comparison
            if let sleepLast = metrics.sleepHoursLastNight, let sleepAvg = metrics.sleepHoursAverage {
                let diff = sleepLast - sleepAvg
                if diff < -1.0 {
                    return String(format: "You slept %.1fh less than usual. Consider lighter tasks this morning.", abs(diff))
                } else if diff > 1.0 {
                    return String(format: "%.1fh extra sleep last night — you're primed for deep work today.", diff)
                }
            }
            // Meeting load comparison
            let meetingsToday = metrics.effectiveMeetingsCount
            if let avgMeetings = metrics.meetingsAverageCount {
                let diff = Double(meetingsToday) - avgMeetings
                if diff >= 2 {
                    return "\(meetingsToday) meetings — \(Int(diff)) more than usual. Pace yourself."
                } else if diff <= -2 && meetingsToday <= 2 {
                    return "Only \(meetingsToday) meeting\(meetingsToday == 1 ? "" : "s") today. Rare opportunity for deep work."
                }
            }
        }

        // PRIORITY 5: Focus window insight
        if let focusWindows = briefing.focusWindows, let firstWindow = focusWindows.first {
            let duration = firstWindow.durationMinutes
            if duration >= 60 {
                let hours = duration / 60
                let startTime = firstWindow.startTime
                if hours >= 2 {
                    return "\(hours)h uninterrupted block at \(startTime) — protect this for your hardest task."
                }
            }
        }

        // PRIORITY 6: First observation from day narrative
        if let narrative = briefing.dayNarrative,
           let observations = narrative.keyObservations,
           let first = observations.first, !first.isEmpty {
            return first
        }

        // PRIORITY 7: Summary line from API
        if !briefing.summaryLine.isEmpty && briefing.summaryLine.count < 100 {
            return briefing.summaryLine
        }

        // Final fallback
        return getPersonalizedFallbackMessage()
    }

    /// Format time string like "09:00" to "9am"
    private func formatTimeString(_ timeStr: String) -> String {
        let parts = timeStr.split(separator: ":")
        guard let hourStr = parts.first, let hour = Int(hourStr) else { return timeStr }

        if hour == 0 { return "12am" }
        if hour == 12 { return "12pm" }
        if hour < 12 { return "\(hour)am" }
        return "\(hour - 12)pm"
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
