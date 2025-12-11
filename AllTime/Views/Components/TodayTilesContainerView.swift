import SwiftUI

// MARK: - Today Tiles Container View
/// Container view that displays the 3 Weather-app style tiles
/// and manages sheet presentations for detail views
struct TodayTilesContainerView: View {
    let overview: TodayOverviewResponse?
    let briefing: DailyBriefingResponse?
    let isLoading: Bool

    @State private var showingSummaryDetail = false
    @State private var showingSuggestionsDetail = false
    @State private var showingTodoDetail = false

    var body: some View {
        VStack(spacing: DesignSystem.Today.tileSpacing) {
            // Summary Tile (Today AI Summary) - Full width
            TodayTileView(
                type: .summary,
                isLoading: isLoading,
                gradient: overview?.summaryTile.moodGradient ?? briefing?.moodGradient,
                onTap: { showingSummaryDetail = true }
            ) {
                if let summary = overview?.summaryTile {
                    SummaryTileContent(data: summary)
                } else if let briefing = briefing {
                    // Fallback to briefing data if overview not available
                    SummaryTileContent(data: SummaryTileData(
                        greeting: briefing.greeting,
                        previewLine: briefing.summaryLine,
                        mood: briefing.mood,
                        moodEmoji: getMoodEmoji(briefing.mood),
                        meetingsCount: briefing.quickStats?.meetingsCount,
                        meetingsLabel: briefing.quickStats?.meetingsLabel,
                        focusTimeAvailable: briefing.quickStats?.focusTimeAvailable,
                        healthScore: briefing.quickStats?.healthScore,
                        healthLabel: briefing.quickStats?.healthLabel
                    ))
                } else {
                    EmptyTileContent(message: "Tap to view today's summary")
                }
            }

            // Two tiles side by side with equal sizing
            HStack(spacing: DesignSystem.Today.tileSpacing) {
                // Suggestions Tile
                TodayTileView(
                    type: .suggestions,
                    isLoading: isLoading,
                    onTap: { showingSuggestionsDetail = true }
                ) {
                    if let suggestions = overview?.suggestionsTile {
                        SuggestionsTileContent(data: suggestions)
                    } else if let briefing = briefing, let suggestions = briefing.suggestions {
                        SuggestionsTileContent(data: SuggestionsTileData(
                            previewLine: suggestions.first?.title,
                            count: suggestions.count,
                            topSuggestions: suggestions.prefix(2).map { s in
                                SuggestionPreviewData(
                                    id: s.id,
                                    title: s.title,
                                    timeLabel: s.effectiveTimeLabel,
                                    icon: s.displayIcon,
                                    category: s.category
                                )
                            }
                        ))
                    } else {
                        EmptyTileContent(message: "No suggestions")
                    }
                }
                .frame(maxWidth: .infinity)

                // Todo Tile
                TodayTileView(
                    type: .todo,
                    isLoading: isLoading,
                    onTap: { showingTodoDetail = true }
                ) {
                    if let todo = overview?.todoTile {
                        TodoTileContent(data: todo)
                    } else {
                        EmptyTileContent(message: "No tasks")
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showingSummaryDetail) {
            TodaySummaryDetailView(
                briefing: briefing,
                summaryTile: overview?.summaryTile
            )
        }
        .sheet(isPresented: $showingSuggestionsDetail) {
            SuggestionsDetailView(
                briefing: briefing,
                suggestionsTile: overview?.suggestionsTile
            )
        }
        .sheet(isPresented: $showingTodoDetail) {
            ToDoDetailView(
                todoTile: overview?.todoTile
            )
        }
    }

    private func getMoodEmoji(_ mood: String) -> String {
        switch mood.lowercased() {
        case "focus_day": return "🎯"
        case "light_day": return "☀️"
        case "intense_meetings": return "📅"
        case "rest_day": return "😴"
        case "balanced": return "⚖️"
        default: return "📊"
        }
    }
}

// MARK: - Empty Tile Content
struct EmptyTileContent: View {
    let message: String

    var body: some View {
        VStack {
            Spacer()
            Text(message)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
        }
    }
}

// MARK: - Today Summary Detail View
struct TodaySummaryDetailView: View {
    let briefing: DailyBriefingResponse?
    let summaryTile: SummaryTileData?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Today.sectionSpacing) {
                    // Header card with mood gradient
                    headerCard

                    // Key Metrics
                    if let metrics = briefing?.keyMetrics {
                        keyMetricsSection(metrics: metrics)
                    }

                    // Summary Line
                    if let summary = briefing?.summaryLine {
                        summarySection(summary: summary)
                    }

                    // Focus Windows
                    if let focusWindows = briefing?.focusWindows, !focusWindows.isEmpty {
                        focusWindowsSection(windows: focusWindows)
                    }

                    // Energy Dips
                    if let dips = briefing?.energyDips, !dips.isEmpty {
                        energyDipsSection(dips: dips)
                    }

                    Spacer(minLength: DesignSystem.Spacing.xl)
                }
                .padding(.horizontal, DesignSystem.Spacing.screenMargin)
                .padding(.top, DesignSystem.Spacing.md)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Today's Overview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.body.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header Card
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Greeting
            if let greeting = summaryTile?.greeting ?? briefing?.greeting {
                Text(greeting)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
            }

            // Mood badge
            HStack(spacing: DesignSystem.Spacing.sm) {
                if let emoji = summaryTile?.moodEmoji {
                    Text(emoji)
                        .font(.title2)
                }
                Text(summaryTile?.moodLabel ?? briefing?.moodLabel ?? "")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
            }

            // Quick stats
            HStack(spacing: DesignSystem.Spacing.md) {
                if let meetings = summaryTile?.meetingsLabel ?? briefing?.quickStats?.meetingsLabel {
                    QuickStatBadge(icon: "calendar", text: meetings)
                }
                if let focus = summaryTile?.focusTimeAvailable ?? briefing?.quickStats?.focusTimeAvailable {
                    QuickStatBadge(icon: "brain.head.profile", text: focus)
                }
                if let health = summaryTile?.healthLabel ?? briefing?.quickStats?.healthLabel {
                    QuickStatBadge(icon: "heart.fill", text: health)
                }
            }
        }
        .padding(DesignSystem.Today.cardPaddingLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Today.tileCornerRadius)
                .fill(summaryTile?.moodGradient ?? briefing?.moodGradient ?? TodayTileType.summary.defaultGradient)
        )
    }

    // MARK: - Key Metrics Section
    private func keyMetricsSection(metrics: BriefingKeyMetrics) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            DetailSectionHeader(title: "Key Metrics", icon: "chart.bar.fill")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.md) {
                if let sleep = metrics.effectiveSleepHours {
                    DetailMetricCard(title: "Sleep", value: String(format: "%.1fh", sleep), icon: "moon.fill", color: Color(hex: "8B5CF6"))
                }
                if let steps = metrics.effectiveSteps {
                    DetailMetricCard(title: "Steps", value: "\(steps)", icon: "figure.walk", color: Color(hex: "10B981"))
                }
                DetailMetricCard(title: "Meetings", value: "\(metrics.effectiveMeetingsCount)", icon: "calendar", color: Color(hex: "3B82F6"))
                if metrics.effectiveLongestFreeBlock > 0 {
                    DetailMetricCard(title: "Longest Block", value: "\(metrics.effectiveLongestFreeBlock)m", icon: "clock.fill", color: Color(hex: "F59E0B"))
                }
            }
        }
        .sectionCardStyle()
    }

    // MARK: - Summary Section
    private func summarySection(summary: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            DetailSectionHeader(title: "AI Summary", icon: "sparkles")

            Text(summary)
                .font(.body)
                .lineSpacing(4)
                .foregroundColor(DesignSystem.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .sectionCardStyle()
    }

    // MARK: - Focus Windows Section
    private func focusWindowsSection(windows: [FocusWindow]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            DetailSectionHeader(title: "Focus Windows", icon: "brain.head.profile")

            ForEach(windows, id: \.windowId) { window in
                FocusWindowRow(window: window)
            }
        }
        .sectionCardStyle()
    }

    // MARK: - Energy Dips Section
    private func energyDipsSection(dips: [EnergyDip]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            DetailSectionHeader(title: "Energy Dips", icon: "battery.50")

            ForEach(dips, id: \.dipId) { dip in
                EnergyDipRow(dip: dip)
            }
        }
        .sectionCardStyle()
    }
}

// MARK: - Quick Stat Badge
struct QuickStatBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption.weight(.medium))
        }
        .foregroundColor(.white.opacity(0.9))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.2))
        )
    }
}

// MARK: - Detail Section Header (with icon)
struct DetailSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primary)

            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Spacer()
        }
    }
}

// MARK: - Detail Metric Card (with icon and color)
struct DetailMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(DesignSystem.Colors.primaryText)
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.cardBackgroundElevated)
        )
    }
}
