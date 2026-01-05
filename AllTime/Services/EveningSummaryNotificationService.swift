import Foundation
import UserNotifications
import Combine

/// Service for managing evening summary notifications
/// Schedules a daily notification with a recap of the user's day
@MainActor
class EveningSummaryNotificationService: ObservableObject {
    static let shared = EveningSummaryNotificationService()

    private let apiService = APIService()
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
        static let enabled = "evening_summary_enabled"
        static let time = "evening_summary_time"
    }

    private let notificationIdentifier = "evening-summary"

    // MARK: - Engaging Copy Templates

    /// Generate a personalized evening title using the user's first name
    private func getPersonalizedTitle() -> String {
        let firstName = UserDefaults.standard.string(forKey: "user_first_name")

        if let name = firstName, !name.isEmpty {
            // Personalized greetings with name
            let personalizedOptions = [
                "How was your day, \(name)?",
                "\(name)'s day in review",
                "Time to reflect, \(name)",
                "\(name), your day is done!"
            ]
            return personalizedOptions.randomElement() ?? "How was your day, \(name)?"
        } else {
            // Fallback to generic titles
            let genericOptions = [
                "Day in review",
                "How was your day?",
                "Daily wrap-up",
                "End of day recap"
            ]
            return genericOptions.randomElement() ?? "Day in review"
        }
    }

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

    /// Generate personalized fallback messages for evening summary
    private func getPersonalizedFallbackMessage() -> String {
        let firstName = UserDefaults.standard.string(forKey: "user_first_name")
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())

        // Weekend-specific messages
        if dayOfWeek == 1 || dayOfWeek == 7 {
            if let name = firstName, !name.isEmpty {
                let weekendMessages = [
                    "How was your weekend day, \(name)?",
                    "\(name), time to reflect on your day.",
                    "Rest up, \(name)! See how today went."
                ]
                return weekendMessages.randomElement() ?? "Your weekend recap is ready."
            }
            return "Weekend day wrapped up! See how it went."
        }

        // Weekday personalized messages
        if let name = firstName, !name.isEmpty {
            let personalizedMessages = [
                "\(name), take a moment to reflect.",
                "Another day done, \(name)! How did it go?",
                "\(name), see what you accomplished today.",
                "Time to unwind, \(name). Review your day."
            ]
            return personalizedMessages.randomElement() ?? "Your day review is ready, \(name)."
        }

        // Generic fallback
        let genericMessages = [
            "See how your day went and reflect.",
            "Your day review is ready.",
            "Review your day and rate how it went.",
            "Time to reflect on your day."
        ]
        return genericMessages.randomElement() ?? "Your day review is ready."
    }

    private let fallbackMessages = [
        "See how your day went and reflect.",
        "Your day review is ready.",
        "Review your day and rate how it went.",
        "Time to reflect on your day."
    ]

    // MARK: - Initialization

    private init() {
        // Load saved enabled state, default to true for new users
        let hasBeenConfigured = UserDefaults.standard.object(forKey: Keys.enabled) != nil
        self.isEnabled = hasBeenConfigured ? UserDefaults.standard.bool(forKey: Keys.enabled) : true

        if let savedTime = UserDefaults.standard.object(forKey: Keys.time) as? Date {
            self.scheduledTime = savedTime
        } else {
            // Default: 8:00 PM
            var components = DateComponents()
            components.hour = 20
            components.minute = 0
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
                self.scheduleContentRefresh()
            }
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
        content.title = getPersonalizedTitle()
        content.body = getPersonalizedFallbackMessage()
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
        content.title = getPersonalizedTitle()
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
        content.title = getPersonalizedTitle()
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

    /// Fetch today's summary data and update notification content
    /// Call this before the scheduled notification time (e.g., 30 min before)
    func refreshNotificationWithSummaryData() async {
        guard isEnabled else { return }

        do {
            // Fetch today's day review data
            let review = try await DayReviewService.shared.getDayReview(date: Date())

            let meetingsCompleted = review.totalCompleted
            let totalMeetings = review.totalPlanned
            let completionPercentage = review.completionPercentage

            // Generate engaging notification content
            let title = getPersonalizedTitle()
            let body = generateSummaryBody(
                meetingsCompleted: meetingsCompleted,
                totalMeetings: totalMeetings,
                completionPercentage: completionPercentage
            )

            // Update the scheduled notification
            updateNotificationContent(
                meetingsCompleted: meetingsCompleted,
                totalMeetings: totalMeetings,
                focusTimeUsed: nil,
                mood: nil
            )

            // Save to notification history
            historyService.addEveningSummary(
                title: title,
                body: body,
                meetingsCompleted: meetingsCompleted,
                totalMeetings: totalMeetings,
                completionPercentage: completionPercentage
            )

            print("[EveningSummary] Updated notification with summary: \(meetingsCompleted)/\(totalMeetings) completed (\(completionPercentage)%)")
        } catch {
            print("[EveningSummary] Failed to fetch summary data: \(error.localizedDescription)")
            // Keep fallback notification content
        }
    }

    /// Generate a summary-specific notification body
    private func generateSummaryBody(meetingsCompleted: Int, totalMeetings: Int, completionPercentage: Int) -> String {
        if totalMeetings == 0 {
            return "Quiet day today! Take a moment to reflect on how you spent your time."
        }

        if completionPercentage >= 80 {
            return "Great day! You completed \(meetingsCompleted) of \(totalMeetings) planned activities (\(completionPercentage)%). How did it feel?"
        } else if completionPercentage >= 50 {
            return "You completed \(meetingsCompleted) of \(totalMeetings) activities today (\(completionPercentage)%). Tap to reflect on your day."
        } else if totalMeetings >= 6 {
            return "Busy day with \(totalMeetings) meetings! You got through \(meetingsCompleted). Time to unwind and reflect."
        } else {
            return "You completed \(meetingsCompleted) of \(totalMeetings) planned activities. How did your day go?"
        }
    }

    /// Schedule a background task to refresh notification content before it fires
    func scheduleContentRefresh() {
        // Calculate time 30 minutes before the notification
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.hour, .minute], from: scheduledTime)

        // Subtract 30 minutes for refresh
        if let hour = dateComponents.hour, let minute = dateComponents.minute {
            var refreshMinute = minute - 30
            var refreshHour = hour
            if refreshMinute < 0 {
                refreshMinute += 60
                refreshHour -= 1
                if refreshHour < 0 { refreshHour = 23 }
            }

            // Schedule the refresh
            let now = Date()
            var refreshComponents = calendar.dateComponents([.year, .month, .day], from: now)
            refreshComponents.hour = refreshHour
            refreshComponents.minute = refreshMinute

            if let refreshDate = calendar.date(from: refreshComponents), refreshDate > now {
                let delay = refreshDate.timeIntervalSince(now)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    await refreshNotificationWithSummaryData()
                }
                print("[EveningSummary] Scheduled content refresh for \(refreshHour):\(refreshMinute)")
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
