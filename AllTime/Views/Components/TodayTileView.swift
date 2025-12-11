import SwiftUI

// MARK: - Tile Type Enum
enum TodayTileType: String, CaseIterable {
    case summary
    case suggestions
    case todo

    var title: String {
        switch self {
        case .summary: return "Today"
        case .suggestions: return "Suggestions"
        case .todo: return "To-Do"
        }
    }

    var icon: String {
        switch self {
        case .summary: return "sparkles"
        case .suggestions: return "lightbulb.fill"
        case .todo: return "checklist"
        }
    }

    var defaultGradient: LinearGradient {
        switch self {
        case .summary:
            return LinearGradient(
                colors: [Color(hex: "6366F1"), Color(hex: "4F46E5")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .suggestions:
            return LinearGradient(
                colors: [Color(hex: "F59E0B"), Color(hex: "D97706")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .todo:
            return LinearGradient(
                colors: [Color(hex: "10B981"), Color(hex: "059669")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Today Tile View (Weather App Style)
struct TodayTileView<Content: View>: View {
    let type: TodayTileType
    let isLoading: Bool
    let gradient: LinearGradient?
    let onTap: () -> Void
    @ViewBuilder let content: () -> Content

    init(
        type: TodayTileType,
        isLoading: Bool = false,
        gradient: LinearGradient? = nil,
        onTap: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.type = type
        self.isLoading = isLoading
        self.gradient = gradient
        self.onTap = onTap
        self.content = content
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Header with icon and title
                HStack(spacing: 6) {
                    Image(systemName: type.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.9))

                    Text(type.title.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.0)
                        .lineLimit(1)
                        .foregroundColor(.white.opacity(0.9))

                    Spacer(minLength: 4)

                    // Chevron indicator
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer(minLength: 4)

                // Content area
                if isLoading {
                    // Loading shimmer
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        ShimmerView()
                            .frame(height: 16)
                            .frame(maxWidth: .infinity)
                        ShimmerView()
                            .frame(height: 12)
                            .frame(width: 100)
                    }
                } else {
                    content()
                }
            }
            .padding(DesignSystem.Today.cardPadding)
            .frame(minHeight: DesignSystem.Today.tileMinHeight)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Today.tileCornerRadius)
                    .fill(gradient ?? type.defaultGradient)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(TileButtonStyle())
    }
}

// MARK: - Tile Button Style (Subtle press effect)
struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Shimmer View (Loading state)
struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white.opacity(0.2))
            .overlay(
                GeometryReader { geometry in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    .white.opacity(0.4),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 0.5)
                        .offset(x: -geometry.size.width * 0.5 + phase * geometry.size.width * 2)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Summary Tile Content
struct SummaryTileContent: View {
    let data: SummaryTileData

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Mood label with emoji
            HStack(spacing: 6) {
                if let emoji = data.moodEmoji {
                    Text(emoji)
                        .font(.title3)
                }
                Text(data.moodLabel)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            // Preview line
            if let preview = data.previewLine {
                Text(preview)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            // Stats row
            HStack(spacing: DesignSystem.Spacing.md) {
                if let meetings = data.meetingsLabel {
                    StatPill(icon: "calendar", text: meetings)
                }
                if let focus = data.focusTimeAvailable, focus != "No focus time" {
                    StatPill(icon: "brain.head.profile", text: focus)
                }
            }
        }
    }
}

// MARK: - Suggestions Tile Content
struct SuggestionsTileContent: View {
    let data: SuggestionsTileData

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Main preview line
            if let preview = data.previewLine {
                Text(preview)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            // Top suggestions preview
            if let suggestions = data.topSuggestions?.prefix(2), !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(suggestions), id: \.previewId) { suggestion in
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: suggestion.displayIcon)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))

                            Text(suggestion.title ?? "")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)

                            Spacer(minLength: 4)

                            if let time = suggestion.timeLabel {
                                Text(time)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
            }

            // Count badge
            if let count = data.count, count > 0 {
                HStack {
                    Spacer()
                    Text("\(count) suggestion\(count == 1 ? "" : "s")")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
}

// MARK: - Todo Tile Content
struct TodoTileContent: View {
    let data: TodoTileData

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Main preview line
            if let preview = data.previewLine {
                Text(preview)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            // Top tasks preview
            if let tasks = data.topTasks?.prefix(2), !tasks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(tasks), id: \.taskId) { task in
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: task.isOverdue == true ? "exclamationmark.circle.fill" : "circle")
                                .font(.caption2)
                                .foregroundColor(task.isOverdue == true ? Color(hex: "FEF2F2") : .white.opacity(0.7))

                            Text(task.title ?? "")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)

                            Spacer(minLength: 4)

                            if let time = task.timeLabel {
                                Text(time)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
            }

            // Stats row
            HStack(spacing: DesignSystem.Spacing.md) {
                if let pending = data.pendingCount, pending > 0 {
                    Text("\(pending) pending")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                if let overdue = data.overdueCount, overdue > 0 {
                    Text("\(overdue) overdue")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(Color(hex: "FEF2F2"))
                }
                if let completed = data.completedTodayCount, completed > 0 {
                    Text("\(completed) done")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            }
        }
    }
}

// MARK: - Stat Pill (small indicator)
struct StatPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption.weight(.medium))
        }
        .foregroundColor(.white.opacity(0.85))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.15))
        )
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 16) {
            TodayTileView(
                type: .summary,
                gradient: LinearGradient(
                    colors: [Color(hex: "6366F1"), Color(hex: "4F46E5")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                onTap: {}
            ) {
                SummaryTileContent(data: SummaryTileData(
                    greeting: "Good morning!",
                    previewLine: "4 meetings today, 2h focus time available",
                    mood: "balanced",
                    moodEmoji: "⚖️",
                    meetingsCount: 4,
                    meetingsLabel: "4 meetings",
                    focusTimeAvailable: "2h",
                    healthScore: 75,
                    healthLabel: "Good"
                ))
            }

            TodayTileView(type: .suggestions, onTap: {}) {
                SuggestionsTileContent(data: SuggestionsTileData(
                    previewLine: "Deep Work Block",
                    count: 5,
                    topSuggestions: [
                        SuggestionPreviewData(id: "1", title: "Deep Work Block", timeLabel: "9:00 AM", icon: "brain.head.profile", category: "focus"),
                        SuggestionPreviewData(id: "2", title: "Lunch Break", timeLabel: "12:30 PM", icon: "fork.knife", category: "nutrition")
                    ]
                ))
            }

            TodayTileView(type: .todo, onTap: {}) {
                TodoTileContent(data: TodoTileData(
                    previewLine: "Review PR comments",
                    pendingCount: 3,
                    overdueCount: 1,
                    completedTodayCount: 2,
                    topTasks: [
                        TaskPreviewData(id: 1, title: "Review PR comments", timeLabel: "Morning", priority: "HIGH", isOverdue: false),
                        TaskPreviewData(id: 2, title: "Send weekly report", timeLabel: "4:00 PM", priority: "MEDIUM", isOverdue: false)
                    ]
                ))
            }

            // Loading state
            TodayTileView(type: .summary, isLoading: true, onTap: {}) {
                EmptyView()
            }
        }
        .padding()
    }
    .background(DesignSystem.Colors.background)
}
