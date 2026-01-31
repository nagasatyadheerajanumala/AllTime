import SwiftUI

// MARK: - Clara Insight Card
/// Visual callout card for Clara's key insights
struct ClaraInsightCard: View {
    let insight: ResponseInsight

    var severityColor: Color {
        switch insight.severity {
        case "critical":
            return DesignSystem.Colors.errorRed
        case "warning":
            return DesignSystem.Colors.amber
        case "positive":
            return DesignSystem.Colors.emerald
        default:
            return DesignSystem.Colors.blue
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon with colored background
            Image(systemName: insight.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(severityColor)
                .frame(width: 36, height: 36)
                .background(severityColor.opacity(0.15))
                .clipShape(Circle())

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Text(insight.detail)
                    .font(.system(size: 13))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            Spacer()
        }
        .padding(12)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(severityColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Clara Metrics Row
/// Quick horizontal display of key metrics
struct ClaraMetricsRow: View {
    let metrics: ContextMetrics

    var body: some View {
        HStack(spacing: 0) {
            // Meetings metric
            if let count = metrics.meetingCount, count > 0 {
                ClaraMetricPill(
                    icon: "calendar",
                    value: "\(count)",
                    label: "meetings"
                )
            }

            // Meeting time metric
            if let minutes = metrics.totalMeetingMinutes, minutes > 0 {
                ClaraMetricPill(
                    icon: "clock",
                    value: formatMinutes(minutes),
                    label: "in meetings"
                )
            }

            // Free time metric
            if let free = metrics.freeMinutes, free > 0 {
                ClaraMetricPill(
                    icon: "target",
                    value: formatMinutes(free),
                    label: "free"
                )
            }

            // Sleep metric (if available)
            if let sleep = metrics.sleepHours, sleep > 0 {
                ClaraMetricPill(
                    icon: "moon.zzz",
                    value: String(format: "%.1fh", sleep),
                    label: "sleep"
                )
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h\(mins)m"
    }
}

// MARK: - Clara Metric Pill
/// Individual metric display in the Clara metrics row
struct ClaraMetricPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(DesignSystem.Colors.violet)

            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews
#Preview("Insight Card - Critical") {
    VStack(spacing: 12) {
        ClaraInsightCard(insight: ResponseInsight(
            type: "meeting_load",
            title: "Heavy Meeting Day",
            detail: "7 meetings, 4h 45min total",
            severity: "critical",
            icon: "calendar.badge.exclamationmark"
        ))

        ClaraInsightCard(insight: ResponseInsight(
            type: "focus_time",
            title: "Limited Focus Time",
            detail: "Longest gap: 45 minutes",
            severity: "warning",
            icon: "target"
        ))

        ClaraInsightCard(insight: ResponseInsight(
            type: "opportunity",
            title: "Ideal for Deep Work",
            detail: "Well-rested with 3h focus block",
            severity: "positive",
            icon: "brain.head.profile"
        ))
    }
    .padding()
    .background(DesignSystem.Colors.background)
}

#Preview("Metrics Row") {
    ClaraMetricsRow(metrics: ContextMetrics(
        meetingCount: 7,
        totalMeetingMinutes: 285,
        freeMinutes: 315,
        longestFocusBlockMinutes: 45,
        sleepHours: 6.8,
        sleepStatus: "slightly_under",
        steps: 8500,
        capacityPercent: 75
    ))
    .padding()
    .background(DesignSystem.Colors.background)
}
