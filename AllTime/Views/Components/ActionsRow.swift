import SwiftUI

// MARK: - Actions Row
/// Compact row showing Suggestions and Todo counts with neutral styling.
/// Replaces the separate colorful tiles with a unified, calm presentation.
struct ActionsRow: View {
    let overview: TodayOverviewResponse?
    let briefing: DailyBriefingResponse?
    let isLoading: Bool
    let onSuggestionsTap: () -> Void
    let onTodoTap: () -> Void

    private var suggestionsCount: Int {
        overview?.suggestionsTile.count ?? briefing?.suggestions?.count ?? 0
    }

    private var topSuggestion: String? {
        overview?.suggestionsTile.previewLine ?? briefing?.suggestions?.first?.title
    }

    private var pendingTasks: Int {
        overview?.todoTile.pendingCount ?? 0
    }

    private var overdueTasks: Int {
        overview?.todoTile.overdueCount ?? 0
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Suggestions Card
            ActionCard(
                icon: "sparkles",
                iconColor: DesignSystem.Colors.amber,
                title: "Actions",
                count: suggestionsCount,
                subtitle: topSuggestion,
                isLoading: isLoading,
                onTap: onSuggestionsTap
            )

            // Todo Card
            ActionCard(
                icon: "checklist",
                iconColor: DesignSystem.Colors.emerald,
                title: "Tasks",
                count: pendingTasks,
                subtitle: overdueTasks > 0 ? "\(overdueTasks) overdue" : nil,
                badgeCount: overdueTasks,
                isLoading: isLoading,
                onTap: onTodoTap
            )
        }
    }
}

// MARK: - Action Card
private struct ActionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let count: Int
    let subtitle: String?
    var badgeCount: Int = 0
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                if isLoading {
                    skeletonContent
                } else {
                    // Header with icon and count
                    HStack {
                        // Icon
                        Image(systemName: icon)
                            .font(.body)
                            .foregroundColor(iconColor.opacity(0.9))

                        Spacer()

                        // Count badge
                        if count > 0 {
                            Text("\(count)")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                        }
                    }

                    // Title
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    // Subtitle or preview
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(badgeCount > 0 ? DesignSystem.Colors.softWarning : DesignSystem.Colors.secondaryText)
                            .lineLimit(1)
                    } else if count == 0 {
                        Text("All clear")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
            }
            .calmCard(padding: DesignSystem.Spacing.md)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var skeletonContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 24, height: 24)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 24, height: 24)
            }

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.08))
                .frame(width: 60, height: 14)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.06))
                .frame(height: 12)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        ActionsRow(
            overview: nil,
            briefing: nil,
            isLoading: true,
            onSuggestionsTap: {},
            onTodoTap: {}
        )

        ActionsRow(
            overview: nil,
            briefing: nil,
            isLoading: false,
            onSuggestionsTap: {},
            onTodoTap: {}
        )
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
