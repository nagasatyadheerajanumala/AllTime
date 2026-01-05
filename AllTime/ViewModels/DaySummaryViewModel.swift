import Foundation
import SwiftUI
import Combine

@MainActor
class DaySummaryViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var isLoading = true
    @Published var greeting = ""
    @Published var dateString = ""
    @Published var moodEmoji = "..."
    @Published var moodTitle = "Loading..."
    @Published var summaryLine = ""
    @Published var moodGradient: [Color] = [.purple.opacity(0.3), .blue.opacity(0.3)]

    @Published var meetingsCompleted = 0
    @Published var totalMeetings = 0
    @Published var focusTimeUsed = "0h"
    @Published var tasksCompleted = 0

    @Published var completedMeetings: [Event] = []
    @Published var accomplishments: [String] = []

    @Published var tomorrowMeetings = 0
    @Published var tomorrowFirstMeeting: String?
    @Published var closingMessage = ""

    // MARK: - Private Properties

    private let apiService = APIService.shared
    private let calendar = Calendar.current

    // MARK: - Forward-Looking Headlines
    // Philosophy: Clara is not here to congratulate. It's here to prepare you for tomorrow.

    private func generateHeadline(tomorrowMeetingCount: Int, todayWasHeavy: Bool) -> String {
        if tomorrowMeetingCount == 0 {
            return "Tomorrow is open."
        } else if tomorrowMeetingCount >= 6 {
            return "Heavy day ahead."
        } else if todayWasHeavy && tomorrowMeetingCount <= 3 {
            return "Recovery day tomorrow."
        } else if tomorrowMeetingCount >= 4 {
            return "Full day tomorrow."
        } else {
            return "Balanced day ahead."
        }
    }

    private func generateClosingAction(tomorrowMeetingCount: Int, todayWasHeavy: Bool) -> String {
        if todayWasHeavy {
            return "Protect your sleep tonight — tomorrow needs you rested."
        } else if tomorrowMeetingCount >= 5 {
            return "Review tomorrow's meetings now. Identify one you can shorten or skip."
        } else if tomorrowMeetingCount == 0 {
            return "Block focus time for tomorrow before the day fills up."
        } else {
            return "Tomorrow's first meeting: prepare tonight to start strong."
        }
    }

    // MARK: - Load Summary

    func loadSummary(events: [Event]) async {
        isLoading = true

        // Set date info
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        dateString = formatter.string(from: now)

        // Process events
        let todayEvents = events.filter { event in
            guard let startDate = event.startDate else { return false }
            return calendar.isDateInToday(startDate)
        }

        totalMeetings = todayEvents.count

        // Filter completed meetings (end time is before now)
        completedMeetings = todayEvents.filter { event in
            guard let endDate = event.endDate else { return false }
            return endDate <= now
        }.sorted { event1, event2 in
            guard let date1 = event1.startDate, let date2 = event2.startDate else { return false }
            return date1 < date2
        }

        meetingsCompleted = completedMeetings.count

        // Calculate focus time (gaps between meetings)
        focusTimeUsed = calculateFocusTime(events: todayEvents)

        // Determine mood based on day metrics
        determineMood()

        // Generate accomplishments
        generateAccomplishments()

        // Load tomorrow's preview
        await loadTomorrowPreview()

        // Set forward-looking headline and action (not congratulatory)
        let todayWasHeavy = totalMeetings >= 5
        greeting = generateHeadline(tomorrowMeetingCount: tomorrowMeetings, todayWasHeavy: todayWasHeavy)
        closingMessage = generateClosingAction(tomorrowMeetingCount: tomorrowMeetings, todayWasHeavy: todayWasHeavy)

        isLoading = false
    }

    // MARK: - Private Methods

    private func calculateFocusTime(events: [Event]) -> String {
        let workdayStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        let workdayEnd = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()

        // Sort events by start time
        let sortedEvents = events.compactMap { event -> (start: Date, end: Date)? in
            guard let start = event.startDate, let end = event.endDate else { return nil }
            return (start, end)
        }.sorted { $0.start < $1.start }

        var totalFocusMinutes: Int = 0
        var lastEndTime = workdayStart

        for event in sortedEvents {
            if event.start > lastEndTime {
                // Gap found - this is focus time
                let gapMinutes = Int(event.start.timeIntervalSince(lastEndTime) / 60)
                if gapMinutes >= 15 { // Only count gaps of 15+ minutes
                    totalFocusMinutes += gapMinutes
                }
            }
            if event.end > lastEndTime {
                lastEndTime = event.end
            }
        }

        // Add focus time after last meeting until workday end (or now if earlier)
        let effectiveEnd = min(Date(), workdayEnd)
        if lastEndTime < effectiveEnd {
            let remainingMinutes = Int(effectiveEnd.timeIntervalSince(lastEndTime) / 60)
            if remainingMinutes >= 15 {
                totalFocusMinutes += remainingMinutes
            }
        }

        let hours = totalFocusMinutes / 60
        let minutes = totalFocusMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    private func determineMood() {
        // Philosophy: Don't celebrate the past. Frame it in terms of what it means for tomorrow.
        let completionRate = totalMeetings > 0 ? Double(meetingsCompleted) / Double(totalMeetings) : 1.0

        if totalMeetings == 0 {
            moodEmoji = "..."
            moodTitle = "Open Day"
            summaryLine = "No external demands today. Check: did you use it, or did it slip away?"
            moodGradient = [Color.teal.opacity(0.3), Color.blue.opacity(0.3)]
        } else if totalMeetings >= 6 && completionRate >= 0.8 {
            moodEmoji = "..."
            moodTitle = "Heavy Load"
            summaryLine = "\(meetingsCompleted) meetings today. Your capacity is depleted — protect tonight."
            moodGradient = [Color.orange.opacity(0.3), Color.red.opacity(0.3)]
        } else if totalMeetings >= 6 {
            moodEmoji = "..."
            moodTitle = "High Demand"
            summaryLine = "\(totalMeetings) meetings scheduled. This pace isn't sustainable without recovery."
            moodGradient = [Color.purple.opacity(0.3), Color.pink.opacity(0.3)]
        } else if completionRate >= 0.9 {
            moodEmoji = "..."
            moodTitle = "Full Day"
            summaryLine = "All \(meetingsCompleted) meetings completed. Energy spent — plan accordingly."
            moodGradient = [Color.green.opacity(0.3), Color.teal.opacity(0.3)]
        } else if completionRate >= 0.7 {
            moodEmoji = "..."
            moodTitle = "Active Day"
            summaryLine = "\(meetingsCompleted) of \(totalMeetings) meetings done. Check what carried over."
            moodGradient = [Color.blue.opacity(0.3), Color.cyan.opacity(0.3)]
        } else if totalMeetings <= 3 {
            moodEmoji = "..."
            moodTitle = "Light Day"
            summaryLine = "Only \(totalMeetings) meetings. Did you use the space, or did tasks expand?"
            moodGradient = [Color.mint.opacity(0.3), Color.teal.opacity(0.3)]
        } else {
            moodEmoji = "..."
            moodTitle = "Mixed Day"
            summaryLine = "Meetings and gaps. The question: was the gap time intentional?"
            moodGradient = [Color.indigo.opacity(0.3), Color.purple.opacity(0.3)]
        }
    }

    private func generateAccomplishments() {
        accomplishments = []

        if meetingsCompleted > 0 {
            accomplishments.append("Completed \(meetingsCompleted) meeting\(meetingsCompleted == 1 ? "" : "s")")
        }

        if totalMeetings > 0 && meetingsCompleted == totalMeetings {
            accomplishments.append("Attended all scheduled meetings")
        }

        // Check for early meetings
        let earlyMeetings = completedMeetings.filter { event in
            guard let startDate = event.startDate else { return false }
            let hour = calendar.component(.hour, from: startDate)
            return hour < 9
        }
        if earlyMeetings.count > 0 {
            accomplishments.append("Started the day early")
        }

        // Check for long meetings survived
        let longMeetings = completedMeetings.filter { event in
            guard let start = event.startDate, let end = event.endDate else { return false }
            let duration = end.timeIntervalSince(start) / 60
            return duration >= 60
        }
        if longMeetings.count >= 2 {
            accomplishments.append("Powered through \(longMeetings.count) long meetings")
        }

        // Add focus time accomplishment
        if totalMeetings <= 3 {
            accomplishments.append("Maintained focus with minimal context switching")
        }
    }

    private func loadTomorrowPreview() async {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let startOfTomorrow = calendar.startOfDay(for: tomorrow)
        let endOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfTomorrow) ?? tomorrow

        do {
            let response = try await apiService.fetchEvents(
                startDate: startOfTomorrow,
                endDate: endOfTomorrow,
                autoSync: false
            )

            tomorrowMeetings = response.events.count

            // Find first meeting tomorrow
            if let firstEvent = response.events.sorted(by: { event1, event2 in
                guard let date1 = event1.startDate, let date2 = event2.startDate else { return false }
                return date1 < date2
            }).first, let startDate = firstEvent.startDate {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                tomorrowFirstMeeting = formatter.string(from: startDate)
            }
        } catch {
            print("Failed to load tomorrow's events: \(error.localizedDescription)")
            tomorrowMeetings = 0
            tomorrowFirstMeeting = nil
        }
    }
}
