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
    private let patternService = EnergyPatternInsightService.shared

    // MARK: - Published Properties

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            // Sync preference to backend - backend handles all push notifications
            Task {
                await syncPreferencesToBackend()
            }
        }
    }

    @Published var scheduledTime: Date {
        didSet {
            UserDefaults.standard.set(scheduledTime, forKey: Keys.time)
            // Sync time to backend - backend handles all push notifications
            Task {
                await syncPreferencesToBackend()
            }
        }
    }

    // MARK: - Constants

    private enum Keys {
        static let enabled = "evening_summary_enabled"
        static let time = "evening_summary_time"
    }

    private let notificationIdentifier = "evening-summary"

    // MARK: - Creative Notification Content
    // Goal: Celebrate wins, acknowledge struggles, be genuinely helpful — not corporate

    /// Generate a personalized, witty evening title
    private func getPersonalizedTitle() -> String {
        let firstName = UserDefaults.standard.string(forKey: "user_first_name")
        let weekday = Calendar.current.component(.weekday, from: Date())
        let hour = Calendar.current.component(.hour, from: Date())

        let hasName = firstName != nil && !firstName!.isEmpty
        let name = firstName ?? ""

        // Friday evening — celebrate
        if weekday == 6 {
            return hasName
                ? ["\(name), you survived another week", "TGIF, \(name). You made it.", "\(name), weekend loading..."].randomElement()!
                : ["Another week survived", "TGIF. You made it.", "Weekend loading..."].randomElement()!
        }

        // Thursday — almost there
        if weekday == 5 {
            return hasName
                ? ["\(name), one more day", "Thursday done, \(name). Almost there.", "\(name), Friday's tomorrow 👀"].randomElement()!
                : ["One more day", "Almost there", "Friday's tomorrow 👀"].randomElement()!
        }

        // Monday evening — you did it
        if weekday == 2 {
            return hasName
                ? ["\(name), Monday: defeated", "You beat Monday, \(name)", "\(name) 1, Monday 0"].randomElement()!
                : ["Monday: defeated", "You beat Monday", "Monday down, 4 to go"].randomElement()!
        }

        // Late evening (after 9pm)
        if hour >= 21 {
            return hasName
                ? ["\(name), log off already", "Still working, \(name)? Day's over.", "\(name), your couch misses you"].randomElement()!
                : ["Log off already", "Day's done. Close the laptop.", "Your couch is calling"].randomElement()!
        }

        // Default
        return hasName
            ? ["Day done, \(name)", "\(name), that's a wrap", "How'd today go, \(name)?"].randomElement()!
            : ["That's a wrap", "Day complete", "How'd today go?"].randomElement()!
    }

    /// Generate an engaging title based on actual day data
    private func getEngagingTitle(dayTone: String?, eventCount: Int?, stepsGoalMet: Bool?) -> String {
        let firstName = UserDefaults.standard.string(forKey: "user_first_name")
        let weekday = Calendar.current.component(.weekday, from: Date())
        let hasName = firstName != nil && !firstName!.isEmpty
        let name = firstName ?? ""

        // Achievement: Steps goal
        if stepsGoalMet == true {
            return hasName
                ? ["\(name), 10K steps! Your future knees thank you.", "Step goal crushed, \(name) 🏆", "\(name)'s legs did the work today"].randomElement()!
                : ["10K steps! Your future knees thank you.", "Step goal crushed 🏆", "Your legs did work today"].randomElement()!
        }

        // Tone-based celebrations/commiserations
        if let tone = dayTone?.lowercased() {
            switch tone {
            case "intense", "busy":
                return hasName
                    ? ["\(name), you survived. That's the win.", "Brutal day done, \(name). Breathe.", "\(name), today was A LOT"].randomElement()!
                    : ["You survived. That's the win.", "Brutal day done. Breathe.", "Today was A LOT"].randomElement()!

            case "productive":
                return hasName
                    ? ["\(name) was in the zone today", "Productive \(name) is scary productive", "\(name), you actually got stuff done"].randomElement()!
                    : ["You were in the zone", "Scary productive today", "Stuff actually got done"].randomElement()!

            case "calm", "relaxed":
                return hasName
                    ? ["\(name), that was a chill one", "Low-key day, \(name). Nice change?", "\(name) took it easy. As one should."].randomElement()!
                    : ["That was a chill one", "Low-key day. Nice change?", "Easy day. As it should be."].randomElement()!

            case "balanced":
                return hasName
                    ? ["\(name), you found the sweet spot today", "Balance achieved, \(name). Rare.", "\(name), meetings AND focus time? Sorcery."].randomElement()!
                    : ["Sweet spot achieved", "Balance is rare. You found it.", "Meetings AND focus time? Witchcraft."].randomElement()!

            default:
                break
            }
        }

        // Event-count based observations
        if let events = eventCount {
            if events >= 8 {
                return hasName
                    ? ["\(name), \(events) events. How are you still standing?", "\(events) events survived, \(name). Medal incoming.", "\(name), \(events) events is not normal. Rest."].randomElement()!
                    : ["\(events) events. How are you standing?", "\(events) events survived. Legend.", "\(events) events is NOT normal"].randomElement()!
            }

            if events >= 6 {
                return hasName
                    ? ["\(name), heavy day done", "\(events) events behind you, \(name)", "\(name), your voice needs a break"].randomElement()!
                    : ["Heavy day done", "\(events) events in the books", "Your voice needs a break"].randomElement()!
            }

            if events == 0 {
                return hasName
                    ? ["\(name), how was the meeting detox?", "Zero meetings, \(name). How'd you spend it?", "\(name) had peace and quiet today"].randomElement()!
                    : ["How was the meeting detox?", "Zero meetings. Rare W.", "Peace and quiet achieved"].randomElement()!
            }

            if events <= 2 {
                return hasName
                    ? ["\(name), light day. Hope you used it.", "Minimal meetings, \(name). Productive?", "\(name) had breathing room today"].randomElement()!
                    : ["Light day. Hope you used it.", "Minimal meetings. Productive?", "Breathing room achieved"].randomElement()!
            }
        }

        // Day-specific
        if weekday == 6 {
            return hasName
                ? ["\(name) made it to Friday night", "Week DONE, \(name) 🎉", "\(name), you earned this weekend"].randomElement()!
                : ["Made it to Friday night", "Week DONE 🎉", "Weekend earned"].randomElement()!
        }

        if weekday == 2 {
            return hasName
                ? ["Monday defeated, \(name)", "\(name) beat Monday. 4 to go.", "Monday's done, \(name). Onward."].randomElement()!
                : ["Monday defeated", "Monday down. 4 to go.", "Monday done. Onward."].randomElement()!
        }

        return getPersonalizedTitle()
    }

    /// Generate personalized fallback messages
    private func getPersonalizedFallbackMessage() -> String {
        let firstName = UserDefaults.standard.string(forKey: "user_first_name")
        let weekday = Calendar.current.component(.weekday, from: Date())
        let hour = Calendar.current.component(.hour, from: Date())

        let hasName = firstName != nil && !firstName!.isEmpty
        let name = firstName ?? ""

        // Late night
        if hour >= 21 {
            return hasName
                ? ["\(name), stop working. Recap's ready.", "Day's over, \(name). Here's the summary.", "\(name), close the laptop. Reflect tomorrow."].randomElement()!
                : ["Stop working. Recap's ready.", "Day's over. Here's the summary.", "Close the laptop."].randomElement()!
        }

        // Friday
        if weekday == 6 {
            return hasName
                ? ["\(name), another week survived. See the stats.", "Week done, \(name). How'd you do?", "\(name), Friday recap ready. Then relax."].randomElement()!
                : ["Another week survived.", "Week done. How'd you do?", "Friday recap ready."].randomElement()!
        }

        // Monday
        if weekday == 2 {
            return hasName
                ? ["\(name), Monday's over. You made it.", "First day done, \(name). 4 more to go.", "\(name), Monday defeated. See the proof."].randomElement()!
                : ["Monday's over. You made it.", "First day done. 4 more to go.", "Monday defeated."].randomElement()!
        }

        // Generic
        return hasName
            ? ["\(name), your day decoded. Tap to see.", "Day done, \(name). Here's how it went.", "\(name), time to reflect. Or not. Your call."].randomElement()!
            : ["Your day decoded.", "Here's how today went.", "Time to reflect."].randomElement()!
    }

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

        // Fetch preferences from backend on init (backend handles push notifications)
        // Cancel any legacy local notifications
        cancelNotification()

        Task { @MainActor in
            await self.fetchPreferencesFromBackend()
        }
    }

    // MARK: - Public Methods

    /// Schedule the evening summary notification
    /// NOTE: Local scheduling removed - backend handles all push notifications
    /// This method now just syncs preferences to backend
    func scheduleNotification() {
        guard isEnabled else { return }

        // Cancel any existing LOCAL notification (we use backend push now)
        cancelNotification()

        // Sync to backend - backend will send push notification at the scheduled time
        Task {
            await syncPreferencesToBackend()
        }

        let timeString = formattedTime(scheduledTime)
        print("Evening summary configured for \(timeString) - backend will send push notification")
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

    /// Generate an enhanced summary body with compelling numbers
    private func generateEnhancedSummaryBody(
        summaryMessage: String,
        meetingsCompleted: Int,
        totalMeetings: Int,
        completionPercentage: Int,
        activities: [ActivityStatus],
        hadLateMeeting: Bool = false,
        hadBackToBack: Bool = false
    ) -> String {
        // PRIORITY 0: Energy pattern-based insight for recovery advice
        if let patternInsight = patternService.eveningInsight(
            meetingCount: totalMeetings,
            hadLateMeeting: hadLateMeeting,
            hadBackToBack: hadBackToBack
        ) {
            return patternInsight
        }

        // If we have a good summary message from the API, use it
        if !summaryMessage.isEmpty && summaryMessage.count < 120 {
            return summaryMessage
        }

        let weekday = Calendar.current.component(.weekday, from: Date())
        let completedActivities = activities.filter { $0.isCompleted }

        // Calculate meeting hours (estimate 45min avg)
        let meetingHours = (totalMeetings * 45) / 60
        let meetingMinutes = (totalMeetings * 45) % 60

        // Zero activities
        if totalMeetings == 0 {
            if weekday == 6 {
                return "Zero meetings on Friday. You spent 0h in calls today. That's the dream."
            }
            return "No meetings today = 8h of potential focus time. How'd you spend it?"
        }

        // Chaos day (8+ meetings)
        if totalMeetings >= 8 {
            return "\(totalMeetings) meetings = \(meetingHours)h \(meetingMinutes)min of your day in calls. Your voice needs a vacation."
        }

        // Heavy day (6-7 meetings)
        if totalMeetings >= 6 {
            let focusMinutes = max(0, 480 - (totalMeetings * 45))
            return "\(totalMeetings) meetings (\(meetingHours)h+) done. You had ~\(focusMinutes)min of free time today. Respect."
        }

        // Perfect execution with specific activity mention
        if completionPercentage == 100 && totalMeetings >= 3 {
            if let topActivity = completedActivities.first {
                let shortTitle = String(topActivity.title.prefix(25))
                return "\(totalMeetings)/\(totalMeetings) done including \"\(shortTitle)\". 100% follow-through today."
            }
            return "\(totalMeetings)/\(totalMeetings) complete. 100% execution rate. Screenshot-worthy day."
        }

        // High completion with numbers
        if completionPercentage >= 80 {
            let incompleteCount = totalMeetings - meetingsCompleted
            if incompleteCount == 1 {
                return "\(meetingsCompleted)/\(totalMeetings) done (\(completionPercentage)%). Just 1 thing slipped. Solid day."
            }
            if totalMeetings >= 5 {
                return "\(completionPercentage)% completion on a \(totalMeetings)-activity day. Above average execution."
            }
            return "\(meetingsCompleted) of \(totalMeetings) done. \(completionPercentage)% completion rate today."
        }

        // Medium completion
        if completionPercentage >= 50 {
            let remaining = totalMeetings - meetingsCompleted
            return "\(meetingsCompleted)/\(totalMeetings) activities done. \(remaining) rolled to tomorrow. Progress over perfection."
        }

        // Lower completion with context
        if completionPercentage >= 25 {
            return "\(meetingsCompleted) of \(totalMeetings) planned activities done (\(completionPercentage)%). Some days are like that."
        }

        // Very low - empathetic
        if totalMeetings >= 3 {
            return "Planned \(totalMeetings), completed \(meetingsCompleted). Life had other plans. Tomorrow's fresh."
        }

        // Light day
        return "\(meetingsCompleted)/\(totalMeetings) activities. Light day, \(completionPercentage)% done."
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
        // Check for pattern-based insight first
        if let patternInsight = patternService.eveningInsight(
            meetingCount: totalMeetings,
            hadLateMeeting: false,  // Could be enhanced with actual data
            hadBackToBack: totalMeetings >= 4
        ) {
            return patternInsight
        }

        // Calculate specific numbers
        let meetingHours = (totalMeetings * 45) / 60
        let meetingMinutes = (totalMeetings * 45) % 60
        let freeMinutes = max(0, 480 - (totalMeetings * 45))

        // Heavy meeting day (6+)
        if totalMeetings >= 6 {
            return [
                "\(totalMeetings) meetings = \(meetingHours)h \(meetingMinutes)min in calls. Only \(freeMinutes)min was yours.",
                "\(totalMeetings) meetings done. That's \(meetingHours)+ hours of talking today.",
                "You survived \(totalMeetings) meetings (~\(meetingHours)h). Your evening is earned."
            ].randomElement()!
        }

        // Light day (0-2 meetings)
        if totalMeetings <= 2 {
            if totalMeetings == 0 {
                return [
                    "0 meetings = 8h of potential deep work today. How'd it go?",
                    "Zero meetings. You had 480 uninterrupted minutes. Rare.",
                    "Meeting-free day. That's ~\(freeMinutes)min of focus time you controlled."
                ].randomElement()!
            }
            return [
                "Only \(totalMeetings) meeting\(totalMeetings == 1 ? "" : "s") = ~\(freeMinutes)min of free time today.",
                "\(totalMeetings) meeting\(totalMeetings == 1 ? "" : "s"), \(freeMinutes)min of focus time. Light day done.",
                "Just \(totalMeetings) meeting\(totalMeetings == 1 ? "" : "s"). Most of your 8h was yours."
            ].randomElement()!
        }

        // Moderate day (3-5 meetings)
        if let focusTime = focusTimeUsed, !focusTime.isEmpty {
            return [
                "\(meetingsCompleted) meetings + \(focusTime) focus time. ~\(freeMinutes)min was yours today.",
                "\(meetingsCompleted) meetings (\(meetingHours)h) + \(focusTime) deep work. Balanced day.",
                "Meetings: \(meetingsCompleted) (\(meetingHours)h). Focus: \(focusTime). Good split."
            ].randomElement()!
        }

        return [
            "\(meetingsCompleted) meetings (\(meetingHours)h \(meetingMinutes)min). \(freeMinutes)min of free time today.",
            "\(meetingsCompleted) of \(totalMeetings) meetings done. ~\(freeMinutes)min was yours.",
            "Day done: \(meetingsCompleted) meetings, \(freeMinutes)min of breathing room."
        ].randomElement()!
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

    // MARK: - Backend Sync

    /// Sync notification preferences to backend
    /// Backend handles all push notification delivery
    private func syncPreferencesToBackend() async {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: scheduledTime)

        do {
            try await APIService.shared.updateNotificationPreferences(
                eveningSummaryEnabled: isEnabled,
                eveningSummaryHour: hour
            )
            print("✅ Evening summary preferences synced to backend: enabled=\(isEnabled), hour=\(hour)")
        } catch {
            print("❌ Failed to sync evening summary preferences: \(error.localizedDescription)")
        }
    }

    /// Fetch preferences from backend on app launch
    func fetchPreferencesFromBackend() async {
        do {
            if let prefs = try await APIService.shared.getNotificationPreferences() {
                await MainActor.run {
                    // Update local state from backend
                    if let enabled = prefs.eveningSummaryEnabled {
                        // Don't trigger didSet sync loop
                        UserDefaults.standard.set(enabled, forKey: Keys.enabled)
                        self.isEnabled = enabled
                    }
                    if let hour = prefs.eveningSummaryHour {
                        var components = DateComponents()
                        components.hour = hour
                        components.minute = 0
                        if let time = Calendar.current.date(from: components) {
                            UserDefaults.standard.set(time, forKey: Keys.time)
                            self.scheduledTime = time
                        }
                    }
                }
                print("✅ Fetched evening summary preferences from backend")
            }
        } catch {
            print("⚠️ Could not fetch notification preferences from backend: \(error.localizedDescription)")
        }
    }
}
