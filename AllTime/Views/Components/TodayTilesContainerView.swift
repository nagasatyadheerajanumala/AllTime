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
    /// Fresh HealthKit data - when provided, these values are displayed instead of backend data
    var freshHealthMetrics: DailyHealthMetrics? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var addedFocusWindowIds: Set<String> = []
    @State private var showingRecommendationActionSheet = false
    @State private var isBlockingFocusTime = false

    // Collapsible section states
    @State private var isStoryExpanded = false
    @State private var isMetricsExpanded = true
    @State private var isEnergyExpanded = true

    /// Get fresh sleep hours, falling back to backend data
    private var displaySleepHours: Double? {
        if let freshMinutes = freshHealthMetrics?.sleepMinutes, freshMinutes > 0 {
            return Double(freshMinutes) / 60.0
        }
        return briefing?.keyMetrics?.effectiveSleepHours
    }

    /// Get fresh steps, falling back to backend data
    private var displaySteps: Int? {
        if let freshSteps = freshHealthMetrics?.steps, freshSteps > 0 {
            return freshSteps
        }
        return briefing?.keyMetrics?.effectiveSteps
    }

    /// Get fresh active minutes, falling back to backend data
    private var displayActiveMinutes: Int? {
        if let freshMinutes = freshHealthMetrics?.activeMinutes, freshMinutes > 0 {
            return freshMinutes
        }
        return briefing?.keyMetrics?.activeMinutesYesterday ?? briefing?.keyMetrics?.activeMinutes
    }

    /// Get fresh resting heart rate, falling back to backend data
    private var displayRestingHeartRate: Int? {
        if let freshHR = freshHealthMetrics?.restingHeartRate, freshHR > 0 {
            return Int(freshHR)
        }
        return briefing?.keyMetrics?.restingHeartRate
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Compact header with mood
                    compactHeader
                        .padding(.horizontal, 16)

                    // Primary Recommendation (THE one thing)
                    if let recommendation = briefing?.primaryRecommendation {
                        primaryRecommendationCard(recommendation)
                            .padding(.horizontal, 16)
                    }

                    // Day Story (collapsible - shows headline + expandable story)
                    if let narrative = briefing?.dayNarrative {
                        dayStorySection(narrative: narrative)
                            .padding(.horizontal, 16)
                    }

                    // Energy Budget Visual
                    if let energyBudget = briefing?.energyBudget {
                        energyBudgetSection(energyBudget)
                            .padding(.horizontal, 16)
                    }

                    // Quick metrics strip
                    metricsStripSection
                        .padding(.horizontal, 16)

                    // Focus Windows (actionable)
                    if let focusWindows = briefing?.focusWindows, !focusWindows.isEmpty {
                        focusWindowsSection(windows: focusWindows)
                            .padding(.horizontal, 16)
                    }

                    // Energy timeline (visual, not text)
                    if let dips = briefing?.energyDips, !dips.isEmpty {
                        energyTimelineSection(dips: dips)
                            .padding(.horizontal, 16)
                    }

                    // Clara Prompts (ask Clara)
                    if let prompts = briefing?.claraPrompts, !prompts.isEmpty {
                        claraPromptsSection(prompts)
                            .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
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
            .sheet(isPresented: $showingRecommendationActionSheet) {
                if let recommendation = briefing?.primaryRecommendation {
                    PrimaryRecommendationActionSheet(
                        recommendation: recommendation,
                        focusWindow: briefing?.focusWindows?.first
                    )
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Primary Recommendation Card
    private func primaryRecommendationCard(_ recommendation: PrimaryRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: recommendation.icon ?? "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text("Top Priority")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                if let urgency = recommendation.urgency {
                    Text(urgency.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.2)))
                }
            }

            // Action
            Text(recommendation.action)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            // Reason (if available)
            if let reason = recommendation.reason, !reason.isEmpty {
                Text(reason)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Action Button
            Button(action: {
                // Show the action sheet for user to confirm
                showingRecommendationActionSheet = true
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }) {
                HStack(spacing: 8) {
                    if isBlockingFocusTime {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: recommendation.urgencyColor))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(actionButtonLabel(for: recommendation))
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(recommendation.urgencyColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isBlockingFocusTime)
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [recommendation.urgencyColor, recommendation.urgencyColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    // Action button label based on recommendation category
    private func actionButtonLabel(for recommendation: PrimaryRecommendation) -> String {
        switch recommendation.category?.lowercased() {
        case "protect_time", "focus":
            return "Block Focus Time"
        case "reduce_load":
            return "Review Calendar"
        case "health":
            return "Set Reminder"
        case "catch_up":
            return "Schedule Now"
        default:
            return "Take Action"
        }
    }


    // MARK: - Day Story Section (Clear Read More)
    private func dayStorySection(narrative: DayNarrative) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon + Headline (always visible)
            HStack(spacing: 10) {
                Image(systemName: narrative.toneIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(narrative.toneColor)

                Text(narrative.headline)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }

            // Key points as colored tags (always visible)
            if let observations = narrative.keyObservations, !observations.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(observations.prefix(3).enumerated()), id: \.offset) { index, obs in
                            let shortText = String(obs.split(separator: " ").prefix(5).joined(separator: " "))
                            Text(shortText)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(storyTagColor(index))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(storyTagColor(index).opacity(0.12)))
                        }
                    }
                }
            }

            // Health alert (always visible if exists)
            if let healthConnection = narrative.healthConnection, !healthConnection.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.errorRed)
                    Text(healthConnection)
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.errorRed)
                        .lineLimit(2)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.Colors.errorRed.opacity(0.08)))
            }

            // Clear "Read full story" button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isStoryExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Text(isStoryExpanded ? "Hide details" : "Read full story")
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: isStoryExpanded ? "chevron.up" : "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(DesignSystem.Colors.primary)
                .padding(.top, 4)
            }
            .buttonStyle(PlainButtonStyle())

            // Expandable content
            if isStoryExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // Full story
                    Text(narrative.story)
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    // Key observations as bullet points
                    if let observations = narrative.keyObservations, !observations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Key Points")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.secondaryText)

                            ForEach(observations, id: \.self) { observation in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(narrative.toneColor)
                                        .frame(width: 5, height: 5)
                                        .padding(.top, 6)

                                    Text(observation)
                                        .font(.system(size: 13))
                                        .foregroundColor(DesignSystem.Colors.primaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    // Health connection
                    if let healthConnection = narrative.healthConnection, !healthConnection.isEmpty {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.Colors.errorRed)

                            Text(healthConnection)
                                .font(.system(size: 13))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(DesignSystem.Colors.errorRed.opacity(0.08))
                        )
                    }

                    // Looking ahead
                    if let lookingAhead = narrative.lookingAhead, !lookingAhead.isEmpty {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "arrow.forward.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.Colors.blue)

                            Text(lookingAhead)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.blue)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(DesignSystem.Colors.blue.opacity(0.08))
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // MARK: - Energy Budget Section (Visual Ring + Compact Info)
    private func energyBudgetSection(_ budget: EnergyBudget) -> some View {
        VStack(spacing: 16) {
            // Top row: Ring + Trajectory + Key info
            HStack(spacing: 20) {
                // Energy Ring (visual)
                energyRingView(current: budget.currentLevel ?? 0, endOfDay: budget.predictedEndOfDay ?? 0)

                // Info column
                VStack(alignment: .leading, spacing: 8) {
                    // Trajectory badge
                    if let trajectory = budget.trajectory {
                        HStack(spacing: 4) {
                            Image(systemName: trajectoryIcon(trajectory))
                                .font(.system(size: 12, weight: .semibold))
                            Text(budget.trajectoryLabel ?? trajectory.capitalized)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(trajectoryColor(trajectory))
                    }

                    // Capacity label
                    if let capacityLabel = budget.capacityLabel {
                        Text(capacityLabel)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }

                    // Peak time (most important)
                    if let peak = budget.peakWindow {
                        HStack(spacing: 6) {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 11))
                                .foregroundColor(DesignSystem.Colors.amber)
                            Text("Peak: \(peak.displayLabel)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }
                }

                Spacer()
            }

            // Bottom row: Boosts & Drains side by side
            HStack(spacing: 12) {
                // Boosts
                if let deposits = budget.energyDeposits, !deposits.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(DesignSystem.Colors.emerald)
                            Text("Boosts")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.emerald)
                        }
                        ForEach(deposits.prefix(2), id: \.label) { deposit in
                            Text("• \(deposit.label ?? "")")
                                .font(.system(size: 11))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                                .lineLimit(1)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.Colors.emerald.opacity(0.08)))
                }

                // Drains
                if let drains = budget.energyDrains, !drains.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(DesignSystem.Colors.errorRed)
                            Text("Drains")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.errorRed)
                        }
                        ForEach(drains.prefix(2), id: \.label) { drain in
                            Text("• \(drain.label ?? "")")
                                .font(.system(size: 11))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                                .lineLimit(1)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.Colors.errorRed.opacity(0.08)))
                }
            }

            // Recovery recommendation (if needed)
            if budget.recoveryNeeded == true, let recommendation = budget.recoveryRecommendation {
                HStack(spacing: 8) {
                    Image(systemName: "cross.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.emerald)
                    Text(recommendation)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.emerald)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.Colors.emerald.opacity(0.1)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // Energy Ring View (Visual)
    private func energyRingView(current: Int, endOfDay: Int) -> some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(DesignSystem.Colors.tertiaryText.opacity(0.2), lineWidth: 8)
                .frame(width: 80, height: 80)

            // Progress ring
            Circle()
                .trim(from: 0, to: CGFloat(current) / 100.0)
                .stroke(
                    energyColor(current),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90))

            // Center content
            VStack(spacing: 2) {
                Text("\(current)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(energyColor(current))

                HStack(spacing: 2) {
                    Image(systemName: current > endOfDay ? "arrow.down" : (current < endOfDay ? "arrow.up" : "arrow.right"))
                        .font(.system(size: 8, weight: .bold))
                    Text("\(endOfDay)")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(energyColor(endOfDay))
            }
        }
    }

    private func trajectoryIcon(_ trajectory: String) -> String {
        switch trajectory.lowercased() {
        case "rising": return "arrow.up.right"
        case "declining": return "arrow.down.right"
        case "recovering": return "arrow.up.forward.circle"
        default: return "arrow.right"
        }
    }

    private func trajectoryColor(_ trajectory: String) -> Color {
        switch trajectory.lowercased() {
        case "rising", "recovering": return DesignSystem.Colors.emerald
        case "declining": return DesignSystem.Colors.errorRed
        default: return DesignSystem.Colors.blue
        }
    }

    private func energyColor(_ level: Int) -> Color {
        if level >= 70 { return DesignSystem.Colors.emerald }
        if level >= 40 { return DesignSystem.Colors.amber }
        return DesignSystem.Colors.errorRed
    }

    private func storyTagColor(_ index: Int) -> Color {
        let colors: [Color] = [DesignSystem.Colors.blue, DesignSystem.Colors.violet, DesignSystem.Colors.amber]
        return colors[index % colors.count]
    }

    // MARK: - Clara Prompts Section
    private func claraPromptsSection(_ prompts: [ClaraPrompt]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.violet)

                Text("Ask Clara")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                Spacer()
            }

            // Horizontal scroll of prompt chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(prompts.prefix(5)) { prompt in
                        Button(action: {
                            // TODO: Open Clara with this prompt
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: prompt.displayIcon)
                                    .font(.system(size: 12))
                                Text(prompt.label ?? "Ask")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(DesignSystem.Colors.violet)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(DesignSystem.Colors.violet.opacity(0.1))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // MARK: - Compact Header
    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Greeting
            if let greeting = summaryTile?.greeting ?? briefing?.greeting {
                Text(greeting)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }

            // Mood + Quick stats row
            HStack(spacing: 12) {
                // Mood badge
                HStack(spacing: 6) {
                    if let emoji = summaryTile?.moodEmoji {
                        Text(emoji)
                            .font(.system(size: 16))
                    }
                    Text(summaryTile?.moodLabel ?? briefing?.moodLabel ?? "")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(0.2)))

                // Quick stats as pills
                if let meetings = summaryTile?.meetingsLabel ?? briefing?.quickStats?.meetingsLabel {
                    quickStatPill(icon: "calendar", text: meetings)
                }
                if let focus = summaryTile?.focusTimeAvailable ?? briefing?.quickStats?.focusTimeAvailable {
                    quickStatPill(icon: "brain.head.profile", text: focus)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(summaryTile?.moodGradient ?? briefing?.moodGradient ?? TodayTileType.summary.defaultGradient)
        )
    }

    private func quickStatPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.white.opacity(0.9))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.15)))
    }

    // MARK: - Metrics Strip Section
    private var metricsStripSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Metrics")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.secondaryText)

            HStack(spacing: 10) {
                // Sleep
                if let sleep = displaySleepHours, sleep > 0 {
                    compactMetric(
                        icon: "moon.fill",
                        value: String(format: "%.1f", sleep),
                        unit: "h",
                        label: "Sleep",
                        color: sleep >= 7 ? DesignSystem.Colors.emerald : (sleep >= 6 ? DesignSystem.Colors.amber : DesignSystem.Colors.errorRed)
                    )
                }

                // Steps
                if let steps = displaySteps, steps > 0 {
                    compactMetric(
                        icon: "figure.walk",
                        value: steps >= 1000 ? String(format: "%.1fk", Double(steps) / 1000) : "\(steps)",
                        unit: "",
                        label: "Steps",
                        color: steps >= 8000 ? DesignSystem.Colors.emerald : (steps >= 5000 ? DesignSystem.Colors.blue : DesignSystem.Colors.amber)
                    )
                }

                // Meetings
                if let metrics = briefing?.keyMetrics, metrics.effectiveMeetingsCount > 0 {
                    compactMetric(
                        icon: "calendar",
                        value: "\(metrics.effectiveMeetingsCount)",
                        unit: "",
                        label: "Meetings",
                        color: metrics.effectiveMeetingsCount >= 6 ? DesignSystem.Colors.errorRed : (metrics.effectiveMeetingsCount >= 4 ? DesignSystem.Colors.amber : DesignSystem.Colors.blue)
                    )
                }

                // Free time
                if let metrics = briefing?.keyMetrics, metrics.effectiveLongestFreeBlock > 0 {
                    compactMetric(
                        icon: "clock.fill",
                        value: metrics.effectiveLongestFreeBlock >= 60 ? "\(metrics.effectiveLongestFreeBlock / 60)h" : "\(metrics.effectiveLongestFreeBlock)m",
                        unit: "",
                        label: "Free",
                        color: DesignSystem.Colors.emerald
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    private func compactMetric(icon: String, value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)

            HStack(spacing: 1) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }

    // MARK: - Energy Timeline (Visual)
    private func energyTimelineSection(dips: [EnergyDip]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "battery.50")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.amber)

                Text("Energy Timeline")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                Spacer()
            }

            // Visual timeline
            HStack(spacing: 8) {
                ForEach(dips.prefix(3), id: \.dipId) { dip in
                    energyDipCard(dip: dip)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    private func energyDipCard(dip: EnergyDip) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Time
            Text(dip.displayTime)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)

            // Severity indicator
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < dipSeverityLevel(dip) ? DesignSystem.Colors.amber : DesignSystem.Colors.tertiaryText.opacity(0.3))
                        .frame(width: 16, height: 4)
                }
            }

            // Recommendation
            if let recommendation = dip.recommendation {
                Text(recommendation.split(separator: " ").prefix(4).joined(separator: " "))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.amber.opacity(0.08))
        )
    }

    private func dipSeverityLevel(_ dip: EnergyDip) -> Int {
        // Return 1-3 based on severity
        switch dip.severity.lowercased() {
        case "high": return 3
        case "medium": return 2
        default: return 1
        }
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
    /// Displays health metrics, preferring fresh HealthKit data over backend data
    private func keyMetricsSection(metrics: BriefingKeyMetrics) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            DetailSectionHeader(title: "Key Metrics", icon: "chart.bar.fill")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.md) {
                // Use fresh HealthKit data when available, otherwise fall back to backend data
                if let sleep = displaySleepHours, sleep > 0 {
                    DetailMetricCard(title: "Sleep", value: String(format: "%.1fh", sleep), icon: "moon.fill", color: DesignSystem.Colors.violet)
                }
                if let steps = displaySteps, steps > 0 {
                    DetailMetricCard(title: "Steps", value: steps.formatted(), icon: "figure.walk", color: DesignSystem.Colors.emerald)
                }
                // Always show meetings as it's calendar-based, not health data
                if metrics.effectiveMeetingsCount > 0 {
                    DetailMetricCard(title: "Meetings", value: "\(metrics.effectiveMeetingsCount)", icon: "calendar", color: DesignSystem.Colors.blue)
                }
                if metrics.effectiveLongestFreeBlock > 0 {
                    DetailMetricCard(title: "Longest Block", value: "\(metrics.effectiveLongestFreeBlock)m", icon: "clock.fill", color: DesignSystem.Colors.amber)
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
                        .foregroundColor(DesignSystem.Colors.errorRed)
                        .frame(width: 16)

                    Text(healthConnection)
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .fill(DesignSystem.Colors.errorRed.opacity(0.08))
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

    // Add focus window to calendar - syncs to Google/Microsoft Calendar via backend
    private func addFocusWindowToCalendar(_ window: FocusWindow) {
        Task {
            guard let startDate = window.startDate, let endDate = window.endDate else {
                print("Cannot add focus window - missing dates")
                return
            }

            do {
                let title = window.suggestedActivity ?? "Focus Time"

                // Use FocusTimeService to sync to Google/Microsoft Calendar via backend
                let response = try await FocusTimeService.shared.blockFocusTime(
                    start: startDate,
                    end: endDate,
                    title: title,
                    description: window.reason ?? "Focus time block",
                    enableFocusMode: false,
                    calendarProvider: "all"  // Sync to all connected calendars
                )

                if response.success {
                    await MainActor.run {
                        withAnimation {
                            addedFocusWindowIds.insert(window.windowId)
                        }
                        // Haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                    print("✅ Added focus window to calendar: \(title)")

                    // Log calendar sync results
                    if let calendarEvents = response.calendarEvents {
                        for event in calendarEvents {
                            if event.success {
                                print("   ✅ \(event.provider) Calendar: synced")
                            } else {
                                print("   ⚠️ \(event.provider) Calendar: failed - \(event.error ?? "unknown")")
                            }
                        }
                    }

                    // Post notification for UI refresh
                    NotificationCenter.default.post(name: NSNotification.Name("EventCreated"), object: nil)
                } else {
                    print("❌ Failed to add focus window: \(response.message ?? "unknown error")")
                }
            } catch {
                print("❌ Failed to add focus window to calendar: \(error)")
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
                    color: DesignSystem.Colors.blue
                )

                // Total Free Hours
                let freeHours = calculateFreeHours(from: briefing)
                DetailMetricCard(
                    title: "Free Time",
                    value: formatHours(freeHours),
                    icon: "clock.fill",
                    color: DesignSystem.Colors.emerald
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
                    .foregroundColor(DesignSystem.Colors.amber)
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
        let progressColor = progress >= 0.8 ? DesignSystem.Colors.emerald : (progress >= 0.5 ? DesignSystem.Colors.amber : DesignSystem.Colors.errorRed)

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
        let progressColor = progress >= 0.9 ? DesignSystem.Colors.emerald : (progress >= 0.7 ? DesignSystem.Colors.amber : DesignSystem.Colors.errorRed)

        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.violet)
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
                        .foregroundColor(DesignSystem.Colors.violet)
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(DesignSystem.Colors.violet.opacity(0.08))
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
                    .fill(DesignSystem.Colors.violet)
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(DesignSystem.Colors.violet.opacity(0.3))
                    .frame(width: 2, height: 20)
                Circle()
                    .stroke(DesignSystem.Colors.violet, lineWidth: 2)
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
                            .foregroundColor(DesignSystem.Colors.violet)
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
                    .foregroundColor(DesignSystem.Colors.violet)
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
                .foregroundColor(isAdded ? .green : DesignSystem.Colors.violet)
            }
            .disabled(isAdded)
            .padding(.top, 2)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(isAdded ? Color.green.opacity(0.08) : DesignSystem.Colors.violet.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .stroke(isAdded ? Color.green.opacity(0.2) : DesignSystem.Colors.violet.opacity(0.15), lineWidth: 1)
                )
        )
    }
}
