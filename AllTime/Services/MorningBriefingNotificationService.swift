import Foundation
import UserNotifications
import Combine

/// Service for managing morning briefing notifications
/// Schedules a daily notification with a preview of the user's day
@MainActor
class MorningBriefingNotificationService: ObservableObject {
    static let shared = MorningBriefingNotificationService()

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
        static let enabled = "morning_briefing_enabled"
        static let time = "morning_briefing_time"
    }

    private let notificationIdentifier = "morning-briefing"

    // MARK: - Creative Notification Content
    // Goal: Sound like a witty friend who gets your work life, not a boring app

    /// Generate an engaging, contextual title based on briefing data
    private func getEngagingTitle(from briefing: DailyBriefingResponse?) -> String {
        let firstName = UserDefaults.standard.string(forKey: "user_first_name")
        let name = firstName ?? ""
        let hasName = !name.isEmpty

        let weekday = Calendar.current.component(.weekday, from: Date())
        let hour = Calendar.current.component(.hour, from: Date())
        let isMonday = weekday == 2
        let isFriday = weekday == 6
        let isWeekend = weekday == 1 || weekday == 7

        guard let briefing = briefing else {
            return getPersonalizedTitle()
        }

        let meetings = briefing.keyMetrics?.effectiveMeetingsCount ?? 0
        // Estimate meeting minutes (assume 45 min avg meeting)
        let totalMeetingMinutes = meetings * 45

        // Weekend work detection
        if isWeekend && meetings > 0 {
            return hasName ? "\(name), working on a weekend?" : "Working on the weekend? Respect."
        }

        // Very early morning (before 6am)
        if hour < 6 {
            return hasName ? "\(name), you're up before the sun" : "You're up before the sun ☀️"
        }

        // Monday morning dread/motivation
        if isMonday {
            if meetings >= 6 {
                return hasName ? "\(name), Monday chose violence" : "Monday chose violence today"
            }
            if meetings == 0 {
                return hasName ? "A Monday without meetings, \(name)? Unicorn day." : "Monday without meetings? Is this real?"
            }
            if hour < 9 {
                return hasName ? "\(name), deep breath. It's Monday." : "Deep breath. It's just Monday."
            }
            return hasName ? "Let's get this Monday, \(name)" : "Let's get this Monday"
        }

        // Friday vibes
        if isFriday {
            if meetings >= 5 {
                return hasName ? "\(name), who scheduled 5 meetings on Friday?" : "5 meetings on a Friday? Who did this?"
            }
            if meetings == 0 {
                return hasName ? "Zero meetings Friday, \(name). Chef's kiss." : "Zero meetings Friday. Perfection."
            }
            if hour >= 14 {
                return hasName ? "Home stretch, \(name) 🏁" : "Home stretch to the weekend 🏁"
            }
            return hasName ? "Happy Friday, \(name)! Almost there." : "Happy Friday! The end is near."
        }

        // Sleep deprivation awareness
        if let metrics = briefing.keyMetrics, let sleepLast = metrics.sleepHoursLastNight {
            if sleepLast < 5 {
                return hasName ? "\(name), running on \(String(format: "%.0f", sleepLast))h sleep? Brave." : "Running on fumes today"
            }
            if sleepLast < 6 {
                return hasName ? "Rough night, \(name)? I see you." : "Rough night? Today's about survival."
            }
        }

        // Meeting chaos levels
        if meetings == 0 {
            return [
                hasName ? "\(name), your calendar is suspiciously empty" : "Your calendar is suspiciously empty",
                hasName ? "No meetings, \(name). What's the catch?" : "No meetings. What's the catch?",
                hasName ? "\(name), zero meetings. Use this power wisely." : "Zero meetings. A rare gift."
            ].randomElement()!
        }

        if meetings >= 8 {
            return [
                hasName ? "\(name), 8 meetings? That's not a day, it's a marathon." : "8 meetings? That's not work, it's endurance.",
                hasName ? "I'm sorry, \(name). 8 meetings." : "I counted. It's 8 meetings. I'm sorry.",
                hasName ? "\(name), your calendar needs an intervention" : "Your calendar needs an intervention"
            ].randomElement()!
        }

        if meetings >= 6 {
            let meetingHours = totalMeetingMinutes / 60
            return [
                hasName ? "\(name), \(meetings) meetings today. Pace yourself." : "\(meetings) meetings. \(meetingHours)h of talking. Godspeed.",
                hasName ? "Heavy day ahead, \(name). \(meetings) meetings." : "Heavy day: \(meetings) meetings on deck",
                hasName ? "\(name), today's a talker — \(meetings) meetings" : "\(meetings) meetings. Your voice will need rest."
            ].randomElement()!
        }

        // Mid-range meetings with personality
        if meetings >= 4 {
            return [
                hasName ? "\(name), \(meetings) meetings — not light, not brutal" : "\(meetings) meetings — survivable but busy",
                hasName ? "Moderate chaos today, \(name). \(meetings) meetings." : "Moderate chaos: \(meetings) meetings",
                hasName ? "\(name), \(meetings) meetings. Find your gaps." : "\(meetings) meetings. Guard your gaps."
            ].randomElement()!
        }

        // Light days
        if meetings <= 2 {
            return [
                hasName ? "\(name), light day — just \(meetings) meeting\(meetings == 1 ? "" : "s")" : "Light day: \(meetings) meeting\(meetings == 1 ? "" : "s"). Breathe.",
                hasName ? "Breathing room today, \(name)" : "Breathing room in your schedule",
                hasName ? "\(name), \(meetings) meeting\(meetings == 1 ? "" : "s"). The rest is yours." : "\(meetings) meeting\(meetings == 1 ? "" : "s"). Freedom awaits."
            ].randomElement()!
        }

        // Default
        return hasName ? "Here's your day, \(name)" : "Here's what's ahead"
    }

    /// Simple personalized title without briefing data
    private func getPersonalizedTitle() -> String {
        let firstName = UserDefaults.standard.string(forKey: "user_first_name")
        let weekday = Calendar.current.component(.weekday, from: Date())
        let hour = Calendar.current.component(.hour, from: Date())

        let hasName = firstName != nil && !firstName!.isEmpty
        let name = firstName ?? ""

        // Time-aware greetings
        if hour < 6 {
            return hasName ? "\(name), you're up early" : "Early riser detected"
        }

        // Day-specific
        switch weekday {
        case 2: // Monday
            return hasName ? "Monday, \(name). Let's go." : "Monday. Deep breath. Let's go."
        case 6: // Friday
            return hasName ? "It's Friday, \(name) 🎉" : "TGIF 🎉"
        case 7, 1: // Weekend
            return hasName ? "Weekend mode, \(name)" : "Weekend warrior mode"
        default:
            return hasName ? "Morning, \(name)" : "Good morning"
        }
    }

    /// Generate personalized fallback messages with personality
    private func getPersonalizedFallbackMessage() -> String {
        let firstName = UserDefaults.standard.string(forKey: "user_first_name")
        let weekday = Calendar.current.component(.weekday, from: Date())
        let hour = Calendar.current.component(.hour, from: Date())

        let hasName = firstName != nil && !firstName!.isEmpty
        let name = firstName ?? ""

        // Super early (before 6am)
        if hour < 6 {
            return hasName
                ? "\(name), you're up before most alarms. Respect."
                : "Up before dawn? Your ambition is showing."
        }

        // Monday
        if weekday == 2 {
            return [
                hasName ? "\(name), coffee first. Strategy second." : "Coffee first. Everything else second.",
                hasName ? "New week energy, \(name). Channel it." : "New week, clean slate. What matters today?",
                hasName ? "\(name), Monday is just Friday's origin story." : "Monday: Friday's origin story."
            ].randomElement()!
        }

        // Friday
        if weekday == 6 {
            return [
                hasName ? "\(name), you can see the weekend from here." : "Weekend's in sight. Push through.",
                hasName ? "Finish line's close, \(name)." : "Almost there. One more day.",
                hasName ? "\(name), make Friday count, then log off." : "Make it count, then log off."
            ].randomElement()!
        }

        // Mid-week
        return [
            hasName ? "\(name), your day awaits. Make it count." : "Your day awaits.",
            hasName ? "What's the one thing today, \(name)?" : "What's your ONE thing today?",
            hasName ? "\(name), you've got this." : "You've got this."
        ].randomElement()!
    }

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

        // Fetch preferences from backend on init (backend handles push notifications)
        // Cancel any legacy local notifications
        cancelNotification()

        Task { @MainActor in
            await self.fetchPreferencesFromBackend()
        }
    }

    // MARK: - Public Methods

    /// Schedule the morning briefing notification
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
        print("Morning briefing configured for \(timeString) - backend will send push notification")
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
        let firstName = UserDefaults.standard.string(forKey: "user_first_name")
        let weekday = Calendar.current.component(.weekday, from: Date())

        // Creative test bodies based on day
        let testBodies: [String]
        if weekday == 2 { // Monday
            testBodies = [
                "5 meetings today. Your 2h focus block at 2pm is gold — protect it.",
                "Monday loaded: 4 meetings, but you've got a 90min window at 10am. Use it wisely.",
                "Back-to-back from 9-12, then freedom. Front-load your energy."
            ]
        } else if weekday == 6 { // Friday
            testBodies = [
                "Light Friday: 2 meetings, then coast. Perfect for wrapping up loose ends.",
                "3 meetings, done by 3pm. Weekend mode loading...",
                "Friday focus: 1 meeting at 10am, rest is yours. Finish strong."
            ]
        } else {
            testBodies = [
                "4 meetings leave you 3h of focus time. Your 2pm block is prime real estate.",
                "Heavy morning (3 meetings), light afternoon. Save your hardest task for 2pm.",
                "Only 2 meetings today. Rare gift — tackle that thing you've been avoiding."
            ]
        }

        let content = UNMutableNotificationContent()
        content.title = getPersonalizedTitle()
        content.body = testBodies.randomElement()!
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
        let meetings = briefing.keyMetrics?.effectiveMeetingsCount ?? 0
        // Estimate meeting minutes (assume 45 min avg meeting)
        let totalMeetingMinutes = meetings * 45
        let weekday = Calendar.current.component(.weekday, from: Date())

        // Extract key metrics for compelling numbers
        let metrics = briefing.keyMetrics
        let sleepLast = metrics?.sleepHoursLastNight
        let sleepAvg = metrics?.sleepHoursAverage
        let meetingsAvg = metrics?.meetingsAverageCount
        let longestFreeBlock = metrics?.effectiveLongestFreeBlock ?? 0

        // NEW: Extract specific meeting details for personal notifications
        let firstMeetingTitle = metrics?.firstMeetingTitle
        let firstMeetingTime = metrics?.firstMeetingTime
        let lastMeetingTime = metrics?.lastMeetingTime
        let longestMeetingTitle = metrics?.longestMeetingTitle
        let longestMeetingDuration = metrics?.longestMeetingDurationMinutes
        let backToBackMeetings = metrics?.backToBackMeetings
        let daySpan = metrics?.daySpan

        // Check for late meetings and back-to-back meetings
        let hasLateMeeting = briefing.focusWindows?.contains { window in
            if let hour = Int(window.startTime.prefix(2)), hour >= 18 {
                return true
            }
            return false
        } ?? false

        let hasBackToBack = meetings >= 3 && longestFreeBlock < 30

        // PRIORITY 0: Specific meeting details (most personal)
        if let firstTitle = firstMeetingTitle, let firstTime = firstMeetingTime, meetings > 0 {
            // Personal notification with specific meeting info
            if meetings == 1 {
                return "One meeting today: \(firstTitle) at \(firstTime). Rest of the day is yours."
            }
            if meetings >= 6, let lastTime = lastMeetingTime {
                return "Heavy day: \(meetings) meetings from \(firstTime) to \(lastTime). First up: \(firstTitle)."
            }
            if let backToBack = backToBackMeetings, !backToBack.isEmpty {
                return "Back-to-back alert: \(backToBack). Starts at \(firstTime)."
            }
            if let longest = longestMeetingTitle, let dur = longestMeetingDuration, dur >= 60 {
                let hours = dur / 60
                let mins = dur % 60
                let durStr = mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
                return "Your longest today: \(longest) (\(durStr)). Day starts with \(firstTitle) at \(firstTime)."
            }
            return "First up: \(firstTitle) at \(firstTime). \(meetings - 1) more meetings after."
        }

        // PRIORITY 1: Energy pattern-based insight (personalized data)
        if let patternInsight = patternService.morningInsight(
            meetingCount: meetings,
            hasLateMeeting: hasLateMeeting,
            hasBackToBack: hasBackToBack
        ) {
            return patternInsight
        }

        // PRIORITY 2: AI-generated narrative headline (if good)
        if let narrative = briefing.dayNarrative, !narrative.headline.isEmpty, narrative.headline.count < 100 {
            return narrative.headline
        }

        // PRIORITY 2: Sleep with comparison numbers
        if let sleep = sleepLast {
            if sleep < 5 {
                if let avg = sleepAvg {
                    let deficit = avg - sleep
                    return "\(String(format: "%.0f", sleep))h sleep — \(String(format: "%.1f", deficit))h below your average. Go easy today."
                }
                return "\(String(format: "%.0f", sleep))h sleep. Your brain is at 60% capacity. Plan accordingly."
            }
            if sleep < 6 {
                if let avg = sleepAvg, avg > sleep + 0.5 {
                    return "\(String(format: "%.1f", sleep))h vs your usual \(String(format: "%.1f", avg))h. Skip ambitious decisions today."
                }
                return "\(String(format: "%.1f", sleep))h sleep. Front-load easy tasks, save hard thinking for tomorrow."
            }
            // Great sleep highlight
            if sleep >= 8, let avg = sleepAvg, sleep > avg + 0.5 {
                return "\(String(format: "%.1f", sleep))h sleep — \(String(format: "%.1f", sleep - avg))h more than usual. Peak performance day."
            }
        }

        // PRIORITY 3: Meeting load with comparisons
        if meetings >= 8 {
            if let avg = meetingsAvg {
                let diff = Double(meetings) - avg
                if diff > 2 {
                    return "\(meetings) meetings — \(Int(diff)) more than your average (\(String(format: "%.0f", avg))). Brutal day ahead."
                }
            }
            return "\(meetings) meetings = ~\(totalMeetingMinutes/60)h of talking. Block 15min for yourself somewhere."
        }

        if meetings >= 6 {
            let freeMinutes = max(0, (8 * 60) - totalMeetingMinutes)
            if let avg = meetingsAvg, Double(meetings) > avg + 1.5 {
                return "\(meetings) meetings (avg: \(String(format: "%.0f", avg))). Only \(freeMinutes)min free. Triage ruthlessly."
            }
            return "\(meetings) meetings, \(freeMinutes)min of free time. Your lunch break is non-negotiable."
        }

        // PRIORITY 4: Zero meetings with opportunity framing
        if meetings == 0 {
            if longestFreeBlock >= 240 {
                return "0 meetings + \(longestFreeBlock/60)h uninterrupted. When did you last have this? Use it."
            }
            if let avg = meetingsAvg, avg >= 3 {
                return "0 meetings vs your usual \(String(format: "%.0f", avg)). Rare gift. What's the ONE thing?"
            }
            if weekday == 2 {
                return "Zero Monday meetings. That's not luck, that's strategy (or everyone forgot you)."
            }
            return "Meeting-free day. Your calendar gave you a gift. Don't waste it on email."
        }

        // PRIORITY 5: Focus windows with specific times
        if let focusWindows = briefing.focusWindows,
           let longest = focusWindows.max(by: { $0.durationMinutes < $1.durationMinutes }) {
            let duration = longest.durationMinutes
            let startTime = formatTimeString(longest.startTime)

            if duration >= 180 {
                if meetings >= 3 {
                    return "\(duration/60)h focus block at \(startTime) despite \(meetings) meetings. That's your power window."
                }
                return "\(duration/60)-hour block starting \(startTime). Perfect for that thing you keep postponing."
            }

            if duration >= 90 && meetings >= 4 {
                return "\(meetings) meetings but you have \(duration)min at \(startTime). Protect it like treasure."
            }

            if duration >= 60 && duration < 90 && meetings >= 5 {
                return "Only \(duration)min of focus time today (\(startTime)). Make every minute count."
            }
        }

        // PRIORITY 6: Well-rested + light calendar with numbers
        if let sleep = sleepLast, sleep >= 7.5, meetings <= 2 {
            if let avg = sleepAvg, sleep > avg {
                return "\(String(format: "%.0f", sleep))h sleep (above avg) + only \(meetings) meetings. Peak conditions."
            }
            return "\(String(format: "%.0f", sleep))h sleep, \(meetings) meetings. Your brain is ready for hard problems."
        }

        // PRIORITY 7: Meeting comparison insights
        if let avg = meetingsAvg {
            if meetings == 1 && avg >= 3 {
                return "Just 1 meeting vs your usual \(String(format: "%.0f", avg)). Rare quiet day. Make it count."
            }
            if Double(meetings) <= avg - 2 && meetings <= 3 {
                return "\(meetings) meetings — \(Int(avg - Double(meetings))) fewer than average. Deep work opportunity."
            }
            if Double(meetings) >= avg + 2 {
                return "\(meetings) meetings — \(Int(Double(meetings) - avg)) more than your average. Pace yourself."
            }
        }

        // PRIORITY 8: Moderate days with context
        if meetings >= 2 && meetings <= 4 {
            if longestFreeBlock >= 90 {
                return "\(meetings) meetings + \(longestFreeBlock)min focus block. Balanced day. Use both."
            }
            return "\(meetings) meetings today. Manageable. What's your ONE priority?"
        }

        // PRIORITY 9: Primary recommendation
        if let rec = briefing.primaryRecommendation {
            if let consequence = rec.ignoredConsequence, !consequence.isEmpty, consequence.count < 50 {
                return "\(rec.action) — or \(consequence.lowercased())"
            }
            return rec.action
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

    // MARK: - Backend Sync

    /// Sync notification preferences to backend
    /// Backend handles all push notification delivery
    private func syncPreferencesToBackend() async {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: scheduledTime)

        do {
            try await APIService.shared.updateNotificationPreferences(
                morningBriefingEnabled: isEnabled,
                morningBriefingHour: hour
            )
            print("✅ Morning briefing preferences synced to backend: enabled=\(isEnabled), hour=\(hour)")
        } catch {
            print("❌ Failed to sync morning briefing preferences: \(error.localizedDescription)")
        }
    }

    /// Fetch preferences from backend on app launch
    func fetchPreferencesFromBackend() async {
        do {
            if let prefs = try await APIService.shared.getNotificationPreferences() {
                await MainActor.run {
                    // Update local state from backend
                    if let enabled = prefs.morningBriefingEnabled {
                        // Don't trigger didSet sync loop
                        UserDefaults.standard.set(enabled, forKey: Keys.enabled)
                        self.isEnabled = enabled
                    }
                    if let hour = prefs.morningBriefingHour {
                        var components = DateComponents()
                        components.hour = hour
                        components.minute = 0
                        if let time = Calendar.current.date(from: components) {
                            UserDefaults.standard.set(time, forKey: Keys.time)
                            self.scheduledTime = time
                        }
                    }
                }
                print("✅ Fetched morning briefing preferences from backend")
            }
        } catch {
            print("⚠️ Could not fetch notification preferences from backend: \(error.localizedDescription)")
        }
    }
}
