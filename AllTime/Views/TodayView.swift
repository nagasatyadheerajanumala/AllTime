import SwiftUI

struct TodayView: View {
    @EnvironmentObject var calendarViewModel: CalendarViewModel
    @StateObject private var briefingViewModel = TodayBriefingViewModel()
    @StateObject private var overviewViewModel = TodayOverviewViewModel()
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

    // Week Drift - the killer feature
    @State private var weekDriftStatus: WeekDriftStatus?
    @State private var weekDriftLoading = false

    // Notification history
    @ObservedObject private var notificationHistory = NotificationHistoryService.shared

    // Accordion expansion states (kept for compatibility)
    @State private var expandedSections: Set<String> = []

    // Task management for cancellation
    @State private var loadTask: Task<Void, Never>?

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
                    VStack(spacing: DesignSystem.Spacing.md) {
                        // Safe area padding
                        Color.clear.frame(height: 8)

                        // SECTION 1: Hero Summary Card (DECISION ENGINE)
                        // The heart of Clara - opinionated, forward-looking, action-oriented
                        HeroSummaryCard(
                            overview: overviewViewModel.overview,
                            briefing: briefingViewModel.briefing,
                            driftStatus: weekDriftStatus,
                            isLoading: weekDriftLoading || overviewViewModel.isLoading || briefingViewModel.isLoading,
                            onTap: { showingSummaryDetail = true },
                            onInterventionTap: handleInterventionTap
                        )
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .cardStagger(index: 0)

                        // SECTION 1.1: PRIMARY RECOMMENDATION - The ONE thing to do today
                        // Clara is opinionated - this is THE recommendation, not a suggestion list
                        if let primaryRec = briefingViewModel.briefing?.primaryRecommendation {
                            PrimaryRecommendationCard(recommendation: primaryRec) {
                                selectedPrimaryRecommendation = primaryRec
                            }
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .cardStagger(index: 1)
                        }

                        // SECTION 1.15: Clara Prompts - Contextual prompts (not open-ended)
                        // Right below Clara's recommendation
                        if let prompts = briefingViewModel.briefing?.claraPrompts, !prompts.isEmpty {
                            ClaraPromptsRow(prompts: prompts) { prompt in
                                handleClaraPrompt(prompt)
                            }
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .cardStagger(index: 2)
                        }

                        // SECTION 1.2: Energy Budget - Time → Energy Transformation
                        // Shows capacity, peak/low windows
                        if let energyBudget = briefingViewModel.briefing?.energyBudget {
                            EnergyBudgetCard(energyBudget: energyBudget)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .cardStagger(index: 3)
                        }

                        // SECTION 1.25: Decision Moments (ACTION CENTER)
                        // Proactive decisions that need user attention - the heart of the decision engine
                        DecisionMomentsCard()
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .cardStagger(index: 3)

                        // SECTION 1.5: Similar Week Alert (pattern prediction)
                        // Shows when this week matches a historical week pattern
                        SimilarWeekSection()
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .cardStagger(index: 4)

                        // SECTION 1.6: Meeting Spots (lunch/coffee near upcoming meeting)
                        // Shows spots near your next meeting with a location
                        MeetingSpotsSection()
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .cardStagger(index: 5)

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
                        .cardStagger(index: 6)

                        // SECTION 3: Plan Your Day (UpNext)
                        // Task management and intelligent suggestions
                        UpNextSectionView()
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .cardStagger(index: 7)

                        // SECTION 4: Schedule (CONDITIONAL)
                        // Only show if there are events today
                        if !todayEvents.isEmpty {
                            eventsSection
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .cardStagger(index: 9)
                        }

                        // Health Access Card (if not authorized)
                        if !healthMetricsService.isAuthorized {
                            TodayHealthCard()
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .cardStagger(index: 8)
                        }

                        // Bottom padding for FAB
                        Color.clear.frame(height: 100)
                    }
                }
                .refreshable {
                    // First: Sync fresh health data to backend
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
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
            .sheet(isPresented: $showingPlanMyDay) {
                PlanMyDayView()
            }
            .sheet(isPresented: $showingNotificationHistory) {
                NotificationHistoryView()
            }
            .sheet(isPresented: $navigationManager.showDayReview) {
                DayReviewView()
            }
            .sheet(item: $selectedClaraPrompt) { prompt in
                ClaraPromptSheet(prompt: prompt)
            }
            .sheet(item: $selectedPrimaryRecommendation) { recommendation in
                PrimaryRecommendationActionSheet(recommendation: recommendation)
            }
            .onAppear {
                // Cancel any existing task
                loadTask?.cancel()

                // Run data loading with health sync FIRST to ensure fresh data
                loadTask = Task {
                    // First: Sync health data to backend (clears cache, gets fresh HealthKit data)
                    // This ensures the briefing will have the latest health metrics
                    await HealthSyncService.shared.syncRecentDays()

                    // Then: Load everything in parallel (including week drift - the killer feature)
                    async let calendarTask: () = calendarViewModel.loadEventsForSelectedDate(Date())
                    async let healthTask: () = healthMetricsService.checkAuthorizationStatus()
                    async let briefingTask: () = briefingViewModel.fetchBriefing()
                    async let overviewTask: () = overviewViewModel.fetchOverview()
                    async let driftTask: () = fetchWeekDrift()

                    // Wait for all to complete (parallel execution)
                    _ = await (calendarTask, healthTask, briefingTask, overviewTask, driftTask)
                }
            }
            .onDisappear {
                // Cancel pending requests when view disappears
                loadTask?.cancel()
                loadTask = nil
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
            // (1) PRIMARY RECOMMENDATION - The ONE thing to do today
            // Clara is opinionated - this is THE recommendation, not a suggestion list
            if let primaryRec = briefing.primaryRecommendation {
                PrimaryRecommendationCard(recommendation: primaryRec) {
                    handleDeepLink(primaryRec.deepLink)
                }
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

    // MARK: - FAB Buttons
    @State private var showFABMenu = false
    @State private var showingAddTask = false
    @State private var showingAddReminder = false

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
                // Expandable menu options
                if showFABMenu {
                    // Plan My Day option
                    fabMenuItem(
                        icon: "wand.and.stars",
                        label: "Plan My Day",
                        color: Color(hex: "8B5CF6")
                    ) {
                        showFABMenu = false
                        showingPlanMyDay = true
                    }

                    // Add Reminder option
                    fabMenuItem(
                        icon: "bell.fill",
                        label: "Add Reminder",
                        color: Color(hex: "F59E0B")
                    ) {
                        showFABMenu = false
                        showingAddReminder = true
                    }

                    // Add Task option
                    fabMenuItem(
                        icon: "checkmark.circle.fill",
                        label: "Add Task",
                        color: Color(hex: "10B981")
                    ) {
                        showFABMenu = false
                        showingAddTask = true
                    }

                    // Add Event option
                    fabMenuItem(
                        icon: "calendar.badge.plus",
                        label: "Add Event",
                        color: Color(hex: "3B82F6")
                    ) {
                        showFABMenu = false
                        showingAddEvent = true
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
            .padding(.bottom, 100)
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskSheet()
        }
        .sheet(isPresented: $showingAddReminder) {
            AddReminderSheet()
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
        NavigationManager.shared.handleDestination(intervention.deepLink)
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

// MARK: - Clara Chat Sheet
struct ClaraPromptSheet: View {
    let prompt: ClaraPrompt
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ClaraChatMessage] = []
    @State private var isTyping = false
    @State private var hasAsked = false
    @State private var followUpText = ""
    @State private var sessionId: String? = nil
    @State private var errorMessage: String? = nil
    @FocusState private var isInputFocused: Bool

    // Clara gradient
    private let claraGradient = LinearGradient(
        colors: [Color(hex: "8B5CF6"), Color(hex: "A855F7"), Color(hex: "7C3AED")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Chat messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                // Initial greeting from Clara
                                ClaraChatBubble(
                                    message: "Hi! I'm Clara, your AI assistant. How can I help you today?",
                                    isClara: true
                                )
                                .id("greeting")

                                // User's question (shown after tapping Ask)
                                ForEach(messages) { message in
                                    ClaraChatBubble(
                                        message: message.content,
                                        isClara: message.isClara
                                    )
                                    .id(message.id)
                                }

                                // Typing indicator
                                if isTyping {
                                    ClaraTypingIndicator()
                                        .id("typing")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                        }
                        .onChange(of: messages.count) { _, _ in
                            withAnimation {
                                if let lastId = messages.last?.id {
                                    proxy.scrollTo(lastId, anchor: .bottom)
                                } else {
                                    proxy.scrollTo("greeting", anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: isTyping) { _, newValue in
                            if newValue {
                                withAnimation {
                                    proxy.scrollTo("typing", anchor: .bottom)
                                }
                            }
                        }
                    }

                    Divider()

                    // Bottom action area
                    VStack(spacing: 12) {
                        if !hasAsked {
                            // Show the prompt as a suggestion
                            Button(action: askClara) {
                                HStack(spacing: 10) {
                                    Image(systemName: prompt.displayIcon)
                                        .font(.system(size: 14))
                                        .foregroundColor(prompt.categoryColor)

                                    Text(prompt.label ?? "Ask Clara")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(DesignSystem.Colors.primaryText)

                                    Spacer()

                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(hex: "8B5CF6"))
                                }
                                .padding(14)
                                .background(DesignSystem.Colors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color(hex: "8B5CF6").opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        } else {
                            // Real text field for follow-up questions
                            HStack(spacing: 12) {
                                TextField("Type a follow-up...", text: $followUpText)
                                    .font(.system(size: 15))
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                    .focused($isInputFocused)
                                    .submitLabel(.send)
                                    .onSubmit {
                                        if !followUpText.isEmpty {
                                            sendFollowUp()
                                        }
                                    }

                                Button(action: sendFollowUp) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(followUpText.isEmpty ? DesignSystem.Colors.tertiaryText : Color(hex: "8B5CF6"))
                                }
                                .disabled(followUpText.isEmpty || isTyping)
                            }
                            .padding(14)
                            .background(DesignSystem.Colors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(isInputFocused ? Color(hex: "8B5CF6").opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(DesignSystem.Colors.background)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(claraGradient)
                                .frame(width: 28, height: 28)
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Text("Clara")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: "8B5CF6"))
                }
            }
        }
    }

    private func askClara() {
        hasAsked = true
        errorMessage = nil

        // Add user message
        let userMessageText = prompt.fullPrompt ?? prompt.label ?? "Help me with this"
        let userMessage = ClaraChatMessage(
            content: userMessageText,
            isClara: false
        )
        messages.append(userMessage)

        // Show typing indicator
        isTyping = true

        // Call the real Clara API
        Task {
            do {
                let response = try await ClaraService.shared.chat(
                    message: userMessageText,
                    sessionId: sessionId
                )

                await MainActor.run {
                    isTyping = false
                    sessionId = response.sessionId

                    let claraMessage = ClaraChatMessage(content: response.response, isClara: true)
                    messages.append(claraMessage)
                }
            } catch {
                await MainActor.run {
                    isTyping = false
                    errorMessage = error.localizedDescription

                    // Fallback message when API fails
                    let fallbackMessage = ClaraChatMessage(
                        content: "I'm having trouble connecting right now. Please try again in a moment.",
                        isClara: true
                    )
                    messages.append(fallbackMessage)
                }
                print("❌ Clara chat error: \(error)")
            }
        }
    }

    private func sendFollowUp() {
        guard !followUpText.isEmpty else { return }
        errorMessage = nil

        let userQuestion = followUpText
        followUpText = ""
        isInputFocused = false

        // Add user message
        let userMessage = ClaraChatMessage(content: userQuestion, isClara: false)
        messages.append(userMessage)

        // Show typing indicator
        isTyping = true

        // Call the real Clara API with conversation continuity
        Task {
            do {
                let response = try await ClaraService.shared.chat(
                    message: userQuestion,
                    sessionId: sessionId
                )

                await MainActor.run {
                    isTyping = false
                    sessionId = response.sessionId

                    let claraMessage = ClaraChatMessage(content: response.response, isClara: true)
                    messages.append(claraMessage)
                }
            } catch {
                await MainActor.run {
                    isTyping = false
                    errorMessage = error.localizedDescription

                    // Fallback message when API fails
                    let fallbackMessage = ClaraChatMessage(
                        content: "I'm having trouble connecting right now. Please try again in a moment.",
                        isClara: true
                    )
                    messages.append(fallbackMessage)
                }
                print("❌ Clara follow-up error: \(error)")
            }
        }
    }
}

// MARK: - Chat Message Model
struct ClaraChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isClara: Bool
}

// MARK: - Chat Bubble
struct ClaraChatBubble: View {
    let message: String
    let isClara: Bool

    private let claraGradient = LinearGradient(
        colors: [Color(hex: "8B5CF6"), Color(hex: "A855F7")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isClara {
                // Clara avatar
                ZStack {
                    Circle()
                        .fill(claraGradient)
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Clara message
                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .padding(14)
                    .background(DesignSystem.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .clipShape(ChatBubbleShape(isFromUser: false))

                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)

                // User message
                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(14)
                    .background(claraGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .clipShape(ChatBubbleShape(isFromUser: true))
            }
        }
    }
}

// MARK: - Chat Bubble Shape
struct ChatBubbleShape: Shape {
    let isFromUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18

        var path = Path()

        if isFromUser {
            // User bubble - rounded except bottom right
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: radius, height: radius))
        } else {
            // Clara bubble - rounded except bottom left
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: radius, height: radius))
        }

        return path
    }
}

// MARK: - Typing Indicator
struct ClaraTypingIndicator: View {
    @State private var animatingDot = 0

    private let claraGradient = LinearGradient(
        colors: [Color(hex: "8B5CF6"), Color(hex: "A855F7")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Clara avatar
            ZStack {
                Circle()
                    .fill(claraGradient)
                    .frame(width: 32, height: 32)
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }

            // Typing dots
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color(hex: "8B5CF6").opacity(animatingDot == index ? 1 : 0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animatingDot == index ? 1.2 : 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        animatingDot = (animatingDot + 1) % 3
                    }
                }
            }

            Spacer()
        }
    }
}

// MARK: - Scale Button Style (if not already defined)
extension View {
    @ViewBuilder
    func scaleButtonEffect() -> some View {
        self.buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Primary Recommendation Action Sheet
struct PrimaryRecommendationActionSheet: View {
    let recommendation: PrimaryRecommendation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(recommendation.urgencyColor.opacity(0.15))
                                    .frame(width: 72, height: 72)

                                Image(systemName: recommendation.displayIcon)
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundColor(recommendation.urgencyColor)
                            }

                            VStack(spacing: 8) {
                                Text(recommendation.urgencyLabel)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(recommendation.urgencyColor)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(recommendation.urgencyColor.opacity(0.15))
                                    .clipShape(Capsule())

                                Text(recommendation.action)
                                    .font(.title2.weight(.semibold))
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, DesignSystem.Spacing.lg)

                        // Reason
                        if let reason = recommendation.reason, !reason.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Why this matters")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                                    .textCase(.uppercase)

                                Text(reason)
                                    .font(.body)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                    .padding(DesignSystem.Spacing.md)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(DesignSystem.Colors.cardBackground)
                                    .cornerRadius(DesignSystem.CornerRadius.md)
                            }
                            .padding(.horizontal, DesignSystem.Spacing.md)
                        }

                        // Consequence warning
                        if let consequence = recommendation.ignoredConsequence, !consequence.isEmpty {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: "F59E0B"))

                                Text(consequence)
                                    .font(.subheadline)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                            }
                            .padding(DesignSystem.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: "F59E0B").opacity(0.1))
                            .cornerRadius(DesignSystem.CornerRadius.md)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                        }

                        Spacer(minLength: 60)

                        // Action buttons
                        VStack(spacing: 12) {
                            Button(action: {
                                takeAction()
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Take Action")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(DesignSystem.Spacing.md)
                                .background(recommendation.urgencyColor)
                                .foregroundColor(.white)
                                .cornerRadius(DesignSystem.CornerRadius.md)
                            }

                            Button(action: { dismiss() }) {
                                Text("Remind Me Later")
                                    .font(.subheadline)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.bottom, DesignSystem.Spacing.lg)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
    }

    private func takeAction() {
        // Navigate based on recommendation category
        switch (recommendation.category ?? "").lowercased() {
        case "protect_time":
            // Could trigger time blocking flow
            print("🎯 Taking action: Protect time")
        case "reduce_load":
            NavigationManager.shared.navigateToCalendar()
        case "health", "movement":
            NavigationManager.shared.navigateToHealth()
        case "catch_up":
            NavigationManager.shared.navigateToReminders()
        default:
            break
        }
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

// MARK: - Add Task Sheet
struct AddTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var dueDate: Date = Date()
    @State private var hasDueDate = false
    @State private var hasDeadline = false
    @State private var deadlineTime: Date = Date()
    @State private var priority: TaskPriority = .medium
    @State private var estimatedMinutes: Int = 30
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var hasReminder = false
    @State private var reminderMinutesBefore: Int = 15

    enum ReminderTiming: Int, CaseIterable {
        case atTime = 0
        case fiveMinutes = 5
        case fifteenMinutes = 15
        case thirtyMinutes = 30
        case oneHour = 60
        case twoHours = 120

        var displayName: String {
            switch self {
            case .atTime: return "At deadline"
            case .fiveMinutes: return "5 min before"
            case .fifteenMinutes: return "15 min before"
            case .thirtyMinutes: return "30 min before"
            case .oneHour: return "1 hour before"
            case .twoHours: return "2 hours before"
            }
        }
    }

    enum TaskPriority: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case urgent = "Urgent"

        var color: Color {
            switch self {
            case .low: return Color(hex: "6B7280")
            case .medium: return Color(hex: "3B82F6")
            case .high: return Color(hex: "F59E0B")
            case .urgent: return Color(hex: "EF4444")
            }
        }

        var icon: String {
            switch self {
            case .low: return "flag"
            case .medium: return "flag.fill"
            case .high: return "flag.fill"
            case .urgent: return "exclamationmark.triangle.fill"
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Title Card
                        formCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Task")
                                    .font(.subheadline)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)

                                TextField("What do you need to do?", text: $title)
                                    .font(.body)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                    .padding(DesignSystem.Spacing.md)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(DesignSystem.CornerRadius.md)
                            }
                        }

                        // Priority Card
                        formCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Priority")
                                    .font(.subheadline)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)

                                HStack(spacing: 8) {
                                    ForEach(TaskPriority.allCases, id: \.self) { p in
                                        Button(action: { priority = p }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: p.icon)
                                                    .font(.caption)
                                                Text(p.rawValue)
                                                    .font(.caption.weight(.medium))
                                            }
                                            .foregroundColor(priority == p ? .white : p.color)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(priority == p ? p.color : p.color.opacity(0.15))
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        // Due Date Card
                        formCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Toggle(isOn: $hasDueDate) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "calendar")
                                            .foregroundColor(Color(hex: "3B82F6"))
                                        Text("Due Date")
                                            .font(.subheadline)
                                            .foregroundColor(DesignSystem.Colors.primaryText)
                                    }
                                }
                                .toggleStyle(.switch)

                                if hasDueDate {
                                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                                        .datePickerStyle(.graphical)
                                        .padding(.top, 8)
                                }
                            }
                        }

                        // Deadline Time Card
                        formCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Toggle(isOn: $hasDeadline) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "clock.fill")
                                            .foregroundColor(Color(hex: "EF4444"))
                                        Text("Must finish by")
                                            .font(.subheadline)
                                            .foregroundColor(DesignSystem.Colors.primaryText)
                                    }
                                }
                                .toggleStyle(.switch)

                                if hasDeadline {
                                    DatePicker("Deadline", selection: $deadlineTime, displayedComponents: [.date, .hourAndMinute])
                                        .datePickerStyle(.compact)
                                        .padding(.top, 4)
                                }
                            }
                        }

                        // Reminder Notification Card (only show if deadline is set)
                        if hasDeadline {
                            formCard {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                    Toggle(isOn: $hasReminder) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "bell.fill")
                                                .foregroundColor(Color(hex: "8B5CF6"))
                                            Text("Remind Me")
                                                .font(.subheadline)
                                                .foregroundColor(DesignSystem.Colors.primaryText)
                                        }
                                    }
                                    .toggleStyle(.switch)

                                    if hasReminder {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                ForEach(ReminderTiming.allCases, id: \.rawValue) { timing in
                                                    Button(action: { reminderMinutesBefore = timing.rawValue }) {
                                                        Text(timing.displayName)
                                                            .font(.caption.weight(.medium))
                                                            .foregroundColor(reminderMinutesBefore == timing.rawValue ? .white : DesignSystem.Colors.primaryText)
                                                            .padding(.horizontal, 10)
                                                            .padding(.vertical, 6)
                                                            .background(
                                                                Capsule()
                                                                    .fill(reminderMinutesBefore == timing.rawValue ? Color(hex: "8B5CF6") : Color(hex: "8B5CF6").opacity(0.15))
                                                            )
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.top, 4)
                                    }
                                }
                            }
                        }

                        // Estimated Time Card
                        formCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                HStack(spacing: 8) {
                                    Image(systemName: "hourglass")
                                        .foregroundColor(Color(hex: "8B5CF6"))
                                    Text("Estimated Time")
                                        .font(.subheadline)
                                        .foregroundColor(DesignSystem.Colors.primaryText)
                                    Spacer()
                                    Text("\(estimatedMinutes) min")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(DesignSystem.Colors.primary)
                                }

                                HStack(spacing: 8) {
                                    ForEach([15, 30, 45, 60, 90, 120], id: \.self) { mins in
                                        Button(action: { estimatedMinutes = mins }) {
                                            Text(mins < 60 ? "\(mins)m" : "\(mins/60)h")
                                                .font(.caption.weight(.medium))
                                                .foregroundColor(estimatedMinutes == mins ? .white : DesignSystem.Colors.primaryText)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(
                                                    Capsule()
                                                        .fill(estimatedMinutes == mins ? Color(hex: "8B5CF6") : Color(hex: "8B5CF6").opacity(0.15))
                                                )
                                        }
                                    }
                                }
                            }
                        }

                        // Notes Card
                        formCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Notes")
                                    .font(.subheadline)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)

                                TextEditor(text: $notes)
                                    .font(.body)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                    .frame(minHeight: 80)
                                    .padding(8)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(DesignSystem.CornerRadius.md)
                            }
                        }

                        // Save Button
                        Button(action: saveTask) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text(isSaving ? "Saving..." : "Add Task")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(DesignSystem.Spacing.md)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "10B981"), Color(hex: "059669")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                            .shadow(color: Color(hex: "10B981").opacity(0.4), radius: 12, y: 6)
                        }
                        .disabled(title.isEmpty || isSaving)
                        .opacity(title.isEmpty ? 0.6 : 1.0)
                        .padding(.horizontal, DesignSystem.Spacing.md)

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }

                        Spacer(minLength: 50)
                    }
                    .padding(DesignSystem.Spacing.md)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
        }
    }

    @ViewBuilder
    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.lg)
    }

    private func saveTask() {
        guard !title.isEmpty else { return }
        isSaving = true
        errorMessage = nil

        Task {
            do {
                // Build task request
                // Always set targetDate to today so task appears in today's list
                // Determine deadline type based on user choices
                let deadlineType: String?
                if hasDeadline {
                    deadlineType = "SPECIFIC_TIME"
                } else if hasDueDate {
                    deadlineType = "END_OF_DAY"
                } else {
                    deadlineType = "NO_DEADLINE"
                }

                // Use the deadline time, or end of due date if only due date is set
                let effectiveDeadline: Date?
                if hasDeadline {
                    effectiveDeadline = deadlineTime
                } else if hasDueDate {
                    // Set deadline to end of the due date (11:59 PM)
                    effectiveDeadline = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: dueDate)
                } else {
                    effectiveDeadline = nil
                }

                let taskRequest = TaskRequest(
                    title: title,
                    description: notes.isEmpty ? nil : notes,
                    durationMinutes: estimatedMinutes,
                    preferredTimeSlot: nil,
                    preferredTime: nil,
                    targetDate: hasDueDate ? dueDate : Date(), // Default to today
                    deadline: effectiveDeadline,
                    deadlineType: deadlineType,
                    notifyMinutesBefore: (hasDeadline && hasReminder) ? reminderMinutesBefore : nil,
                    isReminder: nil,
                    reminderTime: nil,
                    syncToReminders: nil,
                    priority: priority.rawValue.uppercased(),
                    category: nil,
                    tags: nil,
                    source: "ios_fab"
                )

                let _ = try await APIService.shared.createTask(taskRequest)

                await MainActor.run {
                    isSaving = false
                    // Post notification for UI to refresh tasks
                    NotificationCenter.default.post(name: NSNotification.Name("TaskCreated"), object: nil)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save task: \(error.localizedDescription)"
                    print("❌ Failed to create task: \(error)")
                }
            }
        }
    }
}

// MARK: - Add Reminder Sheet
struct AddReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var reminderDate: Date = Date()
    @State private var hasTime = true
    @State private var repeatOption: RepeatOption = .never
    @State private var isSaving = false
    @State private var errorMessage: String?

    enum RepeatOption: String, CaseIterable {
        case never = "Never"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"

        var icon: String {
            switch self {
            case .never: return "arrow.right"
            case .daily: return "sun.max.fill"
            case .weekly: return "calendar.badge.clock"
            case .monthly: return "calendar"
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Title Card
                        formCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Reminder")
                                    .font(.subheadline)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)

                                TextField("What do you want to be reminded of?", text: $title)
                                    .font(.body)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                    .padding(DesignSystem.Spacing.md)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(DesignSystem.CornerRadius.md)
                            }
                        }

                        // Date & Time Card
                        formCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                HStack(spacing: 8) {
                                    Image(systemName: "bell.fill")
                                        .foregroundColor(Color(hex: "F59E0B"))
                                    Text("Remind me on")
                                        .font(.subheadline)
                                        .foregroundColor(DesignSystem.Colors.primaryText)
                                }

                                DatePicker("", selection: $reminderDate, displayedComponents: hasTime ? [.date, .hourAndMinute] : [.date])
                                    .datePickerStyle(.graphical)

                                Toggle(isOn: $hasTime) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "clock")
                                            .foregroundColor(DesignSystem.Colors.secondaryText)
                                        Text("Include time")
                                            .font(.subheadline)
                                            .foregroundColor(DesignSystem.Colors.primaryText)
                                    }
                                }
                                .toggleStyle(.switch)
                            }
                        }

                        // Quick Time Options
                        formCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Quick Set")
                                    .font(.subheadline)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)

                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    quickSetButton("In 1 hour", addHours: 1)
                                    quickSetButton("In 3 hours", addHours: 3)
                                    quickSetButton("Tomorrow 9 AM", tomorrow: true)
                                    quickSetButton("This weekend", weekend: true)
                                }
                            }
                        }

                        // Repeat Card
                        formCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Repeat")
                                    .font(.subheadline)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)

                                HStack(spacing: 8) {
                                    ForEach(RepeatOption.allCases, id: \.self) { option in
                                        Button(action: { repeatOption = option }) {
                                            VStack(spacing: 4) {
                                                Image(systemName: option.icon)
                                                    .font(.system(size: 16))
                                                Text(option.rawValue)
                                                    .font(.caption2)
                                            }
                                            .foregroundColor(repeatOption == option ? .white : DesignSystem.Colors.primaryText)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(repeatOption == option ? Color(hex: "F59E0B") : Color(hex: "F59E0B").opacity(0.15))
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        // Notes Card
                        formCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Notes")
                                    .font(.subheadline)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)

                                TextEditor(text: $notes)
                                    .font(.body)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                    .frame(minHeight: 60)
                                    .padding(8)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(DesignSystem.CornerRadius.md)
                            }
                        }

                        // Save Button
                        Button(action: saveReminder) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "bell.badge.fill")
                                }
                                Text(isSaving ? "Saving..." : "Set Reminder")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(DesignSystem.Spacing.md)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "F59E0B"), Color(hex: "D97706")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                            .shadow(color: Color(hex: "F59E0B").opacity(0.4), radius: 12, y: 6)
                        }
                        .disabled(title.isEmpty || isSaving)
                        .opacity(title.isEmpty ? 0.6 : 1.0)
                        .padding(.horizontal, DesignSystem.Spacing.md)

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }

                        Spacer(minLength: 50)
                    }
                    .padding(DesignSystem.Spacing.md)
                }
            }
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
        }
    }

    @ViewBuilder
    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.lg)
    }

    private func quickSetButton(_ label: String, addHours: Int? = nil, tomorrow: Bool = false, weekend: Bool = false) -> some View {
        Button(action: {
            let calendar = Calendar.current
            if let hours = addHours {
                reminderDate = calendar.date(byAdding: .hour, value: hours, to: Date()) ?? Date()
            } else if tomorrow {
                var components = calendar.dateComponents([.year, .month, .day], from: Date())
                components.day! += 1
                components.hour = 9
                components.minute = 0
                reminderDate = calendar.date(from: components) ?? Date()
            } else if weekend {
                // Find next Saturday
                let today = Date()
                let weekday = calendar.component(.weekday, from: today)
                let daysUntilSaturday = (7 - weekday + 7) % 7
                var components = calendar.dateComponents([.year, .month, .day], from: today)
                components.day! += daysUntilSaturday == 0 ? 7 : daysUntilSaturday
                components.hour = 10
                components.minute = 0
                reminderDate = calendar.date(from: components) ?? Date()
            }
            hasTime = true
        }) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DesignSystem.Colors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DesignSystem.Colors.calmBorder, lineWidth: 1)
                        )
                )
        }
    }

    private func saveReminder() {
        guard !title.isEmpty else { return }
        isSaving = true
        errorMessage = nil

        Task {
            do {
                // Create as a task with isReminder = true
                let taskRequest = TaskRequest(
                    title: title,
                    description: notes.isEmpty ? nil : notes,
                    durationMinutes: nil,
                    preferredTimeSlot: nil,
                    preferredTime: nil,
                    targetDate: reminderDate,
                    deadline: hasTime ? reminderDate : nil,
                    deadlineType: hasTime ? "SPECIFIC_TIME" : "END_OF_DAY",
                    notifyMinutesBefore: 15,
                    isReminder: true,
                    reminderTime: reminderDate,
                    syncToReminders: true,
                    priority: "MEDIUM",
                    category: nil,
                    tags: nil,
                    source: "ios_fab_reminder"
                )

                let _ = try await APIService.shared.createTask(taskRequest)

                await MainActor.run {
                    isSaving = false
                    NotificationCenter.default.post(name: NSNotification.Name("TaskCreated"), object: nil)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save reminder: \(error.localizedDescription)"
                    print("❌ Failed to create reminder: \(error)")
                }
            }
        }
    }
}

