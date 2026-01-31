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

    // FAB Menu State (same as TodayView)
    @State private var showFABMenu = false
    @State private var showingAddTask = false
    @State private var showingAddReminder = false
    @State private var showingQuickBook = false
    @State private var showingCalendarImport = false
    
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

                            // Mood Check-In (moved from Today for less clutter)
                            MoodCheckInCardView()
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .padding(.bottom, 100) // Space for FAB + tab bar
                        }
                    }
                    .refreshable {
                        await calendarViewModel.refreshEvents()
                    }
                }
                
                // Expandable FAB Menu - show for all view modes
                fabMenu
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

    // MARK: - FAB Menu (same as TodayView)
    private var fabMenu: some View {
        ZStack {
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

            // FAB positioned at bottom trailing
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 12) {
                        // Expandable menu options
                        if showFABMenu {
                            // Quick Book - easily block time on calendar
                            fabMenuItem(
                                icon: "calendar.badge.clock",
                                label: "Quick Book",
                                color: Color(hex: "06B6D4")
                            ) {
                                showFABMenu = false
                                showingQuickBook = true
                            }

                            // Add Reminder option
                            fabMenuItem(
                                icon: "bell.fill",
                                label: "Add Reminder",
                                color: DesignSystem.Colors.amber
                            ) {
                                showFABMenu = false
                                showingAddReminder = true
                            }

                            // Add Task option
                            fabMenuItem(
                                icon: "checkmark.circle.fill",
                                label: "Add Task",
                                color: DesignSystem.Colors.emerald
                            ) {
                                showFABMenu = false
                                showingAddTask = true
                            }

                            // Add Event option
                            fabMenuItem(
                                icon: "calendar.badge.plus",
                                label: "Add Event",
                                color: DesignSystem.Colors.blue
                            ) {
                                showFABMenu = false
                                showingAddEvent = true
                            }

                            // Import from Photo option
                            fabMenuItem(
                                icon: "photo.badge.plus",
                                label: "Import from Photo",
                                color: DesignSystem.Colors.amber
                            ) {
                                showFABMenu = false
                                showingCalendarImport = true
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
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskSheet()
        }
        .sheet(isPresented: $showingAddReminder) {
            AddReminderSheet()
        }
        .sheet(isPresented: $showingQuickBook) {
            QuickBookView()
        }
        .sheet(isPresented: $showingCalendarImport) {
            CalendarImportView()
        }
    }

    private func fabMenuItem(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(color)
                    )
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(color.opacity(0.9))
                    .shadow(color: color.opacity(0.3), radius: 8, y: 4)
            )
        }
        .transition(.scale.combined(with: .opacity))
    }
}

/// MARK: - Meeting Clashes Section (Clean, focused design)

struct MeetingClashesSection: View {
    let selectedDate: Date
    @StateObject private var viewModel = MeetingClashesViewModel()
    @State private var showAllClashes = false

    var body: some View {
        let dateClashes = viewModel.clashesForDate(selectedDate)

        Group {
            if viewModel.isLoading && dateClashes.isEmpty {
                // Loading state
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Checking conflicts...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                .cornerRadius(12)
            } else if dateClashes.isEmpty {
                // No conflicts
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No Conflicts")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Your schedule is clear for this day")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color(.systemBackground))
                .cornerRadius(12)
            } else {
                // Show only top clash
                VStack(spacing: 0) {
                    if let topClash = dateClashes.first {
                        CleanClashCard(
                            clash: topClash,
                            totalCount: dateClashes.count,
                            onSeeAll: { showAllClashes = true }
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showAllClashes) {
            AllClashesView(clashes: dateClashes)
        }
        .onAppear {
            loadClashes()
        }
        .onChange(of: selectedDate) { _, _ in
            loadClashes()
        }
    }

    private func loadClashes() {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -7, to: selectedDate) ?? selectedDate
        let end = calendar.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate
        Task {
            await viewModel.loadClashes(startDate: start, endDate: end)
        }
    }
}

/// Clean, focused clash card - shows one conflict clearly
struct CleanClashCard: View {
    let clash: ClashInfo
    let totalCount: Int
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    Text("Conflict")
                        .font(.system(size: 15, weight: .semibold))
                }

                Spacer()

                if totalCount > 1 {
                    Button(action: onSeeAll) {
                        Text("\(totalCount) total →")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }

            // Two events - uniform height boxes
            HStack(spacing: 10) {
                // Event A
                eventBox(clash.eventA, isKeep: clash.recommendedKeep == clash.eventA.id)

                // Overlap indicator
                VStack(spacing: 2) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text("\(clash.overlapMinutes)m")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                }
                .frame(width: 36)

                // Event B
                eventBox(clash.eventB, isKeep: clash.recommendedKeep == clash.eventB.id)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        )
    }

    private func eventBox(_ event: ClashEventInfo, isKeep: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title - single line, truncated
            Text(event.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .foregroundColor(.primary)

            // Time only (no date)
            Text(parseTime(event.startTime))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)

            // Keep badge or spacer for uniform height
            if isKeep {
                Text("KEEP")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(3)
            } else {
                Color.clear.frame(height: 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 60)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isKeep ? Color.green.opacity(0.08) : Color(.secondarySystemBackground))
        )
    }

    private func parseTime(_ isoString: String) -> String {
        // Try ISO8601 first
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: isoString) {
            let tf = DateFormatter()
            tf.dateFormat = "h:mm a"
            return tf.string(from: date)
        }

        // Try without fractional seconds
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: isoString) {
            let tf = DateFormatter()
            tf.dateFormat = "h:mm a"
            return tf.string(from: date)
        }

        // Try simple format (no timezone)
        let simple = DateFormatter()
        simple.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = simple.date(from: String(isoString.prefix(19))) {
            let tf = DateFormatter()
            tf.dateFormat = "h:mm a"
            return tf.string(from: date)
        }

        // Fallback: extract time from string directly
        if let tIndex = isoString.firstIndex(of: "T"),
           isoString.distance(from: tIndex, to: isoString.endIndex) >= 6 {
            let timeStart = isoString.index(after: tIndex)
            let timeEnd = isoString.index(timeStart, offsetBy: 5)
            let timeStr = String(isoString[timeStart..<timeEnd])
            if let hour = Int(timeStr.prefix(2)), let minute = Int(timeStr.suffix(2)) {
                let period = hour >= 12 ? "PM" : "AM"
                let hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
                return String(format: "%d:%02d %@", hour12, minute, period)
            }
        }

        return "—"
    }
}

/// Sheet showing all clashes - uniform cards, time only
struct AllClashesView: View {
    let clashes: [ClashInfo]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(clashes) { clash in
                        clashRow(clash)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("All Conflicts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func clashRow(_ clash: ClashInfo) -> some View {
        HStack(spacing: 8) {
            // Event A box
            eventBox(title: clash.eventA.title, time: parseTime(clash.eventA.startTime), alignment: .leading)

            // Overlap badge
            Text("\(clash.overlapMinutes)m")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(4)

            // Event B box
            eventBox(title: clash.eventB.title, time: parseTime(clash.eventB.startTime), alignment: .trailing)
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func eventBox(title: String, time: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .foregroundColor(.primary)
            Text(time)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
        .frame(height: 36)
    }

    private func parseTime(_ isoString: String) -> String {
        // Try ISO8601 with fractional seconds
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: isoString) {
            let tf = DateFormatter()
            tf.dateFormat = "h:mm a"
            return tf.string(from: date)
        }

        // Try without fractional seconds
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: isoString) {
            let tf = DateFormatter()
            tf.dateFormat = "h:mm a"
            return tf.string(from: date)
        }

        // Try simple format
        let simple = DateFormatter()
        simple.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = simple.date(from: String(isoString.prefix(19))) {
            let tf = DateFormatter()
            tf.dateFormat = "h:mm a"
            return tf.string(from: date)
        }

        // Fallback: extract time manually
        if let tIndex = isoString.firstIndex(of: "T"),
           isoString.distance(from: tIndex, to: isoString.endIndex) >= 6 {
            let timeStart = isoString.index(after: tIndex)
            let timeEnd = isoString.index(timeStart, offsetBy: 5)
            let timeStr = String(isoString[timeStart..<timeEnd])
            if let hour = Int(timeStr.prefix(2)), let minute = Int(timeStr.suffix(2)) {
                let period = hour >= 12 ? "PM" : "AM"
                let hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
                return String(format: "%d:%02d %@", hour12, minute, period)
            }
        }

        return "—"
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
