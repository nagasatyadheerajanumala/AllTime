import SwiftUI

struct TodayView: View {
    @EnvironmentObject var calendarViewModel: CalendarViewModel
    @StateObject private var briefingViewModel = TodayBriefingViewModel()
    @StateObject private var overviewViewModel = TodayOverviewViewModel()
    @State private var selectedEvent: Event?
    @State private var showingAddEvent = false
    @ObservedObject private var healthMetricsService = HealthMetricsService.shared

    // Sheet presentation states
    @State private var showingSummaryDetail = false
    @State private var showingSuggestionsDetail = false
    @State private var showingTodoDetail = false
    @State private var showingInsightsDashboard = false

    // Accordion expansion states (kept for compatibility)
    @State private var expandedSections: Set<String> = []

    private var todayEvents: [Event] {
        calendarViewModel.eventsForToday().sorted { event1, event2 in
            guard let start1 = event1.startDate, let start2 = event2.startDate else { return false }
            return start1 < start2
        }
    }

    private var upcomingEvents: [Event] {
        let now = Date()
        return todayEvents.filter { event in
            guard let startDate = event.startDate else { return false }
            return startDate > now
        }
    }

    private var currentEvent: Event? {
        let now = Date()
        return todayEvents.first { event in
            guard let start = event.startDate, let end = event.endDate else { return false }
            return now >= start && now <= end
        }
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                // Background
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                // Main scrollable content
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        // Safe area padding
                        Color.clear.frame(height: 8)

                        // SECTION 1: Hero Summary Card (PRIMARY)
                        // Replaces greeting header + 4 colorful tiles with single calm hero
                        HeroSummaryCard(
                            overview: overviewViewModel.overview,
                            briefing: briefingViewModel.briefing,
                            isLoading: overviewViewModel.isLoading || briefingViewModel.isLoading,
                            onTap: { showingSummaryDetail = true }
                        )
                        .padding(.horizontal, DesignSystem.Spacing.md)

                        // SECTION 2: Actions Row (SECONDARY)
                        // Compact suggestions + todo counts
                        ActionsRow(
                            overview: overviewViewModel.overview,
                            briefing: briefingViewModel.briefing,
                            isLoading: overviewViewModel.isLoading || briefingViewModel.isLoading,
                            onSuggestionsTap: { showingSuggestionsDetail = true },
                            onTodoTap: { showingTodoDetail = true }
                        )
                        .padding(.horizontal, DesignSystem.Spacing.md)

                        // SECTION 3: Weekly Insights (Capacity Score + Patterns)
                        // Moved up for prominence - shows capacity health
                        InsightsPreviewCard(onTap: { showingInsightsDashboard = true })
                            .padding(.horizontal, DesignSystem.Spacing.md)

                        // SECTION 4: Plan Your Day (UpNext)
                        // Task management and intelligent suggestions
                        UpNextSectionView()
                            .padding(.horizontal, DesignSystem.Spacing.md)

                        // SECTION 5: Mood Check-In
                        // How are you feeling? + energy prediction
                        MoodCheckInCardView()
                            .padding(.horizontal, DesignSystem.Spacing.md)

                        // SECTION 6: Schedule (CONDITIONAL)
                        // Only show if there are events today
                        if !todayEvents.isEmpty {
                            eventsSection
                                .padding(.horizontal, DesignSystem.Spacing.md)
                        }

                        // Health Access Card (if not authorized)
                        if !healthMetricsService.isAuthorized {
                            TodayHealthCard()
                                .padding(.horizontal, DesignSystem.Spacing.md)
                        }

                        // Bottom padding for FAB
                        Color.clear.frame(height: 100)
                    }
                }
                .refreshable {
                    await calendarViewModel.refreshEvents()
                    await briefingViewModel.refresh()
                    await overviewViewModel.refresh()
                }

                // Floating Action Button
                fabButton
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            .sheet(item: $selectedEvent) { event in
                LocalEventDetailSheet(event: event)
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(initialDate: Date())
            }
            .sheet(isPresented: $showingSummaryDetail) {
                TodaySummaryDetailView(
                    briefing: briefingViewModel.briefing,
                    summaryTile: overviewViewModel.overview?.summaryTile
                )
            }
            .sheet(isPresented: $showingSuggestionsDetail) {
                SuggestionsDetailView(
                    briefing: briefingViewModel.briefing,
                    suggestionsTile: overviewViewModel.overview?.suggestionsTile
                )
            }
            .sheet(isPresented: $showingTodoDetail) {
                ToDoDetailView(todoTile: overviewViewModel.overview?.todoTile)
            }
            .sheet(isPresented: $showingInsightsDashboard) {
                InsightsDashboardView()
            }
            .onAppear {
                Task {
                    await calendarViewModel.loadEventsForSelectedDate(Date())
                    await healthMetricsService.checkAuthorizationStatus()
                    await briefingViewModel.fetchBriefing()
                    await overviewViewModel.fetchOverview()
                }
            }
            .onChange(of: healthMetricsService.isAuthorized) { oldValue, newValue in
                if !oldValue && newValue {
                    Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        await HealthSyncService.shared.syncRecentDays()
                    }
                }
            }
        }
    }

    // MARK: - Briefing Content
    @ViewBuilder
    private func briefingContent(briefing: DailyBriefingResponse) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // (2) Daily Summary Card
            DailySummaryCardView(briefing: briefing)
                .padding(.horizontal, DesignSystem.Spacing.md)

            // (3) Today's Plan Section (Top 3 suggestions)
            if let suggestions = briefing.suggestions, !suggestions.isEmpty {
                TodaysPlanSection(suggestions: suggestions)
                    .padding(.horizontal, DesignSystem.Spacing.md)
            }

            // (4) Health Insights Card - Prominent health data display
            HealthInsightsCard(
                keyMetrics: briefing.keyMetrics,
                suggestions: briefing.suggestions,
                quickStats: briefing.quickStats
            )
            .padding(.horizontal, DesignSystem.Spacing.md)

            // (5) Quick Stats Row
            QuickStatsRowView(
                quickStats: briefing.quickStats,
                keyMetrics: briefing.keyMetrics
            )
            .padding(.horizontal, DesignSystem.Spacing.md)

            // (6) Insights Section (Accordions)
            insightsSection(briefing: briefing)
                .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }

    // MARK: - Insights Section (Accordions)
    @ViewBuilder
    private func insightsSection(briefing: DailyBriefingResponse) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Section title
            HStack {
                Text("Insights")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.xs)

            // (5a) All Suggestions Accordion
            if let suggestions = briefing.suggestions, !suggestions.isEmpty {
                InsightsAccordionSection(
                    title: "All Actions",
                    icon: "lightbulb.fill",
                    iconColor: Color(hex: "F59E0B"),
                    badge: "\(suggestions.count)",
                    isExpanded: expandedSections.contains("suggestions"),
                    onToggle: { toggleSection("suggestions") },
                    content: AnyView(AllSuggestionsList(suggestions: suggestions))
                )
            }

            // (5b) Focus Windows Accordion
            if let focusWindows = briefing.focusWindows, !focusWindows.isEmpty {
                InsightsAccordionSection(
                    title: "Focus Windows",
                    icon: "brain.head.profile",
                    iconColor: DesignSystem.Colors.primary,
                    badge: "\(focusWindows.count) available",
                    isExpanded: expandedSections.contains("focus"),
                    onToggle: { toggleSection("focus") },
                    content: AnyView(FocusWindowsList(focusWindows: focusWindows))
                )
            }

            // (5c) Energy Dips Accordion
            if let energyDips = briefing.energyDips, !energyDips.isEmpty {
                InsightsAccordionSection(
                    title: "Energy Dips",
                    icon: "battery.50",
                    iconColor: Color(hex: "F59E0B"),
                    badge: "\(energyDips.count) predicted",
                    isExpanded: expandedSections.contains("energy"),
                    onToggle: { toggleSection("energy") },
                    content: AnyView(EnergyDipsList(energyDips: energyDips))
                )
            }

            // (6) Detailed Summary Accordion
            if briefing.keyMetrics != nil {
                InsightsAccordionSection(
                    title: "Detailed Summary",
                    icon: "doc.text.fill",
                    iconColor: DesignSystem.Colors.accent,
                    badge: nil,
                    isExpanded: expandedSections.contains("details"),
                    onToggle: { toggleSection("details") },
                    content: AnyView(DetailedSummaryContent(briefing: briefing))
                )
            }
        }
    }

    // MARK: - Events Section
    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section header
            HStack {
                Text("Schedule")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                Spacer()

                Text("\(todayEvents.count) event\(todayEvents.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }

            // Event list
            VStack(spacing: 8) {
                ForEach(todayEvents.prefix(5)) { event in
                    CompactEventRow(
                        event: event,
                        isCurrentEvent: event.id == currentEvent?.id,
                        isPastEvent: isPastEvent(event)
                    )
                    .onTapGesture {
                        selectedEvent = event
                    }
                }

                // Show more if needed
                if todayEvents.count > 5 {
                    Text("+ \(todayEvents.count - 5) more events")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.cardBackground)
            )
        }
    }

    // MARK: - Refresh Button
    private var refreshButton: some View {
        Button(action: {
            Task { await briefingViewModel.refresh() }
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignSystem.Colors.primary)
                .rotationEffect(.degrees(briefingViewModel.isLoading ? 360 : 0))
                .animation(
                    briefingViewModel.isLoading ?
                        Animation.linear(duration: 1).repeatForever(autoreverses: false) :
                        .default,
                    value: briefingViewModel.isLoading
                )
        }
        .disabled(briefingViewModel.isLoading)
    }

    // MARK: - FAB Button
    private var fabButton: some View {
        Button(action: { showingAddEvent = true }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primary,
                                    DesignSystem.Colors.primaryDark
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: DesignSystem.Colors.primary.opacity(0.4), radius: 12, y: 6)
                )
        }
        .padding(.trailing, DesignSystem.Spacing.lg)
        .padding(.bottom, 100)
    }

    // MARK: - Helper Methods
    private func toggleSection(_ section: String) {
        withAnimation(.spring(response: 0.3)) {
            if expandedSections.contains(section) {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }
    }

    private func isPastEvent(_ event: Event) -> Bool {
        guard let endDate = event.endDate ?? event.startDate else { return false }
        return endDate < Date()
    }
}

// MARK: - Compact Event Row
struct CompactEventRow: View {
    let event: Event
    let isCurrentEvent: Bool
    let isPastEvent: Bool

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            // Time
            if let startDate = event.startDate {
                Text(timeFormatter.string(from: startDate))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(timeColor)
                    .frame(width: 55, alignment: .leading)
            }

            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(event.sourceColorAsColor.opacity(isPastEvent ? 0.4 : 1.0))
                .frame(width: 3, height: 32)

            // Event details
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .foregroundColor(isPastEvent ? DesignSystem.Colors.tertiaryText : DesignSystem.Colors.primaryText)
                    .lineLimit(1)
                    .strikethrough(isPastEvent)

                if isCurrentEvent {
                    Text("Now")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.green)
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            isCurrentEvent ?
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.06))
            : nil
        )
    }

    private var timeColor: Color {
        if isCurrentEvent { return .green }
        if isPastEvent { return DesignSystem.Colors.tertiaryText }
        return DesignSystem.Colors.primaryText
    }
}

// MARK: - Today Health Card (Kept from original)
struct TodayHealthCard: View {
    @ObservedObject private var healthMetricsService = HealthMetricsService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundColor(.white)

                Text("Health Data Access Required")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Clara needs access to your Health data to provide personalized insights.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                Button(action: {
                    HealthAppHelper.openHealthAppSettings()
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Open Settings")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(Color.white)
                    )
                }

                Button(action: {
                    Task {
                        await healthMetricsService.checkAuthorizationStatus()
                        if healthMetricsService.isAuthorized {
                            await HealthSyncService.shared.syncRecentDays()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Check")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                    )
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0.8),
                            Color.orange.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.red.opacity(0.3), radius: 12, y: 4)
        )
    }
}

// MARK: - Local Event Detail Sheet (Kept from original)
struct LocalEventDetailSheet: View {
    let event: Event
    @Environment(\.dismiss) private var dismiss

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Color bar and title
                    VStack(alignment: .leading, spacing: 12) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(event.sourceColorAsColor)
                            .frame(height: 4)

                        Text(event.title)
                            .font(.title.weight(.bold))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }

                    // Date & Time
                    if let startDate = event.startDate {
                        EventDetailRow(icon: "calendar", iconColor: DesignSystem.Colors.primary, title: "Date & Time") {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(dateFormatter.string(from: startDate))
                                    .font(.body)
                                    .foregroundColor(DesignSystem.Colors.primaryText)

                                if event.allDay {
                                    Text("All day")
                                        .font(.subheadline)
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                } else if let endDate = event.endDate {
                                    Text("\(timeFormatter.string(from: startDate)) - \(timeFormatter.string(from: endDate))")
                                        .font(.subheadline)
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                }
                            }
                        }
                    }

                    // Location
                    if let location = event.locationName, !location.isEmpty {
                        EventDetailRow(icon: "mappin.circle.fill", iconColor: .red, title: "Location") {
                            Text(location)
                                .font(.body)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                        }
                    }

                    // Description
                    if let description = event.description, !description.isEmpty {
                        EventDetailRow(icon: "text.alignleft", iconColor: .purple, title: "Description") {
                            Text(description)
                                .font(.body)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                        }
                    }

                    // Calendar source
                    EventDetailRow(icon: "calendar.badge.clock", iconColor: .gray, title: "Calendar") {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(event.sourceColorAsColor)
                                .frame(width: 12, height: 12)
                            Text(event.source.capitalized)
                                .font(.body)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .background(DesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
    }
}

// MARK: - Event Detail Row
struct EventDetailRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title.uppercased())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                    .tracking(0.5)

                content
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

