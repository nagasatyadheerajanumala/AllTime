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
    /// Uses engaging, curiosity-inducing titles that make users want to tap
    private func getPersonalizedTitle() -> String {
        let firstName = UserDefaults.standard.string(forKey: "user_first_name")

        if let name = firstName, !name.isEmpty {
            // Engaging titles that create curiosity and encourage tapping
            let personalizedOptions = [
                "\(name), see what you accomplished",
                "Your day decoded, \(name)",
                "\(name)'s wins today",
                "\(name), you might be surprised...",
                "Look what you did today, \(name)",
                "\(name), your day in numbers",
                "Guess what, \(name)?",
                "\(name), check this out"
            ]
            return personalizedOptions.randomElement() ?? "\(name), see what you accomplished"
        } else {
            // Generic engaging titles
            let genericOptions = [
                "See what you accomplished",
                "Your day decoded",
                "Today's wins inside",
                "You might be surprised...",
                "Look what you did today",
                "Your day in numbers",
                "Check this out"
            ]
            return genericOptions.randomElement() ?? "See what you accomplished"
        }
    }

    /// Generate an engaging title based on day tone (used when we have insights data)
    /// This creates context-aware titles that are even more compelling
    private func getEngagingTitle(dayTone: String?, eventCount: Int?, stepsGoalMet: Bool?) -> String {
        let firstName = UserDefaults.standard.string(forKey: "user_first_name")
        let name = firstName ?? ""
        let hasName = !name.isEmpty

        // Achievement-based titles when goals are met
        if stepsGoalMet == true {
            if hasName {
                return [
                    "\(name), you crushed your goals!",
                    "Way to go, \(name)!",
                    "\(name), look at those numbers!"
                ].randomElement()!
            } else {
                return ["You crushed your goals!", "Way to go!", "Look at those numbers!"].randomElement()!
            }
        }

        // Tone-based engaging titles
        if let tone = dayTone?.lowercased() {
            switch tone {
            case "intense", "busy":
                if hasName {
                    return [
                        "\(name), you survived!",
                        "What a day, \(name)!",
                        "\(name), you earned this break"
                    ].randomElement()!
                } else {
                    return ["You survived!", "What a day!", "You earned this break"].randomElement()!
                }

            case "productive":
                if hasName {
                    return [
                        "\(name), productive much?",
                        "On fire today, \(name)!",
                        "\(name), boss moves only"
                    ].randomElement()!
                } else {
                    return ["Productive much?", "On fire today!", "Boss moves only"].randomElement()!
                }

            case "calm", "relaxed":
                if hasName {
                    return [
                        "Chill day, \(name)?",
                        "\(name), easy does it",
                        "Nice pace today, \(name)"
                    ].randomElement()!
                } else {
                    return ["Chill day?", "Easy does it", "Nice pace today"].randomElement()!
                }

            case "balanced":
                if hasName {
                    return [
                        "Perfect balance, \(name)",
                        "\(name), nailed the mix",
                        "Harmony achieved, \(name)"
                    ].randomElement()!
                } else {
                    return ["Perfect balance", "Nailed the mix", "Harmony achieved"].randomElement()!
                }

            default:
                break
            }
        }

        // Event-count based titles
        if let events = eventCount {
            if events >= 6 {
                if hasName {
                    return ["\(name), marathon day!", "Busy bee, \(name)!", "\(name), what a hustle"].randomElement()!
                } else {
                    return ["Marathon day!", "Busy bee!", "What a hustle"].randomElement()!
                }
            } else if events <= 2 {
                if hasName {
                    return ["\(name), breathing room!", "Space to think, \(name)", "\(name), light and easy"].randomElement()!
                } else {
                    return ["Breathing room!", "Space to think", "Light and easy"].randomElement()!
                }
            }
        }

        // Default to generic engaging title
        return getPersonalizedTitle()
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
    /// Uses summary-style messages, not questions/questionnaires
    /// Note: For repeating notifications, we use day-agnostic messages since content is
    /// set at schedule time, not fire time. Day-specific content is set via refreshNotificationWithSummaryData.
    private func getPersonalizedFallbackMessage() -> String {
        let firstName = UserDefaults.standard.string(forKey: "user_first_name")

        // Use day-agnostic summary-style messages for repeating notifications
        if let name = firstName, !name.isEmpty {
            let personalizedMessages = [
                "\(name), here's how your day went.",
                "Your day wrapped up, \(name). See the highlights.",
                "\(name), your daily summary is ready.",
                "Day done! Tap to see your summary, \(name)."
            ]
            return personalizedMessages.randomElement() ?? "Your daily summary is ready, \(name)."
        }

        // Generic summary-style fallback (not questions)
        let genericMessages = [
            "Here's how your day went.",
            "Your daily summary is ready.",
            "Day complete. See your highlights.",
            "Tap to see today's summary."
        ]
        return genericMessages.randomElement() ?? "Your daily summary is ready."
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

    /// Send a test notification immediately with mock data (for debugging/preview)
    func sendTestNotification() {
        // Create mock activities for testing
        let mockActivities: [ActivityStatus] = [
            ActivityStatus(
                activityId: "1",
                title: "Team standup meeting",
                category: "work",
                plannedTime: "09:00",
                location: nil,
                isCompleted: true,
                matchedEventTitle: nil
            ),
            ActivityStatus(
                activityId: "2",
                title: "Project review with stakeholders",
                category: "work",
                plannedTime: "14:00",
                location: "Conference Room A",
                isCompleted: true,
                matchedEventTitle: nil
            ),
            ActivityStatus(
                activityId: "3",
                title: "Code review session",
                category: "work",
                plannedTime: "16:00",
                location: nil,
                isCompleted: true,
                matchedEventTitle: nil
            ),
            ActivityStatus(
                activityId: "4",
                title: "1:1 with manager",
                category: "work",
                plannedTime: "17:00",
                location: nil,
                isCompleted: false,
                matchedEventTitle: nil
            )
        ]

        // Generate summary body with mock data
        let body = generateEnhancedSummaryBody(
            summaryMessage: "",  // Empty to test fallback generation
            meetingsCompleted: 3,
            totalMeetings: 4,
            completionPercentage: 75,
            activities: mockActivities
        )

        let content = UNMutableNotificationContent()
        content.title = getPersonalizedTitle()
        content.body = body
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
                print("Test evening summary notification sent with body: \(body)")
            }
        }
    }

    /// Fetch today's summary data and update notification content
    /// Call this before the scheduled notification time (e.g., 30 min before)
    func refreshNotificationWithSummaryData() async {
        guard isEnabled else { return }

        do {
            // Try to fetch comprehensive daily insights first (better summary)
            let dailyInsights = try await DayReviewService.shared.getDailyInsightsSummary(date: Date())

            // Use context-aware engaging title based on day data
            let title = getEngagingTitle(
                dayTone: dailyInsights.dayTone,
                eventCount: dailyInsights.eventStats?.totalEvents,
                stepsGoalMet: dailyInsights.health?.stepsGoalMet
            )
            let body = dailyInsights.shortSummary

            // Update the scheduled notification with fresh content
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.userInfo = [
                "type": "evening_summary",
                "destination": "day-review",
                "day_tone": dailyInsights.dayTone
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
                    print("[EveningSummary] Failed to update notification: \(error.localizedDescription)")
                } else {
                    print("[EveningSummary] Notification updated with daily insights: \(body)")
                }
            }

            // Save to notification history with event stats if available
            let meetingsCompleted = dailyInsights.eventStats?.meetings ?? 0
            let totalMeetings = dailyInsights.eventStats?.totalEvents ?? 0
            let completionPercentage = 0 // Not applicable for insights summary

            historyService.addEveningSummary(
                title: title,
                body: body,
                meetingsCompleted: meetingsCompleted,
                totalMeetings: totalMeetings,
                completionPercentage: completionPercentage
            )

            print("[EveningSummary] Updated notification with daily insights: \(dailyInsights.dayTone) day")
        } catch {
            print("[EveningSummary] Daily insights failed, trying day review: \(error.localizedDescription)")

            // Fallback to day review endpoint
            do {
                let review = try await DayReviewService.shared.getDayReview(date: Date())

                let meetingsCompleted = review.totalCompleted
                let totalMeetings = review.totalPlanned
                let completionPercentage = review.completionPercentage

                let title = getPersonalizedTitle()
                let body = generateEnhancedSummaryBody(
                    summaryMessage: review.summaryMessage,
                    meetingsCompleted: meetingsCompleted,
                    totalMeetings: totalMeetings,
                    completionPercentage: completionPercentage,
                    activities: review.activities
                )

                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                content.userInfo = [
                    "type": "evening_summary",
                    "destination": "day-review"
                ]

                let calendar = Calendar.current
                var dateComponents = calendar.dateComponents([.hour, .minute], from: scheduledTime)
                dateComponents.second = 0

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

                let request = UNNotificationRequest(
                    identifier: notificationIdentifier,
                    content: content,
                    trigger: trigger
                )

                UNUserNotificationCenter.current().removePendingNotificationRequests(
                    withIdentifiers: [notificationIdentifier]
                )

                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("[EveningSummary] Failed to update notification: \(error.localizedDescription)")
                    } else {
                        print("[EveningSummary] Notification updated with day review")
                    }
                }

                historyService.addEveningSummary(
                    title: title,
                    body: body,
                    meetingsCompleted: meetingsCompleted,
                    totalMeetings: totalMeetings,
                    completionPercentage: completionPercentage
                )
            } catch {
                print("[EveningSummary] Failed to fetch any summary data: \(error.localizedDescription)")
                // Keep fallback notification content
            }
        }
    }

    /// Generate an enhanced summary body using API data and activity information
    private func generateEnhancedSummaryBody(
        summaryMessage: String,
        meetingsCompleted: Int,
        totalMeetings: Int,
        completionPercentage: Int,
        activities: [ActivityStatus]
    ) -> String {
        // If we have a good summary message from the API, use it
        if !summaryMessage.isEmpty && summaryMessage.count < 120 {
            return summaryMessage
        }

        // Build a summary based on activities
        let completedActivities = activities.filter { $0.isCompleted }
        let firstName = UserDefaults.standard.string(forKey: "user_first_name")
        let name = firstName ?? ""

        // No activities case
        if totalMeetings == 0 {
            if !name.isEmpty {
                return "\(name), you had a free day today. Time to relax and reflect!"
            }
            return "You had a free day today. Time to relax and reflect!"
        }

        // Build activity summary
        var summary = ""

        // High completion rate
        if completionPercentage >= 80 {
            if !name.isEmpty {
                summary = "Great job, \(name)! You completed \(meetingsCompleted) of \(totalMeetings) activities today (\(completionPercentage)%)."
            } else {
                summary = "Great job! You completed \(meetingsCompleted) of \(totalMeetings) activities today (\(completionPercentage)%)."
            }
        } else if completionPercentage >= 50 {
            summary = "You completed \(meetingsCompleted) of \(totalMeetings) activities today. Tap to reflect on your day."
        } else if totalMeetings >= 5 {
            summary = "Busy day with \(totalMeetings) activities! You got through \(meetingsCompleted). Time to unwind."
        } else {
            summary = "You had \(totalMeetings) activities today and completed \(meetingsCompleted). How did your day feel?"
        }

        // Add top completed activity if available
        if let topActivity = completedActivities.first {
            let shortTitle = topActivity.title.prefix(30)
            if shortTitle.count < topActivity.title.count {
                summary += " Including \"\(shortTitle)...\"."
            } else if summary.count + topActivity.title.count < 140 {
                summary += " Including \"\(topActivity.title)\"."
            }
        }

        return summary
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
