import SwiftUI
import CoreLocation

struct TodayView: View {
    @EnvironmentObject var calendarViewModel: CalendarViewModel
    @StateObject private var dailySummaryViewModel = DailySummaryViewModel()
    @StateObject private var onDemandViewModel = OnDemandRecommendationsViewModel()
    @State private var showingEventDetail = false
    @State private var selectedEventId: Int64?
    @State private var showingAddEvent = false
    @State private var showingDatePicker = false
    @State private var showingFoodSheet = false
    @State private var showingWalkSheet = false
    @ObservedObject private var healthMetricsService = HealthMetricsService.shared
    @ObservedObject private var locationManager = LocationManager.shared
    
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
    
    private func calculateTotalDuration(_ events: [Event]) -> TimeInterval {
        var total: TimeInterval = 0
        for event in events {
            if let start = event.startDate, let end = event.endDate {
                total += end.timeIntervalSince(start)
            }
        }
        return total
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
                            // Today Stats Header
                            TodayStatsHeader(
                                eventCount: todayEvents.count,
                                totalDuration: calculateTotalDuration(todayEvents),
                                firstEvent: todayEvents.first,
                                lastEvent: todayEvents.last
                            )
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.top, DesignSystem.Spacing.sm)
                            
                            // Today's Events Section
                            if !todayEvents.isEmpty {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                    Text("Today's Schedule")
                                        .font(.title3.weight(.bold))
                                        .foregroundColor(DesignSystem.Colors.primaryText)
                                        .padding(.horizontal, DesignSystem.Spacing.md)
                                    
                                    ForEach(todayEvents) { event in
                                        TodayEventTile(event: event)
                                    .padding(.horizontal, DesignSystem.Spacing.md)
                                            .onTapGesture {
                                                selectedEventId = event.id
                                                showingEventDetail = true
                                            }
                                    }
                                }
                            }
                            
                            // Daily AI Summary Section (AI-Generated Narrative)
                            if let summary = dailySummaryViewModel.summary {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                                    // Alerts FIRST - most important (if any)
                                    if !summary.alerts.isEmpty {
                                        AlertsSectionView(alerts: summary.alerts)
                                            .padding(.horizontal, DesignSystem.Spacing.md)
                                    }

                                    // Day Summary - AI narrative paragraphs
                                    if !summary.daySummary.isEmpty {
                                        AINarrativeSummarySection(
                                            paragraphs: summary.daySummary,
                                            title: "Your Day",
                                            icon: "calendar",
                                            accentColor: DesignSystem.Colors.primary
                                        )
                                        .padding(.horizontal, DesignSystem.Spacing.md)
                                    }

                                    // Health Summary - AI narrative paragraphs
                                    if !summary.healthSummary.isEmpty {
                                        AINarrativeSummarySection(
                                            paragraphs: summary.healthSummary,
                                            title: "Health & Recovery",
                                            icon: "heart.fill",
                                            accentColor: .red
                                        )
                                        .padding(.horizontal, DesignSystem.Spacing.md)
                                    }

                                    // Focus Recommendations - AI narrative paragraphs
                                    if !summary.focusRecommendations.isEmpty {
                                        AINarrativeSummarySection(
                                            paragraphs: summary.focusRecommendations,
                                            title: "Focus & Productivity",
                                            icon: "brain.head.profile",
                                            accentColor: .purple
                                        )
                                        .padding(.horizontal, DesignSystem.Spacing.md)
                                    }
                                    
                                    // NOTE: AI-generated summaries don't have structured health suggestions
                                    // All recommendations are in the narrative paragraphs above

                                    // Location-based recommendations not included in AI summary
                                    // TODO: If backend adds location data to AI endpoint, uncomment below

                                    // if let location = summary.locationRecommendations,
                                    //    let spots = location.lunchSuggestions,
                                    //    !spots.isEmpty {
                                    //     LunchSpotsView(spots: spots)
                                    //         .padding(.horizontal, DesignSystem.Spacing.md)
                                    // }

                                    // Location-based walk routes
                                    // if let location = summary.locationRecommendations,
                                    //    let walks = location.walkRoutes,
                                    //    !walks.isEmpty {
                                    //     WalkRoutesListView(routes: walks)
                                    //         .padding(.horizontal, DesignSystem.Spacing.md)
                                    // }
                                }
                            } else if dailySummaryViewModel.isLoading {
                                AILoadingView()
                            } else if let error = dailySummaryViewModel.errorMessage {
                                // Show error message
                                VStack(spacing: 16) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(.orange)
                                    
                                    Text("Failed to Load Summary")
                                        .font(.title2.weight(.bold))
                                    
                                    Text(error)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 32)
                                    
                                    Button(action: {
                                        Task {
                                            await dailySummaryViewModel.refreshSummary()
                                        }
                                    }) {
                                        Text("Try Again")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 32)
                                            .padding(.vertical, 12)
                                            .background(Color.blue)
                                            .cornerRadius(10)
                                    }
                                    
                                    Text("Check Xcode console for detailed logs")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 8)
                                }
                                .padding(.vertical, 60)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                            }
                            
                            // Bottom padding for FAB
                            Color.clear.frame(height: 120)
                        }
                    }
                    .refreshable {
                        await calendarViewModel.refreshEvents()
                        await dailySummaryViewModel.refreshSummary()
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        // Location button
                        Button(action: {
                            print("🔄 TodayView: Forcing location update...")
                            locationManager.forceLocationUpdate()
                        }) {
                            Image(systemName: "location.fill")
                                .foregroundColor(locationManager.location != nil ? .green : .gray)
                        }
                        
                        // Refresh button
                        Button(action: {
                            print("🔄 TodayView: Manual refresh triggered...")
                            Task {
                                await calendarViewModel.refreshEvents()
                                await dailySummaryViewModel.refreshSummary()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(DesignSystem.Colors.primary)
                                .rotationEffect(.degrees(dailySummaryViewModel.isLoading ? 360 : 0))
                                .animation(
                                    dailySummaryViewModel.isLoading ? 
                                        Animation.linear(duration: 1).repeatForever(autoreverses: false) : 
                                        .default, 
                                    value: dailySummaryViewModel.isLoading
                                )
                        }
                        .disabled(dailySummaryViewModel.isLoading)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // Food Places Option (On-Demand)
                        Button(action: {
                            showingFoodSheet = true
                        }) {
                            Label("Food Places", systemImage: "fork.knife.circle")
                        }
                        
                        // Walking Options (On-Demand)
                        Button(action: {
                            showingWalkSheet = true
                        }) {
                            Label("Walking Options", systemImage: "figure.walk.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                }
            }
            .sheet(isPresented: $showingEventDetail) {
                if let eventId = selectedEventId {
                    EventDetailView(eventId: eventId)
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(initialDate: Date())
            }
            .sheet(isPresented: $showingFoodSheet) {
                NavigationView {
                    OnDemandFoodView(viewModel: onDemandViewModel)
                        .navigationTitle("Food Places")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingFoodSheet = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingWalkSheet) {
                NavigationView {
                    OnDemandWalkView(viewModel: onDemandViewModel)
                        .navigationTitle("Walking Options")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingWalkSheet = false
                                }
                            }
                        }
                }
            }
            .task {
                // Use .task instead of .onAppear to handle task cancellation properly
                print("🔄 TodayView: View appeared, loading data...")
                
                // Always re-check authorization when view appears
                await healthMetricsService.checkAuthorizationStatus()
                
                // Request location permission if not determined
                if locationManager.authorizationStatus == .notDetermined {
                    locationManager.requestLocationPermission()
                }
                
                // Load daily summary (includes location recommendations)
                await dailySummaryViewModel.loadSummary()
                
                print("✅ TodayView: Initial load complete")
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

// MARK: - Today Stats Header

struct TodayStatsHeader: View {
    let eventCount: Int
    let totalDuration: TimeInterval
    let firstEvent: Event?
    let lastEvent: Event?
    
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
    
    private var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Date and event count
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(dateFormatter.string(from: Date()))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.primaryText)
            
                Text(eventCount == 0 ? "No events scheduled" : "\(eventCount) event\(eventCount == 1 ? "" : "s") scheduled")
                    .font(.body)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Stats Grid
            if eventCount > 0 {
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Total Duration
                    StatBadge(
                        icon: "clock.fill",
                        value: formattedDuration,
                        label: "Total Time",
                        color: .blue
                    )
                    
                    // Event Count
                    StatBadge(
                        icon: "calendar.badge.clock",
                        value: "\(eventCount)",
                        label: eventCount == 1 ? "Meeting" : "Meetings",
                        color: .purple
                    )
                    
                    // Time Range
                    if let first = firstEvent?.startDate, let last = lastEvent?.endDate {
                        StatBadge(
                            icon: "arrow.right.circle.fill",
                            value: "\(timeFormatter.string(from: first)) - \(timeFormatter.string(from: last))",
                            label: "Time Span",
                            color: .green
                        )
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(color.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

// MARK: - Today Event Tile

struct TodayEventTile: View {
    let event: Event
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    private var duration: String {
        guard let start = event.startDate, let end = event.endDate else { return "" }
        let minutes = Int(end.timeIntervalSince(start)) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    // Source badge
                    Text(event.source.capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.3)))
                    
                    // Event title
                    Text(event.title)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Time and attendees
                    HStack(spacing: DesignSystem.Spacing.md) {
                        if let startDate = event.startDate, let endDate = event.endDate {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                Text("\(timeFormatter.string(from: startDate)) - \(timeFormatter.string(from: endDate))")
                                    .font(.subheadline)
                            }
                            .foregroundColor(.white.opacity(0.9))
                        }
                        
                        if let attendees = event.attendees, !attendees.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2")
                                    .font(.caption)
                                Text("\(attendees.count)")
                                    .font(.subheadline)
                            }
                            .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    
                    // Location
                    if let locationName = event.locationName, !locationName.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption)
                            Text(locationName)
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                        .foregroundColor(.white.opacity(0.9))
                    }
                }
                
                Spacer()
                
                // Duration badge
                Text(duration)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.25))
                    )
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .background(
            LinearGradient(
                colors: eventGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .shadow(color: event.sourceColorAsColor.opacity(0.4), radius: 12, x: 0, y: 4)
    }
    
    private var eventGradientColors: [Color] {
        let sourceColor = event.sourceColorAsColor
        return [sourceColor, sourceColor.opacity(0.75)]
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
        VStack(spacing: 0) {
            // Header with gradient background
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect HealthKit")
                        .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                    
                    Text("Get personalized insights")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                LinearGradient(
                    colors: [.pink, .red],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            // Content
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("AllTime analyzes your health data to provide:")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    FeatureBullet(icon: "moon.stars.fill", text: "Sleep quality insights")
                    FeatureBullet(icon: "figure.walk", text: "Activity recommendations")
                    FeatureBullet(icon: "drop.fill", text: "Hydration tracking")
                    FeatureBullet(icon: "heart.fill", text: "Recovery analysis")
                }
                
                Button(action: {
                    HealthAppHelper.openHealthAppSettings()
                }) {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Open Health Settings")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(
                        LinearGradient(
                            colors: [.pink, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(DesignSystem.CornerRadius.md)
                }
                .padding(.top, DesignSystem.Spacing.sm)
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 4)
    }
}

struct FeatureBullet: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primary)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.primaryText)
        }
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

// MARK: - Today Suggestions Section

struct TodaySuggestionsSection: View {
    let suggestions: [SuggestionItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.green)
                Text("Suggestions")
                    .font(.title3.weight(.bold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            
            VStack(spacing: DesignSystem.Spacing.md) {
                ForEach(suggestions) { suggestion in
                    TodaySuggestionCard(suggestion: suggestion)
                }
            }
        }
    }
}

// MARK: - Today Suggestion Card

struct TodaySuggestionCard: View {
    let suggestion: SuggestionItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(suggestion.headline)
                .font(.body)
                .fontWeight(.regular)
                .foregroundColor(DesignSystem.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
}

// MARK: - Today Health Suggestions Section

struct TodayHealthSuggestionsSection: View {
    let suggestions: [HealthBasedSuggestion]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Health-Based Suggestions")
                    .font(.title3.weight(.bold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            
            VStack(spacing: DesignSystem.Spacing.md) {
                ForEach(suggestions) { suggestion in
                    TodayHealthSuggestionCard(suggestion: suggestion)
                }
            }
        }
    }
}

// MARK: - Today Health Suggestion Card

struct TodayHealthSuggestionCard: View {
    let suggestion: HealthBasedSuggestion
    
    private var categoryColor: Color {
        switch suggestion.category.lowercased() {
        case "exercise": return .orange
        case "nutrition": return .green
        case "sleep": return .indigo
        case "stress": return .red
        case "hydration": return .blue
        case "time_management": return .cyan
        default: return .blue
        }
    }
    
    private var categoryIcon: String {
        suggestion.icon ?? {
            switch suggestion.category.lowercased() {
            case "exercise": return "figure.walk"
            case "nutrition": return "fork.knife"
            case "sleep": return "moon.fill"
            case "stress": return "heart.circle.fill"
            case "hydration": return "drop.fill"
            case "time_management": return "clock.fill"
            default: return "heart.fill"
            }
        }()
    }
    
    private var priorityColor: Color {
        switch suggestion.priority.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .green
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Category Badge
            HStack(spacing: DesignSystem.Spacing.sm) {
                if let icon = suggestion.icon {
                    Text(icon)
                        .font(.system(size: 14, weight: .semibold))
                } else {
                    Image(systemName: categoryIcon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(suggestion.category.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(categoryColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(categoryColor.opacity(0.2))
            .cornerRadius(8)
            
            // Title (main heading)
            Text(suggestion.title)
                .font(.title3.weight(.bold))
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            // Description (details)
            Text(suggestion.description)
                .font(.body)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
            
            // Footer with priority
            HStack {
                Spacer()
                
                Text(suggestion.priority.capitalized)
                    .font(.caption.weight(.bold))
                    .foregroundColor(priorityColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
}

// MARK: - Today Health Impact Section

struct TodayHealthImpactSection: View {
    let insights: HealthImpactInsights
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Health Impact Insights")
                    .font(.title3.weight(.bold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Summary text (clean up any JSON artifacts)
                if let summary = insights.summary, !summary.isEmpty {
                    let cleanedSummary = cleanJSONText(summary)
                    
                    Text(cleanedSummary)
                        .font(.body)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(6)
                }
                
                // Health Trends
                if let trends = insights.healthTrends {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Health Trends")
                            .font(.headline)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.sm) {
                            if let sleep = trends.sleep {
                                HealthTrendBadge(metric: "Sleep", trend: sleep)
                            }
                            if let steps = trends.steps {
                                HealthTrendBadge(metric: "Steps", trend: steps)
                            }
                            if let activeMinutes = trends.activeMinutes {
                                HealthTrendBadge(metric: "Active", trend: activeMinutes)
                            }
                            if let rhr = trends.restingHeartRate {
                                HealthTrendBadge(metric: "Heart Rate", trend: rhr)
                            }
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
    
    private func cleanJSONText(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "{\"summary\": \"", with: "")
            .replacingOccurrences(of: "\"}", with: "")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove any remaining JSON structure
        if cleaned.hasPrefix("{") {
            cleaned = String(cleaned.dropFirst())
        }
        if cleaned.hasSuffix("}") {
            cleaned = String(cleaned.dropLast())
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Health Trend Badge

struct HealthTrendBadge: View {
    let metric: String
    let trend: String
    
    private var trendColor: Color {
        switch trend.lowercased() {
        case "improving": return .green
        case "declining": return .red
        case "stable": return .orange
        default: return .gray
        }
    }
    
    private var trendIcon: String {
        switch trend.lowercased() {
        case "improving": return "arrow.up.right"
        case "declining": return "arrow.down.right"
        case "stable": return "arrow.right"
        default: return "minus"
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: trendIcon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(trendColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(metric)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                Text(trend.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(trendColor)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(trendColor.opacity(0.1))
        .cornerRadius(8)
    }
}
