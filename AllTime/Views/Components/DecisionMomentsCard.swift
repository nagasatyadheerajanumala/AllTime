import SwiftUI

// MARK: - Decision Moment Model

/// Represents a decision point that needs user attention
struct DecisionMoment: Identifiable {
    let id = UUID()
    let type: DecisionType
    let title: String
    let subtitle: String
    let urgency: Urgency
    let primaryAction: DecisionAction
    let secondaryAction: DecisionAction?
    let expiresAt: Date?

    enum DecisionType: String {
        case freeTime = "free_time"
        case taskAvoidance = "task_avoidance"
        case meetingOverload = "meeting_overload"
        case focusOpportunity = "focus_opportunity"
        case protectTime = "protect_time"
        case weekPlanning = "week_planning"
    }

    enum Urgency {
        case high    // Red accent, expires soon
        case medium  // Orange accent
        case low     // Blue accent, informational

        var color: Color {
            switch self {
            case .high: return DesignSystem.Colors.errorRed
            case .medium: return DesignSystem.Colors.amber
            case .low: return DesignSystem.Colors.blue
            }
        }

        var icon: String {
            switch self {
            case .high: return "exclamationmark.circle.fill"
            case .medium: return "clock.fill"
            case .low: return "lightbulb.fill"
            }
        }
    }

    struct DecisionAction {
        let label: String
        let icon: String
        let action: () -> Void
    }
}

// MARK: - Decision Moments Card

/// Shows active decision points that need user attention
/// Transforms Today from passive status to active decision engine
struct DecisionMomentsCard: View {
    @EnvironmentObject var calendarViewModel: CalendarViewModel
    @State private var decisions: [DecisionMoment] = []
    @State private var dismissedIds: Set<UUID> = []

    var body: some View {
        let activeDecisions = decisions.filter { !dismissedIds.contains($0.id) }

        if !activeDecisions.isEmpty {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Header
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.amber.opacity(0.15))
                            .frame(width: 28, height: 28)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.amber)
                    }

                    Text("Decisions")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Spacer()

                    Text("\(activeDecisions.count)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(DesignSystem.Colors.amber))
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.top, DesignSystem.Spacing.md)

                // Decision Cards
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(activeDecisions.prefix(2)) { decision in
                        DecisionMomentRow(
                            decision: decision,
                            onDismiss: { dismissedIds.insert(decision.id) }
                        )
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.md)
            }
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                            .stroke(DesignSystem.Colors.amber.opacity(0.2), lineWidth: 1)
                    )
            )
            .onAppear {
                generateDecisions()
            }
        }
    }

    // MARK: - Decision Generation

    private func generateDecisions() {
        var newDecisions: [DecisionMoment] = []
        let now = Date()
        let calendar = Calendar.current

        // Get today's and tomorrow's events
        let todayEvents = calendarViewModel.eventsForToday()
        let tomorrowEvents = calendarViewModel.eventsForDate(calendar.date(byAdding: .day, value: 1, to: now) ?? now)

        // 1. Check for rare free day tomorrow
        let tomorrowMeetings = tomorrowEvents.filter { isMeeting($0) }
        let avgDailyMeetings = getAverageDailyMeetings()

        if Double(tomorrowMeetings.count) < avgDailyMeetings * 0.3 && avgDailyMeetings > 2 {
            newDecisions.append(DecisionMoment(
                type: .freeTime,
                title: "Tomorrow is unusually light",
                subtitle: "Only \(tomorrowMeetings.count) meetings vs your \(Int(avgDailyMeetings)) avg. Protect it now.",
                urgency: .high,
                primaryAction: DecisionMoment.DecisionAction(
                    label: "Block focus time",
                    icon: "shield.fill",
                    action: { NavigationManager.shared.handleDestination("alltime://calendar?action=block") }
                ),
                secondaryAction: DecisionMoment.DecisionAction(
                    label: "Dismiss",
                    icon: "xmark",
                    action: {}
                ),
                expiresAt: calendar.date(byAdding: .hour, value: 12, to: now)
            ))
        }

        // 2. Check for meeting-heavy today
        let todayMeetings = todayEvents.filter { isMeeting($0) }
        if todayMeetings.count >= 5 {
            // Find gaps
            let gaps = findFocusGaps(in: todayEvents)
            if let bestGap = gaps.first {
                newDecisions.append(DecisionMoment(
                    type: .focusOpportunity,
                    title: "Your only focus window today",
                    subtitle: "\(bestGap.duration) minutes free at \(bestGap.startTime). This is it.",
                    urgency: .medium,
                    primaryAction: DecisionMoment.DecisionAction(
                        label: "Protect this slot",
                        icon: "lock.fill",
                        action: { NavigationManager.shared.handleDestination("alltime://calendar") }
                    ),
                    secondaryAction: nil,
                    expiresAt: bestGap.expiresAt
                ))
            }
        }

        // 3. Check for current free time being wasted
        if currentEvent(in: todayEvents) == nil && !todayMeetings.isEmpty {
            let nextMeeting = todayMeetings.first { ($0.startDate ?? now) > now }
            if let next = nextMeeting, let nextStart = next.startDate {
                let minutesUntilNext = calendar.dateComponents([.minute], from: now, to: nextStart).minute ?? 0
                if minutesUntilNext >= 30 && minutesUntilNext <= 90 {
                    newDecisions.append(DecisionMoment(
                        type: .protectTime,
                        title: "\(minutesUntilNext) minutes before next meeting",
                        subtitle: "Use it or lose it. What's your highest-value task right now?",
                        urgency: .medium,
                        primaryAction: DecisionMoment.DecisionAction(
                            label: "View tasks",
                            icon: "checklist",
                            action: { NavigationManager.shared.handleDestination("alltime://reminders") }
                        ),
                        secondaryAction: nil,
                        expiresAt: nextStart
                    ))
                }
            }
        }

        // 4. Sunday evening - week planning prompt
        if calendar.component(.weekday, from: now) == 1 { // Sunday
            let hour = calendar.component(.hour, from: now)
            if hour >= 17 && hour <= 21 {
                newDecisions.append(DecisionMoment(
                    type: .weekPlanning,
                    title: "Your week starts tomorrow",
                    subtitle: "5 minutes now saves hours of reactive scrambling.",
                    urgency: .low,
                    primaryAction: DecisionMoment.DecisionAction(
                        label: "Plan my week",
                        icon: "calendar.badge.plus",
                        action: { NavigationManager.shared.handleDestination("alltime://insights?tab=weekly") }
                    ),
                    secondaryAction: nil,
                    expiresAt: nil
                ))
            }
        }

        decisions = newDecisions
    }

    // MARK: - Helpers

    private func isMeeting(_ event: Event) -> Bool {
        let title = event.title.lowercased()
        return title.contains("meeting") ||
               title.contains("call") ||
               title.contains("sync") ||
               title.contains("1:1") ||
               title.contains("standup") ||
               (event.attendees?.count ?? 0) > 0
    }

    private func getAverageDailyMeetings() -> Double {
        // Simple heuristic: assume 4 meetings per day average
        // In a real implementation, this would query historical data
        return 4.0
    }

    private func currentEvent(in events: [Event]) -> Event? {
        let now = Date()
        return events.first { event in
            guard let start = event.startDate, let end = event.endDate else { return false }
            return now >= start && now <= end
        }
    }

    private func findFocusGaps(in events: [Event]) -> [FocusGap] {
        var gaps: [FocusGap] = []
        let now = Date()
        let calendar = Calendar.current

        // Filter to meetings only and sort by start time
        let meetings = events.filter { isMeeting($0) && ($0.startDate ?? now) > now }
            .sorted { ($0.startDate ?? now) < ($1.startDate ?? now) }

        guard !meetings.isEmpty else { return [] }

        // Check gap before first meeting
        if let firstStart = meetings.first?.startDate {
            let minutesBefore = calendar.dateComponents([.minute], from: now, to: firstStart).minute ?? 0
            if minutesBefore >= 30 {
                gaps.append(FocusGap(
                    startTime: formatTime(now),
                    duration: minutesBefore,
                    expiresAt: firstStart
                ))
            }
        }

        // Check gaps between meetings
        for i in 0..<(meetings.count - 1) {
            guard let end = meetings[i].endDate, let nextStart = meetings[i + 1].startDate else { continue }
            let gapMinutes = calendar.dateComponents([.minute], from: end, to: nextStart).minute ?? 0
            if gapMinutes >= 30 {
                gaps.append(FocusGap(
                    startTime: formatTime(end),
                    duration: gapMinutes,
                    expiresAt: nextStart
                ))
            }
        }

        return gaps.sorted { $0.duration > $1.duration }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    struct FocusGap {
        let startTime: String
        let duration: Int
        let expiresAt: Date
    }
}

// MARK: - Decision Moment Row

struct DecisionMomentRow: View {
    let decision: DecisionMoment
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Title row with urgency indicator
            HStack(spacing: 8) {
                Image(systemName: decision.urgency.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(decision.urgency.color)

                Text(decision.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(1)

                Spacer()

                // Dismiss button
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .padding(6)
                        .background(Circle().fill(DesignSystem.Colors.cardBackground))
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Subtitle
            Text(decision.subtitle)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            // Action buttons
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Primary action
                Button(action: {
                    HapticManager.shared.mediumTap()
                    decision.primaryAction.action()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: decision.primaryAction.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(decision.primaryAction.label)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(decision.urgency.color)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // Secondary action (if exists)
                if let secondary = decision.secondaryAction {
                    Button(action: {
                        HapticManager.shared.lightTap()
                        secondary.action()
                        onDismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: secondary.icon)
                                .font(.system(size: 10, weight: .medium))
                            Text(secondary.label)
                                .font(.caption.weight(.medium))
                        }
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(DesignSystem.Colors.cardBackground)
                                .overlay(
                                    Capsule().stroke(DesignSystem.Colors.calmBorder, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer()

                // Expiry indicator
                if let expires = decision.expiresAt {
                    let timeLeft = expires.timeIntervalSince(Date())
                    if timeLeft > 0 && timeLeft < 3600 * 4 { // Show if < 4 hours
                        Text(formatTimeLeft(timeLeft))
                            .font(.caption2.weight(.medium))
                            .foregroundColor(decision.urgency.color.opacity(0.8))
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(decision.urgency.color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .stroke(decision.urgency.color.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    private func formatTimeLeft(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes)m left"
        } else {
            let hours = minutes / 60
            return "\(hours)h left"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        DecisionMomentsCard()
            .environmentObject(CalendarViewModel())
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
