import SwiftUI

struct TodayView: View {
    @EnvironmentObject var calendarViewModel: CalendarViewModel
    @EnvironmentObject var summaryViewModel: SummaryViewModel
    @StateObject private var dailySummaryViewModel = DailySummaryViewModel()
    @State private var showingEventDetail = false
    @State private var selectedEventId: Int64?
    @State private var showingAddEvent = false
    @State private var showingDatePicker = false
    @ObservedObject private var healthMetricsService = HealthMetricsService.shared
    
    private var todayEvents: [Event] {
        calendarViewModel.eventsForToday()
    }
    
    private var upcomingEvents: [Event] {
        let now = Date()
        return todayEvents.filter { event in
            guard let startDate = event.startDate else { return false }
            return startDate > now
        }.sorted { event1, event2 in
            guard let start1 = event1.startDate, let start2 = event2.startDate else { return false }
            return start1 < start2
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                // Clean background
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            // Today Header Card
                            TodayHeaderCard(
                                eventCount: todayEvents.count,
                                nextEvent: upcomingEvents.first
                            )
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.top, DesignSystem.Spacing.sm)
                            
                            // Health Access Card (if not authorized)
                            if !healthMetricsService.isAuthorized {
                                TodayHealthCard()
                                    .padding(.horizontal, DesignSystem.Spacing.md)
                            }
                            
                            // Daily AI Summary Section
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                // Date Selector Header
                                HStack {
                                    Button(action: {
                                        showingDatePicker = true
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "calendar")
                                                .font(.system(size: 16, weight: .medium))
                                            Text(dailySummaryViewModel.selectedDate, style: .date)
                                                .font(DesignSystem.Typography.body)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(DesignSystem.Colors.primary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        Task {
                                            await dailySummaryViewModel.refreshSummary()
                                            try? await Task.sleep(nanoseconds: 100_000_000)
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                proxy.scrollTo("summary", anchor: .top)
                                            }
                                        }
                                    }) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(DesignSystem.Colors.primary)
                                            .rotationEffect(.degrees(dailySummaryViewModel.isLoading ? 360 : 0))
                                            .animation(dailySummaryViewModel.isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: dailySummaryViewModel.isLoading)
                                    }
                                    .disabled(dailySummaryViewModel.isLoading)
                                }
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .padding(.vertical, DesignSystem.Spacing.sm)
                                
                                // Summary Content
                                if dailySummaryViewModel.isLoading && dailySummaryViewModel.summary == nil {
                                    LoadingView()
                                        .padding(.vertical, 40)
                                } else if let summary = dailySummaryViewModel.summary {
                                    NewEnhancedSummaryContentView(
                                        summary: summary,
                                        parsed: dailySummaryViewModel.parsedSummary,
                                        waterGoal: dailySummaryViewModel.waterGoal
                                    )
                                    .id("summary")
                                } else if let errorMessage = dailySummaryViewModel.errorMessage {
                                    ErrorView(message: errorMessage) {
                                        Task {
                                            await dailySummaryViewModel.refreshSummary()
                                        }
                                    }
                                    .padding(.vertical, 40)
                                } else {
                                    EmptyStateView()
                                        .padding(.vertical, 40)
                                }
                            }
                            .padding(.top, DesignSystem.Spacing.lg)
                            
                            .padding(.bottom, 120) // Space for tab bar and FAB
                        }
                    }
                    .refreshable {
                        await calendarViewModel.refreshEvents()
                    }
                }
                
                // Floating Action Button for Add Event
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
                .padding(.bottom, 100) // Above tab bar
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingEventDetail) {
                if let eventId = selectedEventId {
                    EventDetailView(eventId: eventId)
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(initialDate: Date())
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(selectedDate: $dailySummaryViewModel.selectedDate)
            }
            .onAppear {
                // Cache is already loaded synchronously in init - no need to reload
                // Just trigger background refresh if cache is old
                Task {
                    // Always re-check authorization when view appears (user may have enabled in Settings)
                    await healthMetricsService.checkAuthorizationStatus()
                    
                    // Background refresh if cache is old (non-blocking)
                    // Cache is already loaded synchronously in init, so UI shows instantly
                    await dailySummaryViewModel.loadSummary(
                        for: dailySummaryViewModel.selectedDate,
                        forceRefresh: false
                    )
                }
            }
            .refreshable {
                // User explicitly pulled to refresh - force refresh
                await dailySummaryViewModel.loadSummary(
                    for: dailySummaryViewModel.selectedDate,
                    forceRefresh: true
                )
            }
            .onChange(of: dailySummaryViewModel.selectedDate) { oldDate, newDate in
                // Reload summary when date changes
                Task {
                    await dailySummaryViewModel.loadSummary(for: newDate)
                }
            }
            .onChange(of: healthMetricsService.isAuthorized) { oldValue, newValue in
                // When authorization changes from false to true, trigger sync
                if !oldValue && newValue {
                    Task {
                        // Small delay to ensure everything is ready
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        await HealthSyncService.shared.syncRecentDays()
                    }
                }
            }
        }
    }
}

// MARK: - Today Header Card
struct TodayHeaderCard: View {
    let eventCount: Int
    let nextEvent: Event?
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Date
            Text(dateFormatter.string(from: Date()))
                .font(.title.weight(.bold))
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            // Event count
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "calendar")
                    .foregroundColor(DesignSystem.Colors.primary)
                Text("\(eventCount) event\(eventCount == 1 ? "" : "s") today")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            
            // Next event
            if let event = nextEvent, let startDate = event.startDate {
                Divider()
                    .padding(.vertical, DesignSystem.Spacing.xs)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Up Next")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    
                    Text(event.title)
                        .font(.body.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    
                    Text(timeFormatter.string(from: startDate))
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        )
    }
}

// MARK: - Today AI Summary Card
struct TodayAISummaryCard: View {
    let summary: DailySummary

    var previewText: String {
        // Show first 2 items from day summary or health summary
        let items = !summary.daySummary.isEmpty ? summary.daySummary : summary.healthSummary
        return items.prefix(2).joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundColor(DesignSystem.Colors.accent)

                Text("AI Summary")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }

            Text(previewText)
                .font(.body)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .lineLimit(4)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.accent.opacity(0.1),
                            DesignSystem.Colors.primary.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }
}

// MARK: - Today Health Card
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
                Text("Chrona needs access to your Health data to provide personalized insights and AI-powered recommendations.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                
                Text("To enable:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.top, DesignSystem.Spacing.xs)
                
                VStack(alignment: .leading, spacing: 6) {
                    InstructionStep(number: "1", text: "Tap 'Open Settings' below")
                    InstructionStep(number: "2", text: "Go to Health → Data Access & Devices")
                    InstructionStep(number: "3", text: "Select 'Chrona'")
                    InstructionStep(number: "4", text: "Turn ON all health data types")
                }
                .padding(.top, DesignSystem.Spacing.xs)
            }
            
            HStack(spacing: DesignSystem.Spacing.md) {
                Button(action: {
                    // First try to open Health app, then fallback to Settings
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
                    // Manual refresh after user enables permissions
                    Task {
                        await healthMetricsService.checkAuthorizationStatus()
                        
                        // If now authorized, trigger sync
                        if healthMetricsService.isAuthorized {
                            await HealthSyncService.shared.syncRecentDays()
                        } else {
                            // Still denied - show alert
                            print("⚠️ Permissions still denied. Make sure all 8 types are enabled in Settings.")
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Check Again")
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
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("⚠️ IMPORTANT: If permissions are still denied after enabling in Settings:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("The app must be deleted and reinstalled to get a fresh provisioning profile with HealthKit. This is required when HealthKit was added after the app was first installed.")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, DesignSystem.Spacing.sm)
            .padding(.horizontal, DesignSystem.Spacing.sm)
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

// MARK: - Instruction Step
struct InstructionStep: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.3))
                )
            
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

// MARK: - Today Timeline Section
struct TodayTimelineSection: View {
    let events: [Event]
    let onEventTap: (Event) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Today's Timeline")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            if events.isEmpty {
                EmptyTimelineView()
            } else {
                ForEach(events) { event in
                    TodayEventCard(event: event)
                        .onTapGesture {
                            onEventTap(event)
                        }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }
}

// MARK: - Empty Timeline View
struct EmptyTimelineView: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
            
            Text("No events today")
                .font(.body)
                .foregroundColor(DesignSystem.Colors.secondaryText)
            
            Text("Enjoy your free day!")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xl)
    }
}

// MARK: - Today Event Card
struct TodayEventCard: View {
    let event: Event
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Time indicator
            if let startDate = event.startDate {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(timeFormatter.string(from: startDate))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
                .frame(width: 60, alignment: .trailing)
            }
            
            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(event.sourceColorAsColor)
                .frame(width: 4)
            
            // Event details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.body.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                if let location = event.locationName, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(location)
                            .font(.caption)
                    }
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemGroupedBackground))
        )
    }
}

// Quick Actions Card removed - Add Event is now a FAB
