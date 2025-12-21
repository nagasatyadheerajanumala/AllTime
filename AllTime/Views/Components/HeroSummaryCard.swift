import SwiftUI

// MARK: - Hero Summary Card
/// Single, calm hero card replacing multiple tiles on Today screen.
/// Shows day tone, summary, and key stats in a unified, premium presentation.
struct HeroSummaryCard: View {
    let overview: TodayOverviewResponse?
    let briefing: DailyBriefingResponse?
    let isLoading: Bool
    let onTap: () -> Void

    private var greeting: String {
        overview?.summaryTile.greeting ?? briefing?.greeting ?? "Good day"
    }

    private var summaryLine: String {
        overview?.summaryTile.previewLine ?? briefing?.summaryLine ?? ""
    }

    private var moodLabel: String {
        let mood = overview?.summaryTile.mood ?? briefing?.mood ?? "balanced"
        return formatMoodLabel(mood)
    }

    private var meetingsCount: Int {
        overview?.summaryTile.meetingsCount ?? briefing?.quickStats?.meetingsCount ?? 0
    }

    private var focusTime: String {
        overview?.summaryTile.focusTimeAvailable ?? briefing?.quickStats?.focusTimeAvailable ?? ""
    }

    private var energyLabel: String {
        briefing?.quickStats?.energyForecast ?? briefing?.quickStats?.healthLabel ?? ""
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                if isLoading && overview == nil && briefing == nil {
                    // Skeleton loading
                    skeletonContent
                } else {
                    // Header: Greeting + Day Tone
                    headerSection

                    // Summary line from Clara
                    if !summaryLine.isEmpty {
                        Text(summaryLine)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: DesignSystem.Spacing.sm)

                    // Stats chips row
                    statsRow
                }
            }
            .heroCard()
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)

                // Day tone badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(moodColor)
                        .frame(width: 8, height: 8)
                    Text(moodLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            Spacer()

            // Chevron indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
    }

    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Meetings
            if meetingsCount > 0 {
                StatChip(
                    icon: "calendar",
                    value: "\(meetingsCount)",
                    label: meetingsCount == 1 ? "meeting" : "meetings"
                )
            }

            // Focus time
            if !focusTime.isEmpty {
                StatChip(
                    icon: "brain.head.profile",
                    value: focusTime,
                    label: "focus"
                )
            }

            // Energy/Health
            if !energyLabel.isEmpty {
                StatChip(
                    icon: "bolt.fill",
                    value: energyLabel,
                    label: ""
                )
            }

            Spacer()
        }
    }

    // MARK: - Skeleton
    private var skeletonContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Title skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.1))
                .frame(width: 180, height: 24)

            // Badge skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.08))
                .frame(width: 100, height: 16)

            Spacer(minLength: DesignSystem.Spacing.sm)

            // Summary skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.06))
                .frame(height: 16)

            // Stats skeleton
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 80, height: 32)
                }
            }
        }
        .frame(minHeight: 120)
    }

    // MARK: - Helpers
    private var moodColor: Color {
        let mood = overview?.summaryTile.mood ?? briefing?.mood ?? "balanced"
        switch mood.lowercased() {
        case "focus_day", "focused": return Color(hex: "3B82F6")
        case "light_day", "light": return Color(hex: "10B981")
        case "intense_meetings", "intense", "busy": return Color(hex: "F59E0B")
        case "rest_day", "rest": return Color(hex: "8B5CF6")
        default: return Color(hex: "6B7280")
        }
    }

    private func formatMoodLabel(_ mood: String) -> String {
        switch mood.lowercased() {
        case "focus_day", "focused": return "Focus day"
        case "light_day", "light": return "Light day"
        case "intense_meetings", "intense", "busy": return "Busy day"
        case "rest_day", "rest": return "Rest day"
        case "balanced": return "Balanced day"
        default: return "Your day"
        }
    }
}

// MARK: - Stat Chip
private struct StatChip: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)

            if !label.isEmpty {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.1))
        )
    }
}

// MARK: - Preview
#Preview {
    VStack {
        HeroSummaryCard(
            overview: nil,
            briefing: nil,
            isLoading: true,
            onTap: {}
        )

        HeroSummaryCard(
            overview: nil,
            briefing: nil,
            isLoading: false,
            onTap: {}
        )
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
