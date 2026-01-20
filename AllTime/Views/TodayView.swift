import SwiftUI

// MARK: - Redesigned Today View
/// A calm, focused Today screen that reduces cognitive load through:
/// - Progressive disclosure (expand to see more)
/// - Information hierarchy (one hero, one action)
/// - Visual calm (minimal colors, subtle animations)
/// - Intentional friction (insights hidden by default)

struct TodayView: View {
    // MARK: - Environment & State
    @EnvironmentObject var calendarViewModel: CalendarViewModel
    @StateObject private var briefingViewModel = TodayBriefingViewModel()
    @StateObject private var overviewViewModel = TodayOverviewViewModel()
    @ObservedObject private var healthMetricsService = HealthMetricsService.shared
    @ObservedObject private var navigationManager = NavigationManager.shared
    @ObservedObject private var notificationHistory = NotificationHistoryService.shared

    // Week Drift - forward-looking intelligence
    @State private var weekDriftStatus: WeekDriftStatus?
    @State private var weekDriftLoading = false

    // UI State
    @State private var isBriefExpanded = false
    @State private var isInsightsExpanded = false
    @State private var selectedEvent: Event?
    @State private var showingEventSheet = false
    @State private var showingClaraChat = false
    @State private var showingAddEvent = false
    @State private var showingAddTask = false
    @State private var showFABMenu = false
    @State private var showingNotificationHistory = false
    @State private var showingSummaryDetail = false
    @State private var selectedPrimaryRecommendation: PrimaryRecommendation?

    // Task management
    @State private var loadTask: Task<Void, Never>?

    // MARK: - Computed Properties

    private var todayEvents: [Event] {
        calendarViewModel.eventsForToday().sorted { event1, event2 in
            guard let start1 = event1.startDate, let start2 = event2.startDate else { return false }
            return start1 < start2
        }
    }

    private var currentEvent: Event? {
        let now = Date()
        return todayEvents.first { event in
            guard let start = event.startDate, let end = event.endDate else { return false }
            return now >= start && now <= end
        }
    }

    private var upcomingEvents: [Event] {
        let now = Date()
        return todayEvents.filter { event in
            guard let startDate = event.startDate else { return false }
            return startDate > now
        }
    }

    private var isLoading: Bool {
        weekDriftLoading || overviewViewModel.isLoading || briefingViewModel.isLoading
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background - Near black for visual calm
            DesignSystem.Colors.background
                .ignoresSafeArea()

            // Main Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // A. Sticky Header spacer (actual header is in overlay)
                    Color.clear.frame(height: 60)

                    // Content with proper spacing
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // B. Daily Brief (Hero Card)
                        DailyBriefCard(
                            driftStatus: weekDriftStatus,
                            briefing: briefingViewModel.briefing,
                            overview: overviewViewModel.overview,
                            freshHealthMetrics: briefingViewModel.freshHealthMetrics,
                            isLoading: isLoading,
                            isExpanded: $isBriefExpanded,
                            onTap: { showingSummaryDetail = true }
                        )
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.top, DesignSystem.Spacing.sm)

                        // C. Primary Action Card (ONE action only)
                        if let primaryRec = briefingViewModel.briefing?.primaryRecommendation {
                            PrimaryActionCard(
                                recommendation: primaryRec,
                                onAction: { selectedPrimaryRecommendation = primaryRec },
                                onDismiss: { /* Handle remind later */ }
                            )
                            .padding(.horizontal, DesignSystem.Spacing.md)
                        }

                        // D. Day Timeline (Today Schedule)
                        TodayScheduleView(
                            events: todayEvents,
                            currentEvent: currentEvent,
                            onEventTap: { event in
                                selectedEvent = event
                                showingEventSheet = true
                            }
                        )
                        .padding(.horizontal, DesignSystem.Spacing.md)

                        // E. Optional Insights (Collapsed by default)
                        OptionalInsightsView(
                            briefing: briefingViewModel.briefing,
                            isExpanded: $isInsightsExpanded
                        )
                        .padding(.horizontal, DesignSystem.Spacing.md)

                        // Bottom padding for floating actions
                        Color.clear.frame(height: 140)
                    }
                }
            }
            .refreshable {
                await refreshData()
            }

            // A. Sticky Header (overlay for true stickiness)
            VStack {
                TodayHeaderView(
                    unreadCount: notificationHistory.unreadCount,
                    isRefreshing: isLoading,
                    onNotificationTap: { showingNotificationHistory = true },
                    onRefreshTap: { Task { await refreshData() } }
                )
                Spacer()
            }

            // Floating Actions
            FloatingActionStack(
                showFABMenu: $showFABMenu,
                showingClaraChat: $showingClaraChat,
                showingAddEvent: $showingAddEvent,
                showingAddTask: $showingAddTask
            )
        }
        .sheet(isPresented: $showingEventSheet) {
            if let event = selectedEvent {
                LocalEventDetailSheet(event: event)
            }
        }
        .sheet(isPresented: $showingClaraChat) {
            ClaraChatView()
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(initialDate: Date())
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskSheet()
        }
        .sheet(isPresented: $showingNotificationHistory) {
            NotificationHistoryView()
        }
        .sheet(isPresented: $showingSummaryDetail) {
            TodaySummaryDetailView(
                briefing: briefingViewModel.briefing,
                summaryTile: overviewViewModel.overview?.summaryTile,
                freshHealthMetrics: briefingViewModel.freshHealthMetrics
            )
        }
        .sheet(item: $selectedPrimaryRecommendation) { recommendation in
            PrimaryRecommendationActionSheet(
                recommendation: recommendation,
                focusWindow: briefingViewModel.briefing?.focusWindows?.first
            )
        }
        .onAppear {
            loadTask?.cancel()
            loadTask = Task {
                await loadAllData()
            }
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
    }

    // MARK: - Data Loading

    private func loadAllData() async {
        // First: Fresh HealthKit data
        await briefingViewModel.fetchFreshHealthMetrics()

        // Sync health to backend
        await HealthSyncService.shared.syncRecentDays()

        // Load everything in parallel
        async let calendarTask: () = calendarViewModel.loadEventsForSelectedDate(Date())
        async let healthTask: () = healthMetricsService.checkAuthorizationStatus()
        async let briefingTask: () = briefingViewModel.fetchBriefing()
        async let overviewTask: () = overviewViewModel.fetchOverview()
        async let driftTask: () = fetchWeekDrift()

        _ = await (calendarTask, healthTask, briefingTask, overviewTask, driftTask)
    }

    private func refreshData() async {
        await briefingViewModel.fetchFreshHealthMetrics()
        await HealthSyncService.shared.syncRecentDays()

        async let calendarRefresh: () = calendarViewModel.refreshEvents()
        async let briefingRefresh: () = briefingViewModel.refresh()
        async let overviewRefresh: () = overviewViewModel.refresh()

        _ = await (calendarRefresh, briefingRefresh, overviewRefresh)
    }

    private func fetchWeekDrift() async {
        await MainActor.run { weekDriftLoading = true }
        do {
            let status = try await APIService.shared.getWeekDriftStatus()
            await MainActor.run {
                weekDriftStatus = status
                weekDriftLoading = false
            }
        } catch {
            await MainActor.run { weekDriftLoading = false }
        }
    }
}

// MARK: - A. Sticky Header View
/// Minimal header that stays fixed during scroll
/// Shows: Title, Date, Notification bell, Refresh
struct TodayHeaderView: View {
    let unreadCount: Int
    let isRefreshing: Bool
    let onNotificationTap: () -> Void
    let onRefreshTap: () -> Void

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    var body: some View {
        HStack(alignment: .center) {
            // Title + Date
            VStack(alignment: .leading, spacing: 2) {
                Text("Today")
                    .font(.title2.weight(.bold))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Text(dateText)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }

            Spacer()

            // Right actions
            HStack(spacing: 16) {
                // Notification bell
                Button(action: onNotificationTap) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.secondaryText)

                        if unreadCount > 0 {
                            Circle()
                                .fill(DesignSystem.Colors.errorRed)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                .frame(width: 44, height: 44)

                // Refresh
                Button(action: onRefreshTap) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(
                            isRefreshing
                                ? Animation.linear(duration: 1).repeatForever(autoreverses: false)
                                : .default,
                            value: isRefreshing
                        )
                }
                .frame(width: 44, height: 44)
                .disabled(isRefreshing)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            // Subtle gradient for visual separation
            LinearGradient(
                colors: [
                    DesignSystem.Colors.background,
                    DesignSystem.Colors.background.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

// MARK: - B. Daily Brief Card (Hero)
/// Single hero card showing day quality with expandable details
struct DailyBriefCard: View {
    let driftStatus: WeekDriftStatus?
    let briefing: DailyBriefingResponse?
    let overview: TodayOverviewResponse?
    let freshHealthMetrics: DailyHealthMetrics?
    let isLoading: Bool
    @Binding var isExpanded: Bool
    let onTap: () -> Void

    // Derived properties
    private var headline: String {
        if let drift = driftStatus {
            return drift.headline
        }
        return overview?.summaryTile.greeting ?? briefing?.greeting ?? "Good day"
    }

    private var subheadline: String {
        if let drift = driftStatus {
            return drift.subheadline
        }
        return overview?.summaryTile.previewLine ?? briefing?.summaryLine ?? ""
    }

    private var severity: DriftSeverity {
        guard let drift = driftStatus else { return .onTrack }
        return DriftSeverity(rawValue: drift.severity) ?? .onTrack
    }

    private var dayLabel: String {
        if let drift = driftStatus {
            return "Day \(drift.dayOfWeek) of 7"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                isExpanded.toggle()
            }
        }) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Top row: Status pill + Day indicator
                HStack {
                    // Status pill
                    HStack(spacing: 4) {
                        Image(systemName: severity.icon)
                            .font(.system(size: 10, weight: .semibold))
                        Text(severity.displayName)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(Color(hex: severity.color))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color(hex: severity.color).opacity(0.12))
                    )

                    Spacer()

                    Text(dayLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.white.opacity(0.4))
                }

                // Main headline
                if isLoading && driftStatus == nil {
                    SkeletonView(width: 250, height: 22)
                } else {
                    Text(headline)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(isExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Subheadline
                if isLoading && driftStatus == nil {
                    SkeletonView(width: 200, height: 16)
                } else if !subheadline.isEmpty {
                    Text(subheadline)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(isExpanded ? nil : 2)
                }

                // Expanded content: Health metrics, sleep, etc.
                if isExpanded {
                    expandedContent
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Expand/collapse indicator
                HStack {
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(.top, 4)
            }
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                // Premium dark gradient (charcoal → slate)
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.cardBackground.opacity(1.2),
                        DesignSystem.Colors.cardBackground
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.vertical, 4)

            // Health metrics grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // Sleep (convert minutes to hours for DailyHealthMetrics)
                if let sleepMinutes = freshHealthMetrics?.sleepMinutes {
                    let sleepHours = Double(sleepMinutes) / 60.0
                    metricItem(
                        icon: "bed.double.fill",
                        value: String(format: "%.1fh", sleepHours),
                        label: "Sleep"
                    )
                } else if let sleep = briefing?.keyMetrics?.effectiveSleepHours {
                    metricItem(
                        icon: "bed.double.fill",
                        value: String(format: "%.1fh", sleep),
                        label: "Sleep"
                    )
                }

                // Steps
                if let steps = freshHealthMetrics?.steps ?? briefing?.keyMetrics?.effectiveSteps {
                    metricItem(
                        icon: "figure.walk",
                        value: "\(steps)",
                        label: "Steps"
                    )
                }

                // Meetings
                if let meetings = briefing?.quickStats?.meetingsCount {
                    metricItem(
                        icon: "person.2.fill",
                        value: "\(meetings)",
                        label: "Meetings"
                    )
                }

                // Meeting hours
                if let keyMetrics = briefing?.keyMetrics {
                    let hours = keyMetrics.effectiveMeetingHours
                    if hours > 0 {
                        metricItem(
                            icon: "clock.fill",
                            value: String(format: "%.1fh", hours),
                            label: "In meetings"
                        )
                    }
                }

                // Focus time
                if let focus = briefing?.keyMetrics?.focusTimeAvailable, focus > 0 {
                    metricItem(
                        icon: "brain.head.profile",
                        value: String(format: "%.1fh", focus),
                        label: "Focus"
                    )
                }

                // Tasks
                if let tasks = overview?.todoTile.total {
                    metricItem(
                        icon: "checkmark.circle",
                        value: "\(tasks)",
                        label: "Tasks"
                    )
                }
            }

            // Week projection (if drifting)
            if severity != .onTrack, let projection = driftStatus?.weekProjection {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: severity.color))

                    Text(projection)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: severity.color).opacity(0.08))
                )
            }

            // Tap for more details
            Button(action: onTap) {
                HStack {
                    Text("See full summary")
                        .font(.caption.weight(.medium))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(DesignSystem.Colors.primary)
            }
            .padding(.top, 4)
        }
    }

    private func metricItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)

            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - C. Primary Action Card
/// Single "Do Now" action with clear CTAs
struct PrimaryActionCard: View {
    let recommendation: PrimaryRecommendation
    let onAction: () -> Void
    let onDismiss: () -> Void

    private var accentColor: Color {
        switch recommendation.urgency?.lowercased() ?? "" {
        case "high", "critical":
            return DesignSystem.Colors.amber
        default:
            return DesignSystem.Colors.violet
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Label
            HStack(spacing: 6) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 6, height: 6)

                Text("DO NOW")
                    .font(.caption.weight(.bold))
                    .foregroundColor(accentColor)
                    .tracking(0.5)
            }

            // Action text
            Text(recommendation.action)
                .font(.body.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            // Reason (if available)
            if let reason = recommendation.reason, !reason.isEmpty {
                Text(reason)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .lineLimit(2)
            }

            // CTAs
            HStack(spacing: 12) {
                // Primary: Do it
                Button(action: onAction) {
                    Text("Do it")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(accentColor)
                        )
                }

                // Secondary: Remind me later
                Button(action: onDismiss) {
                    Text("Later")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(DesignSystem.Colors.secondaryText.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - D. Today Schedule View
/// Vertical time-based list showing schedule flow (renamed to avoid conflict with calendar DayTimelineView)
struct TodayScheduleView: View {
    let events: [Event]
    let currentEvent: Event?
    let onEventTap: (Event) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Section header
            HStack {
                Text("Schedule")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                Spacer()

                Text("\(events.count) event\(events.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }

            if events.isEmpty {
                // Empty state
                emptyState
            } else {
                // Timeline
                VStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        TodayScheduleRow(
                            event: event,
                            isCurrentEvent: event.id == currentEvent?.id,
                            isPastEvent: isPastEvent(event),
                            isLast: index == events.count - 1,
                            onTap: { onEventTap(event) }
                        )
                    }
                }
                .padding(DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .fill(DesignSystem.Colors.cardBackground)
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 24))
                .foregroundColor(DesignSystem.Colors.tertiaryText)

            Text("No events today")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    private func isPastEvent(_ event: Event) -> Bool {
        guard let endDate = event.endDate ?? event.startDate else { return false }
        return endDate < Date()
    }
}

// MARK: - Today Schedule Row
/// Individual event row in the schedule (renamed to avoid conflict)
struct TodayScheduleRow: View {
    let event: Event
    let isCurrentEvent: Bool
    let isPastEvent: Bool
    let isLast: Bool
    let onTap: () -> Void

    private var timeText: String {
        guard let start = event.startDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: start).lowercased()
    }

    private var durationText: String {
        guard let start = event.startDate, let end = event.endDate else { return "" }
        let minutes = Int(end.timeIntervalSince(start) / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Timeline indicator
                VStack(spacing: 0) {
                    // Time dot
                    Circle()
                        .fill(isCurrentEvent ? DesignSystem.Colors.primary : (isPastEvent ? DesignSystem.Colors.tertiaryText : DesignSystem.Colors.secondaryText))
                        .frame(width: isCurrentEvent ? 10 : 6, height: isCurrentEvent ? 10 : 6)

                    // Connecting line (if not last)
                    if !isLast {
                        Rectangle()
                            .fill(DesignSystem.Colors.tertiaryText.opacity(0.3))
                            .frame(width: 1)
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(width: 20)

                // Time
                Text(timeText)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(isPastEvent ? DesignSystem.Colors.tertiaryText : DesignSystem.Colors.secondaryText)
                    .frame(width: 60, alignment: .leading)

                // Event details
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.subheadline.weight(isCurrentEvent ? .semibold : .regular))
                        .foregroundColor(isPastEvent ? DesignSystem.Colors.tertiaryText : DesignSystem.Colors.primaryText)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(durationText)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)

                        if let location = event.locationName, !location.isEmpty {
                            Text("·")
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                            Text(location)
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                // Current indicator
                if isCurrentEvent {
                    Text("NOW")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.primary.opacity(0.15))
                        )
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(isPastEvent ? 0.6 : 1.0)
    }
}

// MARK: - E. Optional Insights View
/// Collapsed accordion for secondary insights
struct OptionalInsightsView: View {
    let briefing: DailyBriefingResponse?
    @Binding var isExpanded: Bool

    @State private var expandedSections: Set<String> = []

    private var hasInsights: Bool {
        guard let briefing = briefing else { return false }
        let hasSuggestions = (briefing.suggestions?.count ?? 0) > 0
        let hasFocusWindows = (briefing.focusWindows?.count ?? 0) > 0
        let hasEnergyDips = (briefing.energyDips?.count ?? 0) > 0
        return hasSuggestions || hasFocusWindows || hasEnergyDips
    }

    var body: some View {
        if hasInsights {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Section header (tap to expand/collapse)
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        Text("Insights")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(DesignSystem.Colors.secondaryText)

                        Text("(optional)")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                }

                // Expanded content
                if isExpanded {
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        // All Actions
                        if let suggestions = briefing?.suggestions, !suggestions.isEmpty {
                            insightAccordion(
                                title: "All Actions",
                                icon: "lightbulb.fill",
                                iconColor: DesignSystem.Colors.amber,
                                badge: "\(suggestions.count)",
                                sectionId: "actions",
                                content: AnyView(
                                    VStack(spacing: 8) {
                                        ForEach(suggestions.prefix(5), id: \.suggestionId) { suggestion in
                                            suggestionRow(suggestion)
                                        }
                                    }
                                )
                            )
                        }

                        // Focus Windows
                        if let focusWindows = briefing?.focusWindows, !focusWindows.isEmpty {
                            insightAccordion(
                                title: "Focus Windows",
                                icon: "brain.head.profile",
                                iconColor: DesignSystem.Colors.blue,
                                badge: "\(focusWindows.count) available",
                                sectionId: "focus",
                                content: AnyView(
                                    VStack(spacing: 8) {
                                        ForEach(focusWindows.prefix(3), id: \.startTime) { window in
                                            focusWindowRow(window)
                                        }
                                    }
                                )
                            )
                        }

                        // Energy Dips
                        if let energyDips = briefing?.energyDips, !energyDips.isEmpty {
                            insightAccordion(
                                title: "Energy Dips",
                                icon: "battery.50",
                                iconColor: DesignSystem.Colors.amber,
                                badge: "\(energyDips.count) predicted",
                                sectionId: "energy",
                                content: AnyView(
                                    VStack(spacing: 8) {
                                        ForEach(energyDips.prefix(3), id: \.time) { dip in
                                            energyDipRow(dip)
                                        }
                                    }
                                )
                            )
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: - Accordion Component

    private func insightAccordion(
        title: String,
        icon: String,
        iconColor: Color,
        badge: String,
        sectionId: String,
        content: AnyView
    ) -> some View {
        VStack(spacing: 0) {
            // Header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedSections.contains(sectionId) {
                        expandedSections.remove(sectionId)
                    } else {
                        expandedSections.insert(sectionId)
                    }
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                        .frame(width: 24)

                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Spacer()

                    Text(badge)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)

                    Image(systemName: expandedSections.contains(sectionId) ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
                .padding(DesignSystem.Spacing.md)
            }

            // Content
            if expandedSections.contains(sectionId) {
                content
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.md)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // MARK: - Row Components

    private func suggestionRow(_ suggestion: BriefingSuggestion) -> some View {
        HStack(spacing: 10) {
            Image(systemName: suggestion.icon ?? "lightbulb")
                .font(.system(size: 12))
                .foregroundColor(DesignSystem.Colors.amber)
                .frame(width: 20)

            Text(suggestion.title)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.primaryText)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func focusWindowRow(_ window: FocusWindow) -> some View {
        HStack(spacing: 10) {
            Text(window.startTime)
                .font(.caption.monospacedDigit())
                .foregroundColor(DesignSystem.Colors.secondaryText)

            Text(window.suggestedActivity ?? "Focus time")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.primaryText)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func energyDipRow(_ dip: EnergyDip) -> some View {
        HStack(spacing: 10) {
            Text(dip.displayTime)
                .font(.caption.monospacedDigit())
                .foregroundColor(DesignSystem.Colors.secondaryText)

            Text(dip.recommendation ?? dip.reason ?? "Energy dip expected")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.primaryText)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Floating Action Stack
/// Two floating buttons: + FAB and Clara orb
struct FloatingActionStack: View {
    @Binding var showFABMenu: Bool
    @Binding var showingClaraChat: Bool
    @Binding var showingAddEvent: Bool
    @Binding var showingAddTask: Bool

    // Clara orb breathing animation
    @State private var orbScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            HStack {
                Spacer()

                VStack(spacing: 12) {
                    // Dimmed background when FAB menu is open
                    if showFABMenu {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showFABMenu = false
                                }
                            }
                    }

                    // FAB Menu items (when expanded)
                    if showFABMenu {
                        // Add Task
                        fabMenuItem(
                            icon: "checkmark.circle.fill",
                            label: "Task",
                            color: DesignSystem.Colors.emerald
                        ) {
                            showFABMenu = false
                            showingAddTask = true
                        }

                        // Add Event
                        fabMenuItem(
                            icon: "calendar.badge.plus",
                            label: "Event",
                            color: DesignSystem.Colors.blue
                        ) {
                            showFABMenu = false
                            showingAddEvent = true
                        }
                    }

                    // Clara AI Orb (secondary, above + button)
                    claraOrb

                    // Primary FAB (+)
                    primaryFAB
                }
                .padding(.trailing, DesignSystem.Spacing.lg)
                .padding(.bottom, 100) // Above tab bar
            }
        }
    }

    // MARK: - Clara Orb
    /// Soft purple gradient with slow breathing animation
    private var claraOrb: some View {
        Button(action: {
            HapticManager.shared.lightTap()
            showingClaraChat = true
        }) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                DesignSystem.Colors.violet.opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    .frame(width: 60, height: 60)

                // Main orb
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.violet,
                                DesignSystem.Colors.violetDark
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: DesignSystem.Colors.violet.opacity(0.4), radius: 8, y: 4)

                // Sparkle icon
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .scaleEffect(orbScale)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            // Slow breathing animation (3s cycle)
            withAnimation(
                Animation
                    .easeInOut(duration: 3)
                    .repeatForever(autoreverses: true)
            ) {
                orbScale = 1.04
            }
        }
    }

    // MARK: - Primary FAB
    /// Blue + button for adding events/tasks
    private var primaryFAB: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showFABMenu.toggle()
            }
        }) {
            Image(systemName: showFABMenu ? "xmark" : "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: showFABMenu
                                    ? [DesignSystem.Colors.tertiaryText, DesignSystem.Colors.tertiaryText.opacity(0.8)]
                                    : [DesignSystem.Colors.primary, DesignSystem.Colors.primaryDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(
                            color: (showFABMenu ? DesignSystem.Colors.tertiaryText : DesignSystem.Colors.primary).opacity(0.4),
                            radius: 12,
                            y: 6
                        )
                )
                .rotationEffect(.degrees(showFABMenu ? 90 : 0))
        }
    }

    // MARK: - FAB Menu Item
    private func fabMenuItem(
        icon: String,
        label: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.cardBackground)
                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    )

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(color)
                            .shadow(color: color.opacity(0.4), radius: 6, y: 3)
                    )
            }
        }
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.6).combined(with: .opacity).combined(with: .offset(y: 10)),
                removal: .scale(scale: 0.6).combined(with: .opacity)
            )
        )
    }
}

// MARK: - Preview

#Preview {
    TodayView()
        .environmentObject(CalendarViewModel())
        .preferredColorScheme(.dark)
}
