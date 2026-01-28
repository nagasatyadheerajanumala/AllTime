import SwiftUI

struct TodayView: View {
    @EnvironmentObject var calendarViewModel: CalendarViewModel
    @StateObject private var briefingViewModel = TodayBriefingViewModel()
    @StateObject private var overviewViewModel = TodayOverviewViewModel()
    @StateObject private var timeIntelligenceService = TimeIntelligenceService.shared
    @State private var selectedEvent: Event?
    @State private var showingAddEvent = false
    @ObservedObject private var healthMetricsService = HealthMetricsService.shared
    @ObservedObject private var navigationManager = NavigationManager.shared

    // Sheet presentation states
    @State private var showingSummaryDetail = false
    @State private var showingSuggestionsDetail = false
    @State private var showingTodoDetail = false
    @State private var showingPlanMyDay = false
    @State private var showingNotificationHistory = false
    @State private var selectedClaraPrompt: ClaraPrompt? = nil
    @State private var selectedPrimaryRecommendation: PrimaryRecommendation? = nil

    // Say No / Decline Recommendations
    @State private var selectedDeclineRecommendation: DeclineRecommendationDTO? = nil

    // Week Drift - the killer feature
    @State private var weekDriftStatus: WeekDriftStatus?
    @State private var weekDriftLoading = false

    // Notification history
    @ObservedObject private var notificationHistory = NotificationHistoryService.shared

    // PROGRESSIVE DISCLOSURE: Single-tile expansion manager
    // Only one tile can be expanded at a time, reducing cognitive overload
    @StateObject private var tileExpansionManager = TileExpansionManager()

    // TILE ORDERING: User-customizable tile order with persistence
    @ObservedObject private var tileOrderManager = TodayTileOrderManager.shared

    // Accordion expansion states (kept for compatibility with insights section)
    @State private var expandedSections: Set<String> = []

    // Task management for cancellation
    @State private var loadTask: Task<Void, Never>?

    // DESIGN PHILOSOPHY: Today is the DECISION SURFACE, not a calendar.
    // We answer "What should I do?" not "What's on my schedule?"
    // Schedule listing is deliberately REMOVED - users can see that in Calendar tab.

    private var todayEvents: [Event] {
        calendarViewModel.eventsForToday().sorted { event1, event2 in
            guard let start1 = event1.startDate, let start2 = event2.startDate else { return false }
            return start1 < start2
        }
    }

    /// Count of meetings today (excludes all-day events, focus time, etc.)
    private var todayMeetingCount: Int {
        todayEvents.filter { event in
            // Exclude all-day events
            guard !event.allDay else { return false }
            // Exclude focus time, lunch, breaks, etc.
            let title = event.title.lowercased()
            let nonMeetingKeywords = ["focus", "lunch", "break", "blocked", "hold", "personal", "commute", "travel", "holiday", "birthday", "pto", "vacation", "out of office", "ooo"]
            for keyword in nonMeetingKeywords {
                if title.contains(keyword) { return false }
            }
            return true
        }.count
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

    /// Check if today is a weekend or has a holiday
    private var isWeekendOrHoliday: Bool {
        Calendar.current.isDateInWeekend(Date()) || todayHolidayName != nil
    }

    /// Get the name of today's holiday (if any)
    private var todayHolidayName: String? {
        todayEvents.first { event in
            event.title.lowercased().contains("holiday") ||
            event.allDay && (
                event.title.lowercased().contains("christmas") ||
                event.title.lowercased().contains("thanksgiving") ||
                event.title.lowercased().contains("new year") ||
                event.title.lowercased().contains("independence") ||
                event.title.lowercased().contains("memorial") ||
                event.title.lowercased().contains("labor day") ||
                event.title.lowercased().contains("veterans")
            )
        }?.title
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                // Background
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                // Main scrollable content
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.md) {
                        // Safe area padding
                        Color.clear.frame(height: 8)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Collapse all tiles when tapping empty space
                                tileExpansionManager.collapseAll()
                                if tileOrderManager.isReorderModeActive {
                                    tileOrderManager.exitReorderMode()
                                }
                            }

                        // Reorder mode header (appears when active)
                        ReorderModeHeader()

                        // HERO: Today's Overview Card - All key metrics in one glanceable tile
                        HeroSummaryCard(
                            overview: overviewViewModel.overview,
                            briefing: briefingViewModel.briefing,
                            driftStatus: weekDriftStatus,
                            freshHealth: briefingViewModel.freshHealthMetrics,
                            intelligence: timeIntelligenceService.todayIntelligence,
                            isLoading: weekDriftLoading || overviewViewModel.isLoading || briefingViewModel.isLoading,
                            onTap: { showingSummaryDetail = true },
                            onInterventionTap: handleInterventionTap,
                            fallbackMeetingCount: todayMeetingCount
                        )
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .cardStagger(index: 0)

                        // Reorderable tiles (user-customizable order)
                        ForEach(tileOrderManager.tileOrder, id: \.self) { tileType in
                            renderTile(tileType, index: tileOrderManager.tileOrder.firstIndex(of: tileType) ?? 0)
                        }

                        // Health Access Card (only if not authorized)
                        if !healthMetricsService.isAuthorized {
                            TodayHealthCard()
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .cardStagger(index: tileOrderManager.tileOrder.count + 1)
                        }

                        // Bottom padding for FAB
                        Color.clear.frame(height: 100)
                    }
                }
                .refreshable {
                    // First: Fetch FRESH HealthKit data for immediate display
                    await briefingViewModel.fetchFreshHealthMetrics()

                    // Then: Sync health data to backend
                    await HealthSyncService.shared.syncRecentDays()

                    // Then: Run all refreshes in parallel
                    async let calendarRefresh: () = calendarViewModel.refreshEvents()
                    async let briefingRefresh: () = briefingViewModel.refresh()
                    async let overviewRefresh: () = overviewViewModel.refresh()
                    _ = await (calendarRefresh, briefingRefresh, overviewRefresh)
                }

                // Floating Action Button
                fabButton
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    customizeLayoutButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        notificationHistoryButton
                        refreshButton
                    }
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
                    summaryTile: overviewViewModel.overview?.summaryTile,
                    freshHealthMetrics: briefingViewModel.freshHealthMetrics
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
            .sheet(isPresented: $showingPlanMyDay) {
                PlanMyDayView()
            }
            .sheet(isPresented: $showingNotificationHistory) {
                NotificationHistoryView()
            }
            .sheet(isPresented: $navigationManager.showDayReview) {
                DailyInsightsView()
            }
            .sheet(item: $selectedClaraPrompt) { prompt in
                ClaraPromptSheet(prompt: prompt)
            }
            .sheet(item: $selectedPrimaryRecommendation) { recommendation in
                PrimaryRecommendationActionSheet(
                    recommendation: recommendation,
                    focusWindow: briefingViewModel.briefing?.focusWindows?.first
                )
            }
            .sheet(item: $selectedDeclineRecommendation) { recommendation in
                // Say No Action Sheet - the UNIQUE decline workflow
                DeclineActionSheet(
                    recommendation: recommendation,
                    onDecline: {
                        Task {
                            await timeIntelligenceService.recordDeclineAction(
                                recommendationId: recommendation.recommendationId,
                                action: "declined",
                                wasPositive: true
                            )
                            await timeIntelligenceService.fetchTodayIntelligence()
                        }
                    },
                    onReschedule: {
                        Task {
                            await timeIntelligenceService.recordDeclineAction(
                                recommendationId: recommendation.recommendationId,
                                action: "rescheduled",
                                wasPositive: true
                            )
                            await timeIntelligenceService.fetchTodayIntelligence()
                        }
                    },
                    onDismiss: {
                        Task {
                            await timeIntelligenceService.dismissRecommendation(
                                recommendationId: recommendation.recommendationId
                            )
                            await timeIntelligenceService.fetchTodayIntelligence()
                        }
                    }
                )
            }
            .onAppear {
                // Cancel any existing task
                loadTask?.cancel()

                // Run data loading with health sync FIRST to ensure fresh data
                loadTask = Task {
                    // First: Fetch FRESH HealthKit data for immediate display
                    // This ensures the UI shows exact data from the device, not stale backend data
                    await briefingViewModel.fetchFreshHealthMetrics()

                    // Second: Sync health data to backend (for historical analysis)
                    await HealthSyncService.shared.syncRecentDays()

                    // Then: Load everything in parallel (including week drift AND Time Intelligence)
                    async let calendarTask: () = calendarViewModel.loadEventsForSelectedDate(Date())
                    async let healthTask: () = healthMetricsService.checkAuthorizationStatus()
                    async let briefingTask: () = briefingViewModel.fetchBriefing()
                    async let overviewTask: () = overviewViewModel.fetchOverview()
                    async let driftTask: () = fetchWeekDrift()
                    async let intelligenceTask: () = timeIntelligenceService.fetchTodayIntelligence()

                    // Wait for all to complete (parallel execution)
                    _ = await (calendarTask, healthTask, briefingTask, overviewTask, driftTask, intelligenceTask)
                }
            }
            .onDisappear {
                // Cancel pending requests when view disappears
                loadTask?.cancel()
                loadTask = nil
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EventCreated"))) { _ in
                // Refresh calendar and briefing when an event is created
                print("📅 TodayView: Received EventCreated notification, refreshing data...")
                Task {
                    // Refresh calendar events
                    await calendarViewModel.refreshEvents()
                    // Refresh briefing (recommendations may change based on new events)
                    await briefingViewModel.refresh()
                }
            }
            // Handle action notifications from detail views
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenQuickBook"))) { _ in
                print("📅 TodayView: Received OpenQuickBook notification")
                // Dismiss any open sheets first, then show QuickBook
                showingSummaryDetail = false
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s - faster
                    showingQuickBook = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenPlanMyDay"))) { _ in
                print("📅 TodayView: Received OpenPlanMyDay notification")
                // Dismiss any open sheets first, then show Plan My Day
                showingSummaryDetail = false
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s - faster
                    showingPlanMyDay = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenCalendar"))) { _ in
                print("📅 TodayView: Received OpenCalendar notification")
                // Dismiss any open sheets first, then navigate to Calendar
                showingSummaryDetail = false
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s - faster
                    NavigationManager.shared.navigateToCalendar()
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

    // MARK: - Tile Rendering (Reorderable)
    /// Renders a tile based on its type. Used for user-customizable ordering.
    @ViewBuilder
    private func renderTile(_ tileType: TodayReorderableTile, index: Int) -> some View {
        let _ = {
            if tileType == .primaryRecommendation {
                print("🔍 DO NOW tile check: briefing=\(briefingViewModel.briefing != nil), primaryRec=\(briefingViewModel.briefing?.primaryRecommendation != nil)")
                if let rec = briefingViewModel.briefing?.primaryRecommendation {
                    print("🔍 DO NOW data: action=\(rec.action), urgency=\(rec.urgency ?? "nil")")
                }
            }
        }()
        switch tileType {
        case .primaryRecommendation:
            // REMOVED: Redundant with hero card intervention
            // The hero card now shows the primary action
            EmptyView()

        case .claraPrompts:
            // REMOVED: Redundant with floating Clara button
            EmptyView()

        case .energyBudget:
            if let energyBudget = briefingViewModel.briefing?.energyBudget {
                CollapsibleEnergyBudgetCard(
                    energyBudget: energyBudget,
                    tileId: TileExpansionManager.TileId.energyBudget.rawValue,
                    expansionManager: tileExpansionManager
                )
                .reorderableTile(.energyBudget)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .cardStagger(index: index + 1)
            }

        case .decisionMoments:
            DecisionMomentsCard()
                .reorderableTile(.decisionMoments)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .cardStagger(index: index + 1)

        case .similarWeek:
            SimilarWeekSection()
                .reorderableTile(.similarWeek)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .cardStagger(index: index + 1)

        case .meetingSpots:
            MeetingSpotsSection()
                .reorderableTile(.meetingSpots)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .cardStagger(index: index + 1)

        case .actionsRow:
            CollapsibleActionsRow(
                overview: overviewViewModel.overview,
                briefing: briefingViewModel.briefing,
                isLoading: overviewViewModel.isLoading || briefingViewModel.isLoading,
                expansionManager: tileExpansionManager,
                onSuggestionsTap: { showingSuggestionsDetail = true },
                onTodoTap: { showingTodoDetail = true }
            )
            .reorderableTile(.actionsRow)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .cardStagger(index: index + 1)

        case .upNext:
            UpNextSectionView()
                .reorderableTile(.upNext)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .cardStagger(index: index + 1)

        // Fixed tiles (handled separately, not rendered here)
        case .heroSummary, .criticalHealthAlert, .schedule, .healthAccess:
            EmptyView()
        }
    }

    // MARK: - Briefing Content
    @ViewBuilder
    private func briefingContent(briefing: DailyBriefingResponse) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // (1) PRIMARY RECOMMENDATION - The ONE thing to do today
            // Clara is opinionated - this is THE recommendation, not a suggestion list
            if let primaryRec = briefing.primaryRecommendation {
                PrimaryRecommendationCard(recommendation: primaryRec) {
                    handleDeepLink(primaryRec.deepLink)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }

            // (1.5) RISK + OPPORTUNITY SECTION - 1 Risk + 1 Opportunity model
            // Shows the key intelligence: what's the risk and what's the opportunity
            if briefing.riskInsight != nil || briefing.opportunityInsight != nil {
                RiskOpportunitySectionView(
                    riskInsight: briefing.riskInsight,
                    opportunityInsight: briefing.opportunityInsight,
                    onRiskTap: {
                        // Could open detail sheet or navigate
                    },
                    onOpportunityTap: {
                        if let deepLink = briefing.opportunityInsight?.deepLink {
                            handleDeepLink(deepLink)
                        }
                    }
                )
                .padding(.horizontal, DesignSystem.Spacing.md)
            }

            // (2) Daily Summary Card
            DailySummaryCardView(briefing: briefing)
                .padding(.horizontal, DesignSystem.Spacing.md)

            // (2.5) Clara Prompts - Contextual prompts (not open-ended)
            if let prompts = briefing.claraPrompts, !prompts.isEmpty {
                ClaraPromptsRow(prompts: prompts) { prompt in
                    handleClaraPrompt(prompt)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }

            // (3) Today's Plan Section (Top 3 suggestions)
            if let suggestions = briefing.suggestions, !suggestions.isEmpty {
                TodaysPlanSection(suggestions: suggestions)
                    .padding(.horizontal, DesignSystem.Spacing.md)
            }

            // (4) Health Insights Card - Prominent health data display
            // Uses fresh HealthKit data when available for accurate display
            HealthInsightsCard(
                keyMetrics: briefing.keyMetrics,
                suggestions: briefing.suggestions,
                quickStats: briefing.quickStats,
                freshHealthMetrics: briefingViewModel.freshHealthMetrics
            )
            .padding(.horizontal, DesignSystem.Spacing.md)

            // (5) Quick Stats Row
            QuickStatsRowView(
                quickStats: briefing.quickStats,
                keyMetrics: briefing.keyMetrics
            )
            .padding(.horizontal, DesignSystem.Spacing.md)

            // (6) Energy Budget - Time → Energy Transformation
            if let energyBudget = briefing.energyBudget {
                EnergyBudgetCard(energyBudget: energyBudget)
                    .padding(.horizontal, DesignSystem.Spacing.md)
            }

            // (7) Insights Section (Accordions)
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
                    iconColor: DesignSystem.Colors.amber,
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
                    iconColor: DesignSystem.Colors.amber,
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
                    content: AnyView(DetailedSummaryContent(briefing: briefing, freshHealthMetrics: briefingViewModel.freshHealthMetrics))
                )
            }
        }
    }

    // MARK: - Events Section (DEPRECATED)
    // NOTE: Schedule listing has been INTENTIONALLY REMOVED from the Today tab.
    // The Today tab is a DECISION SURFACE, not a calendar display.
    // Users should view their schedule in the Calendar tab.
    // This code is kept for reference but is no longer used in the main body.
    @available(*, deprecated, message: "Schedule viewing belongs in Calendar tab")
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

    // MARK: - Customize Layout Button
    private var customizeLayoutButton: some View {
        Button(action: {
            if tileOrderManager.isReorderModeActive {
                tileOrderManager.exitReorderMode()
            } else {
                tileOrderManager.enterReorderMode()
            }
        }) {
            Image(systemName: tileOrderManager.isReorderModeActive ? "checkmark" : "square.grid.2x2")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(tileOrderManager.isReorderModeActive ? DesignSystem.Colors.primary : DesignSystem.Colors.secondaryText)
        }
    }

    // MARK: - Notification History Button
    private var notificationHistoryButton: some View {
        Button(action: {
            showingNotificationHistory = true
        }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primary)

                // Unread badge
                if notificationHistory.unreadCount > 0 {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: -4)
                }
            }
        }
    }

    // MARK: - Refresh Button
    @State private var refreshRotation: Double = 0

    private var refreshButton: some View {
        Button(action: {
            Task { await briefingViewModel.refresh() }
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignSystem.Colors.primary)
                .rotationEffect(.degrees(refreshRotation))
        }
        .disabled(briefingViewModel.isLoading)
        .onChange(of: briefingViewModel.isLoading) { _, isLoading in
            if isLoading {
                // Single rotation animation instead of infinite
                withAnimation(.linear(duration: 0.8)) {
                    refreshRotation += 360
                }
            }
        }
    }

    // MARK: - FAB Buttons
    @State private var showFABMenu = false
    @State private var showingAddTask = false
    @State private var showingAddReminder = false
    @State private var showingQuickPick = false
    @State private var showingQuickBook = false
    @State private var generatedWeekendPlan: WeekendPlanResponse?

    private var fabButton: some View {
        ZStack(alignment: .bottomTrailing) {
            // Dimmed background when FAB menu is open
            if showFABMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            showFABMenu = false
                        }
                    }
            }

            VStack(alignment: .trailing, spacing: 12) {
                if showFABMenu {
                    // Weekend: Plan My Weekend / Quick Pick
                    if isWeekendOrHoliday {
                        fabMenuItem(
                            icon: "sparkles",
                            label: "Plan My Weekend",
                            color: Color(hex: "EC4899")
                        ) {
                            showFABMenu = false
                            showingQuickPick = true
                        }
                    }

                    // Add Reminder
                    fabMenuItem(
                        icon: "bell.fill",
                        label: "Add Reminder",
                        color: DesignSystem.Colors.amber
                    ) {
                        showFABMenu = false
                        showingAddReminder = true
                    }

                    // Add Event
                    fabMenuItem(
                        icon: "calendar.badge.plus",
                        label: "Add Event",
                        color: DesignSystem.Colors.blue
                    ) {
                        showFABMenu = false
                        showingAddEvent = true
                    }

                    // Quick Book - PROTECT YOUR TIME
                    fabMenuItem(
                        icon: "shield.fill",
                        label: "Quick Book",
                        color: DesignSystem.Colors.emerald
                    ) {
                        showFABMenu = false
                        showingQuickBook = true
                    }

                    // Plan My Day
                    fabMenuItem(
                        icon: "wand.and.stars",
                        label: "Plan My Day",
                        color: DesignSystem.Colors.violet
                    ) {
                        showFABMenu = false
                        showingPlanMyDay = true
                    }
                }

                // Main FAB button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showFABMenu.toggle()
                    }
                }) {
                    Image(systemName: showFABMenu ? "xmark" : "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: showFABMenu ? [Color(hex: "6B7280"), Color(hex: "4B5563")] : [
                                            DesignSystem.Colors.primary,
                                            DesignSystem.Colors.primaryDark
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: (showFABMenu ? Color(hex: "6B7280") : DesignSystem.Colors.primary).opacity(0.4), radius: 12, y: 6)
                        )
                        .rotationEffect(.degrees(showFABMenu ? 90 : 0))
                }
            }
            .padding(.trailing, DesignSystem.Spacing.lg)
            .padding(.bottom, 160) // Above Clara FAB button
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskSheet()
        }
        .sheet(isPresented: $showingAddReminder) {
            AddReminderSheet()
        }
        .sheet(isPresented: $showingQuickPick) {
            WeekendQuickPickView { plan in
                generatedWeekendPlan = plan
            }
        }
        .sheet(item: $generatedWeekendPlan) { plan in
            WeekendPlanResultView(plan: plan)
        }
        .sheet(isPresented: $showingQuickBook) {
            QuickBookView()
        }
    }

    private func fabMenuItem(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.cardBackground)
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    )

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(color)
                            .shadow(color: color.opacity(0.4), radius: 6, y: 3)
                    )
            }
        }
        .transition(.asymmetric(
            insertion: .scale(scale: 0.5).combined(with: .opacity).combined(with: .move(edge: .trailing)),
            removal: .scale(scale: 0.5).combined(with: .opacity)
        ))
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

    // MARK: - Week Drift (Killer Feature)

    /// Fetch week drift status - the forward-looking intelligence
    private func fetchWeekDrift() async {
        await MainActor.run { weekDriftLoading = true }

        do {
            let status = try await APIService.shared.getWeekDriftStatus()
            await MainActor.run {
                weekDriftStatus = status
                weekDriftLoading = false
            }
            print("🎯 TodayView: Week drift loaded - score=\(status.driftScore), severity=\(status.severity)")
        } catch {
            print("⚠️ TodayView: Failed to load week drift: \(error)")
            await MainActor.run { weekDriftLoading = false }
        }
    }

    /// Handle intervention taps - navigate to the action deep link
    private func handleInterventionTap(_ intervention: DriftIntervention) {
        print("🎯 TodayView: Intervention tapped - \(intervention.id): \(intervention.action)")

        // Handle common intervention types directly
        let id = intervention.id.lowercased()
        let action = intervention.action.lowercased()

        if id.contains("block") || id.contains("focus") || id.contains("deep_work") ||
           action.contains("block") || action.contains("focus") {
            // Open Plan My Day for blocking time
            showingPlanMyDay = true
        } else if id.contains("decline") || id.contains("cancel") || action.contains("decline") {
            // Navigate to calendar for meeting management
            NavigationManager.shared.navigateToCalendar()
        } else if id.contains("reschedule") || id.contains("move") {
            NavigationManager.shared.navigateToCalendar()
        } else if !intervention.deepLink.isEmpty {
            NavigationManager.shared.handleDestination(intervention.deepLink)
        } else {
            // Default: show Plan My Day
            showingPlanMyDay = true
        }
    }

    /// Handle deep link navigation from primary recommendation
    private func handleDeepLink(_ deepLink: String?) {
        // If no deep link, show the action sheet for the recommendation
        if deepLink == nil || deepLink?.isEmpty == true {
            if let rec = briefingViewModel.briefing?.primaryRecommendation {
                selectedPrimaryRecommendation = rec
            }
            return
        }

        guard let link = deepLink else { return }
        print("🔗 TodayView: Deep link tapped - \(link)")

        // Handle various deep link formats
        if link.starts(with: "block_time") || link.starts(with: "protect_time") {
            // Show Plan My Day for time blocking
            showingPlanMyDay = true
        } else if link.starts(with: "reschedule") || link.starts(with: "move_meeting") {
            // Navigate to calendar
            NavigationManager.shared.navigateToCalendar()
        } else if link.starts(with: "health") || link.starts(with: "recovery") {
            // Navigate to health
            NavigationManager.shared.navigateToHealth()
        } else if link.starts(with: "cancel") || link.starts(with: "decline") {
            // Show calendar for meeting management
            NavigationManager.shared.navigateToCalendar()
        } else {
            // Try standard navigation
            NavigationManager.shared.handleDestination(link)
        }
    }

    /// Handle Clara prompt taps - opens Clara prompt sheet
    private func handleClaraPrompt(_ prompt: ClaraPrompt) {
        print("🗣️ TodayView: Clara prompt tapped - \(prompt.label ?? "unknown")")
        selectedClaraPrompt = prompt
    }
}
