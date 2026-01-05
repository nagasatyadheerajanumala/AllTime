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
    @State private var showingInsightsDetail = false
    @StateObject private var insightsViewModel = InsightsDashboardViewModel()

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
                        EmptyTileContent(message: "No actions")
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

            // Insights Tile - Full width
            TodayTileView(
                type: .insights,
                isLoading: insightsViewModel.state == .loading && insightsViewModel.claraNarrative.isEmpty,
                onTap: { showingInsightsDetail = true }
            ) {
                InsightsTileContent(viewModel: insightsViewModel)
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
        .sheet(isPresented: $showingInsightsDetail) {
            InsightsDashboardView()
        }
        .task {
            await insightsViewModel.loadData()
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
    @State private var addedFocusWindowIds: Set<String> = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Today.sectionSpacing) {
                    // Header card with mood gradient
                    headerCard

                    // Day Narrative (plain-English story about the day)
                    if let narrative = briefing?.dayNarrative {
                        dayNarrativeSection(narrative: narrative)
                    }

                    // Key Metrics (above Health Insights)
                    if let metrics = briefing?.keyMetrics {
                        keyMetricsSection(metrics: metrics)
                    }

                    // Health Insights Card
                    if let briefing = briefing {
                        HealthInsightsCard(
                            keyMetrics: briefing.keyMetrics,
                            suggestions: briefing.suggestions,
                            quickStats: briefing.quickStats
                        )
                    }

                    // Focus Windows
                    if let focusWindows = briefing?.focusWindows, !focusWindows.isEmpty {
                        focusWindowsSection(windows: focusWindows)
                    }

                    // Energy Dips
                    if let dips = briefing?.energyDips, !dips.isEmpty {
                        energyDipsSection(dips: dips)
                    }

                    // Enhanced AI Summary Section
                    if let briefing = briefing {
                        aiSummarySection(briefing: briefing)
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
                // Only show health metrics if they have meaningful values (> 0)
                if let sleep = metrics.effectiveSleepHours, sleep > 0 {
                    DetailMetricCard(title: "Sleep", value: String(format: "%.1fh", sleep), icon: "moon.fill", color: Color(hex: "8B5CF6"))
                }
                if let steps = metrics.effectiveSteps, steps > 0 {
                    DetailMetricCard(title: "Steps", value: steps.formatted(), icon: "figure.walk", color: Color(hex: "10B981"))
                }
                // Always show meetings as it's calendar-based, not health data
                if metrics.effectiveMeetingsCount > 0 {
                    DetailMetricCard(title: "Meetings", value: "\(metrics.effectiveMeetingsCount)", icon: "calendar", color: Color(hex: "3B82F6"))
                }
                if metrics.effectiveLongestFreeBlock > 0 {
                    DetailMetricCard(title: "Longest Block", value: "\(metrics.effectiveLongestFreeBlock)m", icon: "clock.fill", color: Color(hex: "F59E0B"))
                }
            }
        }
        .sectionCardStyle()
    }

    // MARK: - Day Narrative Section
    private func dayNarrativeSection(narrative: DayNarrative) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header with tone icon
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: narrative.toneIcon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(narrative.toneColor)

                Text(narrative.headline)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Spacer()
            }

            // Main story
            Text(narrative.story)
                .font(.body)
                .lineSpacing(4)
                .foregroundColor(DesignSystem.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            // Key observations (bullet points)
            if let observations = narrative.keyObservations, !observations.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    ForEach(observations, id: \.self) { observation in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                            Circle()
                                .fill(narrative.toneColor.opacity(0.6))
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)

                            Text(observation)
                                .font(.subheadline)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }
                }
                .padding(.top, DesignSystem.Spacing.xs)
            }

            // Health connection
            if let healthConnection = narrative.healthConnection, !healthConnection.isEmpty {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(Color(hex: "EF4444"))
                        .frame(width: 16)

                    Text(healthConnection)
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .fill(Color(hex: "EF4444").opacity(0.08))
                )
            }

            // Looking ahead
            if let lookingAhead = narrative.lookingAhead, !lookingAhead.isEmpty {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "arrow.forward.circle.fill")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .frame(width: 16)

                    Text(lookingAhead)
                        .font(.subheadline.italic())
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .fill(DesignSystem.Colors.primary.opacity(0.08))
                )
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
            HStack {
                DetailSectionHeader(title: "Focus Windows", icon: "brain.head.profile")
                Spacer()
                Text("Tap + to block time")
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }

            ForEach(windows, id: \.windowId) { window in
                ActionableFocusWindowRow(
                    window: window,
                    isAdded: addedFocusWindowIds.contains(window.windowId),
                    onAddToCalendar: {
                        addFocusWindowToCalendar(window)
                    }
                )
            }
        }
        .sectionCardStyle()
    }

    // Add focus window to calendar
    private func addFocusWindowToCalendar(_ window: FocusWindow) {
        Task {
            guard let startDate = window.startDate, let endDate = window.endDate else {
                print("Cannot add focus window - missing dates")
                return
            }

            do {
                let title = window.suggestedActivity ?? "Focus Time"
                let success = try await CalendarService.shared.createEvent(
                    title: title,
                    startDate: startDate,
                    endDate: endDate,
                    notes: window.reason
                )

                if success {
                    await MainActor.run {
                        withAnimation {
                            addedFocusWindowIds.insert(window.windowId)
                        }
                        // Haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                    print("Added focus window to calendar: \(title)")
                }
            } catch {
                print("Failed to add focus window to calendar: \(error)")
            }
        }
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

    // MARK: - Enhanced AI Summary Section
    private func aiSummarySection(briefing: DailyBriefingResponse) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            DetailSectionHeader(title: "AI Summary", icon: "sparkles")

            // Day Overview Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.md) {
                // Total Meeting Hours
                let meetingHours = calculateMeetingHours(from: briefing)
                DetailMetricCard(
                    title: "Meeting Time",
                    value: formatHours(meetingHours),
                    icon: "calendar.badge.clock",
                    color: Color(hex: "3B82F6")
                )

                // Total Free Hours
                let freeHours = calculateFreeHours(from: briefing)
                DetailMetricCard(
                    title: "Free Time",
                    value: formatHours(freeHours),
                    icon: "clock.fill",
                    color: Color(hex: "10B981")
                )
            }

            // AI Summary Text
            if !briefing.summaryLine.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text(briefing.summaryLine)
                        .font(.body)
                        .lineSpacing(4)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DesignSystem.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(DesignSystem.Colors.cardBackgroundElevated)
                )
            }

            // Today's Goals Section
            todayGoalsSection(briefing: briefing)
        }
        .sectionCardStyle()
    }

    // MARK: - Today's Goals Section
    @ViewBuilder
    private func todayGoalsSection(briefing: DailyBriefingResponse) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "target")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color(hex: "F59E0B"))
                Text("Today's Goals")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Steps Goal
                if let metrics = briefing.keyMetrics {
                    if let stepsAvg = metrics.stepsAverage, stepsAvg > 0 {
                        goalRow(
                            icon: "figure.walk",
                            title: "Steps",
                            target: "\(stepsAvg.formatted()) steps",
                            current: metrics.stepsToday ?? metrics.stepsYesterday,
                            targetValue: stepsAvg
                        )
                    }

                    // Active Minutes Goal
                    if let activeAvg = metrics.activeMinutesAverage, activeAvg > 0 {
                        goalRow(
                            icon: "flame.fill",
                            title: "Active Time",
                            target: "\(activeAvg) min",
                            current: metrics.activeMinutes ?? metrics.activeMinutesYesterday,
                            targetValue: activeAvg
                        )
                    }

                    // Sleep Goal (for tonight)
                    if let sleepAvg = metrics.sleepHoursAverage, sleepAvg > 0 {
                        goalRow(
                            icon: "moon.fill",
                            title: "Sleep Tonight",
                            target: String(format: "%.1fh", sleepAvg),
                            sleepCurrent: metrics.sleepHoursLastNight ?? metrics.effectiveSleepHours,
                            sleepTarget: sleepAvg
                        )
                    }
                }

                // Focus Time Goal
                if let quickStats = briefing.quickStats, let focusTime = quickStats.focusTimeAvailable {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.primary)
                            .frame(width: 20)

                        Text("Focus Time Available")
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        Spacer()

                        Text(focusTime)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                    .padding(DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                            .fill(DesignSystem.Colors.primary.opacity(0.1))
                    )
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.cardBackgroundElevated)
        )
    }

    // MARK: - Goal Row Helper
    @ViewBuilder
    private func goalRow(icon: String, title: String, target: String, current: Int?, targetValue: Int) -> some View {
        let progress = current != nil ? min(Double(current!) / Double(targetValue), 1.0) : 0
        let progressColor = progress >= 0.8 ? Color(hex: "10B981") : (progress >= 0.5 ? Color(hex: "F59E0B") : Color(hex: "EF4444"))

        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(progressColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(DesignSystem.Colors.tertiaryText.opacity(0.3))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(progressColor)
                            .frame(width: geo.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                if let curr = current {
                    Text("\(curr.formatted())")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(progressColor)
                }
                Text("/ \(target)")
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(progressColor.opacity(0.08))
        )
    }

    @ViewBuilder
    private func goalRow(icon: String, title: String, target: String, sleepCurrent: Double?, sleepTarget: Double) -> some View {
        let progress = sleepCurrent != nil ? min(sleepCurrent! / sleepTarget, 1.0) : 0
        let progressColor = progress >= 0.9 ? Color(hex: "10B981") : (progress >= 0.7 ? Color(hex: "F59E0B") : Color(hex: "EF4444"))

        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Color(hex: "8B5CF6"))
                .frame(width: 20)

            Text(title)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.primaryText)

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                if let curr = sleepCurrent {
                    Text(String(format: "%.1fh", curr))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(progressColor)
                    Text("last night")
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                } else {
                    Text("Target: \(target)")
                        .font(.caption.weight(.medium))
                        .foregroundColor(Color(hex: "8B5CF6"))
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(Color(hex: "8B5CF6").opacity(0.08))
        )
    }

    // MARK: - Helper Functions
    private func calculateMeetingHours(from briefing: DailyBriefingResponse) -> Double {
        if let metrics = briefing.keyMetrics {
            // Use actual meeting hours if available
            if let totalHours = metrics.totalMeetingHoursToday {
                return totalHours
            }
            // Legacy fallback
            if let meetingHours = metrics.meetingHours {
                return meetingHours
            }
            // Estimate from meeting count: average meeting is ~45 minutes
            let meetingsCount = metrics.effectiveMeetingsCount
            return Double(meetingsCount) * 0.75
        }
        return 0
    }

    private func calculateFreeHours(from briefing: DailyBriefingResponse) -> Double {
        if let metrics = briefing.keyMetrics {
            // Use actual free hours if available
            if let freeHours = metrics.freeHoursToday {
                return freeHours
            }
            // Legacy fallback
            if let freeTimeHours = metrics.freeTimeHours {
                return freeTimeHours
            }
            // Estimate from longest free block (assume ~2-3 blocks per day)
            let longestBlock = metrics.effectiveLongestFreeBlock
            if longestBlock > 0 {
                return Double(longestBlock) * 2.5 / 60.0
            }
        }
        // Default: estimate based on typical 8-hour workday minus meetings
        let meetingHours = calculateMeetingHours(from: briefing)
        return max(0, 8 - meetingHours)
    }

    private func formatHours(_ hours: Double) -> String {
        if hours < 1 {
            return "\(Int(hours * 60).formatted())m"
        } else if hours == Double(Int(hours)) {
            return "\(Int(hours).formatted())h"
        } else {
            let wholeHours = Int(hours)
            let minutes = Int((hours - Double(wholeHours)) * 60)
            if minutes == 0 {
                return "\(wholeHours.formatted())h"
            }
            return "\(wholeHours.formatted())h \(minutes)m"
        }
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

// MARK: - Insights Tile Content
struct InsightsTileContent: View {
    @ObservedObject var viewModel: InsightsDashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Clara's narrative (1 line summary)
            if !viewModel.claraNarrative.isEmpty {
                Text(viewModel.claraNarrative)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("View your weekly summary")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer(minLength: 0)

            // Compact metrics row (3 chips max)
            if !viewModel.keyMetrics.isEmpty {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(viewModel.keyMetrics.prefix(3)) { metric in
                        InsightMetricChip(
                            icon: metric.icon,
                            value: metric.value,
                            label: metric.label
                        )
                    }
                    Spacer()
                }
            } else {
                // Skeleton chips when loading
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 70, height: 28)
                    }
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Insight Metric Chip (Compact, subtle)
struct InsightMetricChip: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.12))
        )
    }
}

// MARK: - Actionable Focus Window Row (with Add to Calendar)
struct ActionableFocusWindowRow: View {
    let window: FocusWindow
    let isAdded: Bool
    let onAddToCalendar: () -> Void

    @State private var isExpanded = false

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // Time indicator
            VStack(spacing: 2) {
                Circle()
                    .fill(Color(hex: "8B5CF6"))
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(Color(hex: "8B5CF6").opacity(0.3))
                    .frame(width: 2, height: 20)
                Circle()
                    .stroke(Color(hex: "8B5CF6"), lineWidth: 2)
                    .frame(width: 8, height: 8)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(TimeRangeFormatter.format(start: window.startTime, end: window.endTime, compact: true))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Text(TimeRangeFormatter.formatDuration(minutes: window.durationMinutes))
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    if let quality = window.qualityScore {
                        Text("Quality: \(quality)%")
                            .font(.caption2)
                            .foregroundColor(Color(hex: "8B5CF6"))
                    }
                }

                // Suggested activity if available
                if let activity = window.suggestedActivity, !activity.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                        Text(activity)
                            .font(.caption)
                    }
                    .foregroundColor(Color(hex: "8B5CF6"))
                    .fixedSize(horizontal: false, vertical: true)
                }

                // Reason - expandable for long text
                if let reason = window.reason, !reason.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reason)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                            .lineSpacing(2)
                            .lineLimit(isExpanded ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)

                        if reason.count > 80 {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isExpanded.toggle()
                                }
                            }) {
                                Text(isExpanded ? "Show less" : "Show more")
                                    .font(.caption2)
                                    .foregroundColor(DesignSystem.Colors.primary)
                            }
                        }
                    }
                }
            }

            Spacer()

            // Add to Calendar Button
            Button(action: onAddToCalendar) {
                HStack(spacing: 4) {
                    Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 20))
                }
                .foregroundColor(isAdded ? .green : Color(hex: "8B5CF6"))
            }
            .disabled(isAdded)
            .padding(.top, 2)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(isAdded ? Color.green.opacity(0.08) : Color(hex: "8B5CF6").opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .stroke(isAdded ? Color.green.opacity(0.2) : Color(hex: "8B5CF6").opacity(0.15), lineWidth: 1)
                )
        )
    }
}
