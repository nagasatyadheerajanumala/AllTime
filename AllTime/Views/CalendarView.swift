import SwiftUI

enum CalendarViewMode {
    case month, week, day
}

struct CalendarView: View {
    @EnvironmentObject var calendarViewModel: CalendarViewModel
    @State private var showingEventDetail = false
    @State private var selectedEventId: Int64?
    @State private var viewMode: CalendarViewMode = .month
    @State private var calendarStyle: CalendarStyle = .wheel
    @State private var showingAddEvent = false

    // Day Detail Sheet State
    @State private var showingDayDetail = false
    @State private var selectedDayForDetail: Date = Date()
    @State private var selectedDayEvents: [Event] = []
    @State private var useDarkThemeForSheet = false  // For wheel calendar style
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background - gradient for wheel, normal for traditional
                if calendarStyle == .wheel {
                    LinearGradient(
                        colors: [
                            Color(red: 0.35, green: 0.15, blue: 0.55), // Deep purple
                            Color(red: 0.55, green: 0.25, blue: 0.45)  // Magenta-purple
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                } else {
                    DesignSystem.Colors.background
                        .ignoresSafeArea()
                }
                
                // Sync Status Banner
                VStack {
                    if calendarViewModel.isSyncing {
                        SyncBanner(message: "Syncing Google Calendar...")
                            .transition(.move(edge: .top).combined(with: .opacity))
                    } else if calendarViewModel.showSyncError {
                        SyncErrorBanner(
                            message: calendarViewModel.syncError ?? "Google Calendar sync failed",
                            onRetry: {
                                Task {
                                    await calendarViewModel.retrySync()
                                }
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer()
                }
                .zIndex(1000)
                .animation(.easeInOut(duration: 0.3), value: calendarViewModel.isSyncing)
                .animation(.easeInOut(duration: 0.3), value: calendarViewModel.showSyncError)
                
                if viewMode == .day {
                    // 24-hour timeline view
                    ZStack {
                        // Background
                        DesignSystem.Colors.background
                            .ignoresSafeArea()
                        
                        DayViewContent(
                            selectedDate: $calendarViewModel.selectedDate,
                            viewMode: $viewMode,
                            events: calendarViewModel.eventsForDate(calendarViewModel.selectedDate),
                            isRefreshing: calendarViewModel.isRefreshing,
                            onRefresh: {
                                Task {
                                    await calendarViewModel.refreshEvents()
                                }
                            },
                            onEventTap: { event in
                                selectedEventId = Int64(event.id)
                                showingEventDetail = true
                            },
                            onAddEvent: {
                                showingAddEvent = true
                            }
                        )
                    }
                } else {
                    // Month/Week view
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            // Premium Calendar Header with Month/Year and Week Strip
                            PremiumCalendarHeader(
                                selectedDate: $calendarViewModel.selectedDate,
                                viewMode: $viewMode,
                                calendarStyle: $calendarStyle,
                                isRefreshing: calendarViewModel.isRefreshing,
                                onRefresh: {
                                    Task {
                                        await calendarViewModel.refreshEvents()
                                    }
                                }
                            )
                            
                            // Calendar View (Traditional or Wheel)
                            if calendarStyle == .wheel {
                                if viewMode == .month {
                                    // Interactive Month Wheel View
                                    CircularDateWheelView(
                                        selectedDate: $calendarViewModel.selectedDate,
                                        events: calendarViewModel.events,
                                        onDateSelected: { date in
                                            HapticManager.shared.selectionChanged()
                                            // Load events and show day detail sheet
                                            Task { @MainActor in
                                                await calendarViewModel.loadEventsForSelectedDate(date)
                                                selectedDayForDetail = date
                                                selectedDayEvents = calendarViewModel.eventsForDate(date)
                                                useDarkThemeForSheet = true
                                                showingDayDetail = true
                                            }
                                        }
                                    )
                                    .frame(height: 400)
                                    .padding(.horizontal, DesignSystem.Spacing.md)
                                } else if viewMode == .week {
                                    // Interactive Week Wheel View
                                    CircularWeekWheelView(
                                        selectedDate: $calendarViewModel.selectedDate,
                                        events: calendarViewModel.events,
                                        onDateSelected: { date in
                                            HapticManager.shared.selectionChanged()
                                            // Load events and show day detail sheet
                                            Task { @MainActor in
                                                await calendarViewModel.loadEventsForSelectedDate(date)
                                                selectedDayForDetail = date
                                                selectedDayEvents = calendarViewModel.eventsForDate(date)
                                                useDarkThemeForSheet = true
                                                showingDayDetail = true
                                            }
                                        }
                                    )
                                    .frame(height: 400)
                                    .padding(.horizontal, DesignSystem.Spacing.md)
                                } else {
                                    // Day view - use traditional grid
                                    PremiumCalendarGrid(
                                        selectedDate: $calendarViewModel.selectedDate,
                                        events: calendarViewModel.events,
                                        viewMode: viewMode,
                                        onDayTap: { date, events in
                                            HapticManager.shared.selectionChanged()
                                            selectedDayForDetail = date
                                            selectedDayEvents = events
                                            useDarkThemeForSheet = true  // Day view in wheel mode
                                            showingDayDetail = true
                                        }
                                    )
                                    .padding(.horizontal, DesignSystem.Spacing.md)
                                }
                            } else {
                                // Traditional Calendar Grid
                                PremiumCalendarGrid(
                                    selectedDate: $calendarViewModel.selectedDate,
                                    events: calendarViewModel.events,
                                    viewMode: viewMode,
                                    onDayTap: { date, events in
                                        HapticManager.shared.selectionChanged()
                                        selectedDayForDetail = date
                                        selectedDayEvents = events
                                        useDarkThemeForSheet = false  // Traditional style uses light theme
                                        showingDayDetail = true
                                    }
                                )
                                .padding(.horizontal, DesignSystem.Spacing.md)
                            }
                            
                            // Meeting Clashes Section (if any)
                            MeetingClashesSection(
                                selectedDate: calendarViewModel.selectedDate
                            )
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.bottom, 100) // Space for FAB + tab bar
                        }
                    }
                    .refreshable {
                        await calendarViewModel.refreshEvents()
                    }
                }
                
                // Single Floating Action Button - only show for month/week views
                if viewMode != .day {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                HapticManager.shared.mediumTap()
                                showingAddEvent = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.title2.weight(.semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        DesignSystem.Colors.primary,
                                                        DesignSystem.Colors.primaryLight
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .shadow(color: DesignSystem.Colors.primary.opacity(0.4), radius: 12, y: 6)
                                    )
                            }
                            .buttonStyle(SmoothButtonStyle(haptic: .medium))
                            .padding(.trailing, DesignSystem.Spacing.lg)
                            .padding(.bottom, 100) // Above tab bar
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingEventDetail) {
                if let eventId = selectedEventId {
                    EventDetailView(eventId: eventId)
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(initialDate: calendarViewModel.selectedDate)
                    .onDisappear {
                        Task {
                            await calendarViewModel.refreshEvents()
                        }
                    }
            }
            .sheet(isPresented: $showingDayDetail) {
                DayDetailView(
                    date: selectedDayForDetail,
                    events: selectedDayEvents
                )
                .preferredColorScheme(useDarkThemeForSheet ? .dark : nil)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EventCreated"))) { _ in
                // Use fast refresh for immediate update after event creation
                Task {
                    await calendarViewModel.refreshEventsFromBackend()
                }
            }
            .task {
                // PERFORMANCE: Use fast backend refresh instead of full sync on appear
                // Full sync happens in background, UI shows cached data immediately
                if !calendarViewModel.isLoading && calendarViewModel.events.isEmpty {
                    await calendarViewModel.refreshEventsFromBackend()
                }
            }
            .onChange(of: calendarViewModel.selectedDate) { oldDate, newDate in
                // Use low priority for date change loads - UI already has data
                Task(priority: .utility) {
                    await calendarViewModel.loadEventsForSelectedDate(newDate)
                }
            }
            .alert("Calendar Connection Expired", isPresented: $calendarViewModel.showReconnectAlert) {
                Button("Reconnect") {
                    calendarViewModel.reconnectCalendar()
                }
                Button("Cancel", role: .cancel) {
                    calendarViewModel.showReconnectAlert = false
                }
            } message: {
                Text(calendarViewModel.reconnectAlertMessage)
            }
        }
    }
    
    private var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: calendarViewModel.selectedDate)
    }
}

// MARK: - Meeting Clashes Section

struct MeetingClashesSection: View {
    let selectedDate: Date
    @StateObject private var viewModel = MeetingClashesViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Checking for meeting clashes...")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .padding(DesignSystem.Spacing.md)
            } else if let clashes = viewModel.clashes, clashes.totalClashes > 0 {
                // Show clashes for selected date
                let dateClashes = viewModel.clashesForDate(selectedDate)
                
                if !dateClashes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.orange)
                            
                            Text("Meeting Clashes")
                                .font(DesignSystem.Typography.title3)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                            
                            Spacer()
                            
                            Text("\(dateClashes.count)")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.orange.opacity(0.2))
                                )
                        }
                        
                        VStack(spacing: 8) {
                            ForEach(dateClashes) { clash in
                                ClashCard(clash: clash)
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .fill(DesignSystem.Colors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                    .stroke(clashSeverityColor(dateClashes.first?.severity ?? "none"), lineWidth: 1)
                            )
                    )
                }
            }
            // Silently ignore errors - don't show error message to user
        }
        .onAppear {
            // Load clashes for selected date ± 7 days
            let calendar = Calendar.current
            let start = calendar.date(byAdding: .day, value: -7, to: selectedDate) ?? selectedDate
            let end = calendar.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate
            
            Task {
                await viewModel.loadClashes(startDate: start, endDate: end)
            }
        }
        .onChange(of: selectedDate) { oldDate, newDate in
            // Reload clashes when date changes
            let calendar = Calendar.current
            let start = calendar.date(byAdding: .day, value: -7, to: newDate) ?? newDate
            let end = calendar.date(byAdding: .day, value: 7, to: newDate) ?? newDate
            
            Task {
                await viewModel.loadClashes(startDate: start, endDate: end)
            }
        }
    }
    
    private func clashSeverityColor(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "red": return .red
        case "orange": return .orange
        default: return .clear
        }
    }
}

struct ClashCard: View {
    let clash: ClashInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: clash.severityIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(clash.severityColor)
                
                Text("Overlap: \(clash.overlapMinutes) min")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(clash.severityColor)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(clash.eventA.title)
                            .font(DesignSystem.Typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        
                        Text(clash.eventA.formattedTimeRange)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(clash.eventB.title)
                            .font(DesignSystem.Typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        
                        Text(clash.eventB.formattedTimeRange)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(clash.severityColor.opacity(0.1))
        )
    }
}

// MARK: - Sync Status Banners

struct SyncBanner: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.8)
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    DesignSystem.Colors.primary,
                    DesignSystem.Colors.primaryLight
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .shadow(color: DesignSystem.Colors.primary.opacity(0.3), radius: 8, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

struct SyncErrorBanner: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer()
            
            Button(action: onRetry) {
                Text("Retry")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    Color.red.opacity(0.9),
                    Color.red.opacity(0.7)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .shadow(color: Color.red.opacity(0.3), radius: 8, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}
