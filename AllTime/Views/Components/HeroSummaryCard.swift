import SwiftUI

// MARK: - Hero Summary Card (Today's Overview)
/// The ONE tile that tells you everything about your day.
/// Design: Calendar-first - shows events prominently, health metrics compactly.
struct HeroSummaryCard: View {
    let overview: TodayOverviewResponse?
    let briefing: DailyBriefingResponse?
    let driftStatus: WeekDriftStatus?
    let freshHealth: DailyHealthMetrics?
    let intelligence: TimeIntelligenceResponse?
    let isLoading: Bool
    let onTap: () -> Void
    let onInterventionTap: (DriftIntervention) -> Void

    /// Today's events for displaying in the card
    var todayEvents: [Event] = []

    /// Callback when an event is tapped
    var onEventTap: ((Event) -> Void)? = nil

    /// Fallback meeting count from calendar events (used when intelligence is nil)
    var fallbackMeetingCount: Int = 0

    /// Whether to show sleep-related UI (false if user doesn't reliably track sleep)
    var showSleepUI: Bool = true

    // Animation
    @State private var animateIn = false
    @State private var pulseScale: CGFloat = 1.0

    // MARK: - Derived State

    /// Use briefing mood for daily status (not week drift severity)
    /// The briefing mood reflects TODAY's actual load, not accumulated week signals
    private var dailyStatusLabel: String {
        briefing?.moodLabel ?? "Today"
    }

    private var dailyStatusColor: Color {
        // Map briefing mood to appropriate color
        guard let moodValue = briefing?.mood.lowercased() else {
            return Color(hex: "10B981") // Default green
        }
        switch moodValue {
        case "balanced", "light_day", "light", "rest_day", "rest":
            return Color(hex: "10B981") // Green - good day
        case "focus_day", "focused":
            return Color(hex: "6366F1") // Indigo - focus mode
        case "intense_meetings", "intense", "busy":
            return Color(hex: "F59E0B") // Amber - busy but manageable
        case "overloaded", "critical":
            return Color(hex: "EF4444") // Red - actually overloaded
        default:
            return Color(hex: "10B981") // Default to green
        }
    }

    /// Only use drift severity for the intervention, not for the status badge
    private var severity: DriftSeverity {
        guard let drift = driftStatus else { return .onTrack }
        return DriftSeverity(rawValue: drift.severity) ?? .onTrack
    }

    private var severityColor: Color {
        // Use daily status color, not week drift color
        dailyStatusColor
    }

    private var primaryIntervention: DriftIntervention? {
        // Don't show intervention button if DailyInsightCard already shows the primary recommendation
        guard briefing?.primaryRecommendation == nil else { return nil }
        return driftStatus?.interventions.first
    }

    // MARK: - Computed Metrics

    private var sleepHours: Double {
        Double(freshHealth?.sleepMinutes ?? 0) / 60.0
    }

    private var steps: Int {
        freshHealth?.steps ?? 0
    }

    private var energyPercent: Int {
        // Prefer energyBudget.currentLevel (same source as the Energy Budget card)
        // to avoid showing conflicting numbers on the same screen
        if let level = briefing?.energyBudget?.currentLevel {
            return min(max(level, 0), 100)
        }
        return 100 - min(intelligence?.capacityOverloadPercent ?? 50, 100)
    }

    private var meetingCount: Int {
        // Use intelligence data if available, otherwise fall back to calendar events count
        intelligence?.metrics?.meetingCount ?? fallbackMeetingCount
    }

    private var focusMinutes: Int {
        intelligence?.metrics?.largestFocusBlockMinutes ?? 0
    }

    // MARK: - Fallback Metrics (when sleep is unavailable)

    private var restingHeartRate: Double? {
        freshHealth?.restingHeartRate
    }

    private var activeCalories: Double? {
        freshHealth?.activeEnergyBurned
    }

    private var activeMinutes: Int? {
        freshHealth?.activeMinutes
    }

    /// Determine which metrics to show based on data availability
    /// Returns: (firstMetric, secondMetric) where each is a tuple of (icon, value, unit, label, color, changePercent)
    private var adaptiveMetrics: [(icon: String, value: String, unit: String, label: String, color: Color, changePercent: Int?)] {
        var metrics: [(icon: String, value: String, unit: String, label: String, color: Color, changePercent: Int?)] = []

        // First priority: Sleep (if available AND user reliably tracks sleep)
        if showSleepUI && sleepHours > 0 {
            metrics.append((
                icon: "moon.fill",
                value: String(format: "%.1f", sleepHours),
                unit: "h",
                label: "Sleep",
                color: sleepColor,
                changePercent: sleepChangePercent
            ))
        } else if let hr = restingHeartRate, hr > 0 {
            // Fallback 1: Resting Heart Rate
            metrics.append((
                icon: "heart.fill",
                value: String(format: "%.0f", hr),
                unit: "bpm",
                label: "Heart Rate",
                color: heartRateColor(hr),
                changePercent: nil
            ))
        } else if let cal = activeCalories, cal > 0 {
            // Fallback 2: Active Calories
            metrics.append((
                icon: "flame.fill",
                value: formatCalories(cal),
                unit: "",
                label: "Calories",
                color: caloriesColor(cal),
                changePercent: nil
            ))
        } else if let mins = activeMinutes, mins > 0 {
            // Fallback 3: Active Minutes
            metrics.append((
                icon: "figure.run",
                value: "\(mins)",
                unit: "m",
                label: "Active",
                color: activeMinutesColor(mins),
                changePercent: nil
            ))
        } else if showSleepUI {
            // Default: Show sleep as "--" (only if user reliably tracks sleep)
            metrics.append((
                icon: "moon.fill",
                value: "--",
                unit: "h",
                label: "Sleep",
                color: DesignSystem.Colors.secondaryText,
                changePercent: nil
            ))
        }

        // Second: Steps (always show if available, otherwise show alternative)
        if steps > 0 {
            metrics.append((
                icon: "figure.walk",
                value: formatSteps(steps),
                unit: "",
                label: "Steps",
                color: stepsColor,
                changePercent: stepsChangePercent
            ))
        } else if let mins = activeMinutes, mins > 0, showSleepUI && sleepHours > 0 {
            // Show active minutes if we already showed sleep
            metrics.append((
                icon: "figure.run",
                value: "\(mins)",
                unit: "m",
                label: "Active",
                color: activeMinutesColor(mins),
                changePercent: nil
            ))
        } else if let cal = activeCalories, cal > 0, showSleepUI && sleepHours > 0 {
            // Show calories if we showed sleep
            metrics.append((
                icon: "flame.fill",
                value: formatCalories(cal),
                unit: "",
                label: "Calories",
                color: caloriesColor(cal),
                changePercent: nil
            ))
        } else {
            // Default: Show steps as "--"
            metrics.append((
                icon: "figure.walk",
                value: "--",
                unit: "",
                label: "Steps",
                color: DesignSystem.Colors.secondaryText,
                changePercent: nil
            ))
        }

        // Third: Energy (always show)
        metrics.append((
            icon: "bolt.fill",
            value: "\(energyPercent)",
            unit: "%",
            label: "Energy",
            color: energyColor,
            changePercent: energyChangePercent
        ))

        // Fourth: Meetings (always show)
        metrics.append((
            icon: "calendar",
            value: "\(meetingCount)",
            unit: "",
            label: "Meetings",
            color: meetingsColor,
            changePercent: meetingsChangePercent
        ))

        return metrics
    }

    // Color helpers for fallback metrics
    private func heartRateColor(_ hr: Double) -> Color {
        if hr >= 60 && hr <= 80 { return DesignSystem.Colors.emerald }
        if hr >= 50 && hr <= 90 { return DesignSystem.Colors.blue }
        return DesignSystem.Colors.amber
    }

    private func caloriesColor(_ cal: Double) -> Color {
        if cal >= 400 { return DesignSystem.Colors.emerald }
        if cal >= 200 { return DesignSystem.Colors.blue }
        return DesignSystem.Colors.amber
    }

    private func activeMinutesColor(_ mins: Int) -> Color {
        if mins >= 30 { return DesignSystem.Colors.emerald }
        if mins >= 15 { return DesignSystem.Colors.blue }
        return DesignSystem.Colors.amber
    }

    private func formatCalories(_ cal: Double) -> String {
        if cal >= 1000 {
            return String(format: "%.1fk", cal / 1000)
        }
        return String(format: "%.0f", cal)
    }

    // MARK: - Percentage Change Calculations (vs average)

    private var sleepChangePercent: Int? {
        guard let current = freshHealth?.sleepMinutes, current > 0,
              let avgHours = briefing?.keyMetrics?.sleepHoursAverage, avgHours > 0 else { return nil }
        let currentHours = Double(current) / 60.0
        let change = ((currentHours - avgHours) / avgHours) * 100
        return Int(change.rounded())
    }

    private var stepsChangePercent: Int? {
        guard let current = freshHealth?.steps, current > 0,
              let avg = briefing?.keyMetrics?.stepsAverage, avg > 0 else { return nil }
        let change = ((Double(current) - Double(avg)) / Double(avg)) * 100
        return Int(change.rounded())
    }

    private var meetingsChangePercent: Int? {
        guard let avgCount = briefing?.keyMetrics?.meetingsAverageCount, avgCount > 0 else { return nil }
        let change = ((Double(meetingCount) - avgCount) / avgCount) * 100
        return Int(change.rounded())
    }

    private var energyChangePercent: Int? {
        // Energy doesn't have a direct "yesterday" comparison, so we'll skip it
        // Could be enhanced later with historical data
        return nil
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if isLoading && driftStatus == nil && overview == nil {
                loadingState
            } else {
                mainContent
            }
        }
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .compositingGroup()
        .shadow(color: severityColor.opacity(0.15), radius: 8, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateIn = true
            }
            startPulseAnimation()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 12) {
            // Header: Day progress circle + Date + Status badge
            headerSection
                .padding(.horizontal, 20)
                .padding(.top, 20)

            // COMPACT Health Row: Just 2 key metrics (was 4)
            compactHealthRow
                .padding(.horizontal, 16)

            // EVENTS TODAY: Show upcoming meetings with context
            eventsSection
                .padding(.horizontal, 16)

            // Action button (if needed)
            if let intervention = primaryIntervention {
                actionButton(intervention)
                    .padding(.horizontal, 16)
            }

            Spacer().frame(height: 12)
        }
    }

    // MARK: - Compact Health Row (2 metrics instead of 4)

    private var compactHealthRow: some View {
        let metrics = compactMetrics
        return HStack(spacing: 8) {
            ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                CompactMetricTile(
                    icon: metric.icon,
                    value: metric.value,
                    unit: metric.unit,
                    label: metric.label,
                    color: metric.color,
                    changePercent: metric.changePercent
                )
            }
        }
    }

    /// Only 2 key metrics for compact display
    private var compactMetrics: [(icon: String, value: String, unit: String, label: String, color: Color, changePercent: Int?)] {
        var metrics: [(icon: String, value: String, unit: String, label: String, color: Color, changePercent: Int?)] = []

        // First: Energy (most actionable metric)
        metrics.append((
            icon: "bolt.fill",
            value: "\(energyPercent)",
            unit: "%",
            label: "Energy",
            color: energyColor,
            changePercent: nil
        ))

        // Second: Meetings count
        metrics.append((
            icon: "calendar",
            value: "\(meetingCount)",
            unit: "",
            label: "Meetings",
            color: meetingsColor,
            changePercent: meetingsChangePercent
        ))

        return metrics
    }

    // MARK: - Events Section

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Day context summary
            if !dayContextSummary.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: dayContextIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(dayContextColor)
                    Text(dayContextSummary)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // Upcoming events (max 3)
            let upcomingEvents = getUpcomingEvents()
            if upcomingEvents.isEmpty {
                // No events state
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.emerald)
                    Text("No meetings scheduled")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(upcomingEvents.prefix(3), id: \.id) { event in
                        EventPreviewRow(event: event, onTap: {
                            onEventTap?(event)
                        })
                    }

                    // Show "more events" if there are more
                    if upcomingEvents.count > 3 {
                        HStack {
                            Spacer()
                            Text("+ \(upcomingEvents.count - 3) more")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
    }

    // MARK: - Day Context Helpers

    private func getUpcomingEvents() -> [Event] {
        let now = Date()
        return todayEvents
            .filter { event in
                guard let endDate = event.endDate ?? event.startDate else { return false }
                // Show events that haven't ended yet
                return endDate > now && !event.allDay
            }
            .sorted { event1, event2 in
                guard let start1 = event1.startDate, let start2 = event2.startDate else { return false }
                return start1 < start2
            }
    }

    private var dayContextSummary: String {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)

        let upcomingEvents = getUpcomingEvents()
        let timedEvents = todayEvents.filter { !$0.allDay }

        if timedEvents.isEmpty {
            return "Clear schedule today"
        }

        // Check morning (before noon)
        let morningEvents = timedEvents.filter { event in
            guard let start = event.startDate else { return false }
            let eventHour = calendar.component(.hour, from: start)
            return eventHour < 12
        }

        // Check afternoon (noon to 5pm)
        let afternoonEvents = timedEvents.filter { event in
            guard let start = event.startDate else { return false }
            let eventHour = calendar.component(.hour, from: start)
            return eventHour >= 12 && eventHour < 17
        }

        // Check evening (5pm+)
        let eveningEvents = timedEvents.filter { event in
            guard let start = event.startDate else { return false }
            let eventHour = calendar.component(.hour, from: start)
            return eventHour >= 17
        }

        // Generate contextual summary based on current time
        if hour < 12 {
            // Morning
            if morningEvents.count >= 3 {
                if let lastMorning = morningEvents.sorted(by: { ($0.endDate ?? $0.startDate ?? now) < ($1.endDate ?? $1.startDate ?? now) }).last,
                   let endTime = lastMorning.endDate {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "h:mm a"
                    return "Morning busy until \(formatter.string(from: endTime))"
                }
                return "Morning is packed"
            } else if afternoonEvents.count >= 3 {
                return "Afternoon is full"
            } else if let nextEvent = upcomingEvents.first, let startTime = nextEvent.startDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                return "Free until \(formatter.string(from: startTime))"
            }
        } else if hour < 17 {
            // Afternoon
            if afternoonEvents.count >= 3 {
                return "Afternoon is packed"
            } else if eveningEvents.count >= 2 {
                return "Evening has meetings"
            } else if let nextEvent = upcomingEvents.first, let startTime = nextEvent.startDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                return "Next at \(formatter.string(from: startTime))"
            }
        } else {
            // Evening
            if eveningEvents.count >= 2 {
                return "Evening is busy"
            } else if upcomingEvents.isEmpty {
                return "Day is winding down"
            }
        }

        // Default based on total count
        if timedEvents.count >= 5 {
            return "Busy day ahead"
        } else if timedEvents.count >= 3 {
            return "\(timedEvents.count) meetings today"
        }

        return ""
    }

    private var dayContextIcon: String {
        let summary = dayContextSummary.lowercased()
        if summary.contains("packed") || summary.contains("full") || summary.contains("busy") {
            return "exclamationmark.circle.fill"
        } else if summary.contains("free") || summary.contains("clear") || summary.contains("winding") {
            return "checkmark.circle.fill"
        }
        return "info.circle.fill"
    }

    private var dayContextColor: Color {
        let summary = dayContextSummary.lowercased()
        if summary.contains("packed") || summary.contains("full") || summary.contains("busy") {
            return DesignSystem.Colors.amber
        } else if summary.contains("free") || summary.contains("clear") {
            return DesignSystem.Colors.emerald
        }
        return DesignSystem.Colors.blue
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 16) {
            // Day progress circle with weather
            dayProgressCircle

            // Date and greeting
            VStack(alignment: .leading, spacing: 4) {
                Text(dayName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(dateString)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Status badge
            statusBadge
        }
    }

    // MARK: - Day Progress Circle

    private var dayProgressCircle: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 56, height: 56)

            // Progress ring (day completion)
            Circle()
                .trim(from: 0, to: dayProgress)
                .stroke(
                    DesignSystem.Colors.emerald,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(-90))

            // Content: Short day + weather icon
            VStack(spacing: 2) {
                Text(shortDayName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Image(systemName: weatherIcon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(weatherColor)
            }
        }
        .scaleEffect(animateIn ? 1.0 : 0.8)
        .opacity(animateIn ? 1.0 : 0)
    }

    /// Calculate day progress (0.0 to 1.0) based on working hours (8am - 10pm)
    private var dayProgress: CGFloat {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)

        let startHour = 8  // 8 AM
        let endHour = 22   // 10 PM
        let totalHours = endHour - startHour

        let currentMinutes = (hour - startHour) * 60 + minute
        let totalMinutes = totalHours * 60

        if hour < startHour { return 0.0 }
        if hour >= endHour { return 1.0 }

        return CGFloat(currentMinutes) / CGFloat(totalMinutes)
    }

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }

    private var shortDayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: Date()).uppercased()
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: Date())
    }

    /// Weather icon based on time of day (placeholder - can be enhanced with actual weather API)
    private var weatherIcon: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 6 && hour < 18 {
            return "sun.max.fill"  // Daytime
        } else {
            return "moon.fill"     // Nighttime
        }
    }

    private var weatherColor: Color {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 6 && hour < 18 {
            return DesignSystem.Colors.amber  // Sun color
        } else {
            return DesignSystem.Colors.blue   // Moon color
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dailyStatusColor)
                .frame(width: 8, height: 8)
                .scaleEffect(pulseScale)

            Text(dailyStatusLabel)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(dailyStatusColor.opacity(0.2))
        )
    }

    // MARK: - Metrics Grid (No Scrolling)

    private var metricsGrid: some View {
        let metrics = adaptiveMetrics
        return HStack(spacing: 10) {
            ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                HeroMetricTile(
                    icon: metric.icon,
                    value: metric.value,
                    unit: metric.unit,
                    label: metric.label,
                    color: metric.color,
                    delay: Double(index) * 0.05,
                    changePercent: metric.changePercent
                )
            }
        }
    }

    // MARK: - Action Button

    private func actionButton(_ intervention: DriftIntervention) -> some View {
        Button {
            HapticManager.shared.mediumTap()
            onInterventionTap(intervention)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: intervention.icon)
                    .font(.system(size: 16, weight: .semibold))

                Text(intervention.shortAction)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(severityColor.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(severityColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ActionButtonStyle())
    }

    // MARK: - Card Background
    /// Optimized: Removed GeometryReader for 60fps, uses static pattern

    private var cardBackground: some View {
        ZStack {
            // Base
            LinearGradient(
                colors: [Color(hex: "1C1C2E"), Color(hex: "141420")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Ambient glow based on status
            RadialGradient(
                colors: [severityColor.opacity(severity == .onTrack ? 0.08 : 0.15), Color.clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 300
            )

            // Subtle pattern overlay - static, no GeometryReader for 60fps
            // Using a fixed-size pattern that tiles naturally
            DiagonalPatternView()
                .opacity(0.02)
        }
        .drawingGroup()  // GPU compositing for smooth scrolling
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 20) {
            // Header skeleton
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 120, height: 28)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 60, height: 14)
                }
                Spacer()
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 80, height: 32)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            // Hero skeleton
            HStack(spacing: 16) {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 72, height: 72)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.3)))
                    )

                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 160, height: 18)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 100, height: 14)
                }
                Spacer()
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.03)))
            .padding(.horizontal, 24)

            // Metrics skeleton
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 80)
                }
            }
            .padding(.horizontal, 20)

            Spacer().frame(height: 20)
        }
    }

    // MARK: - Colors

    private var sleepColor: Color {
        if sleepHours >= 7 { return DesignSystem.Colors.emerald }
        if sleepHours >= 6 { return DesignSystem.Colors.amber }
        if sleepHours > 0 { return DesignSystem.Colors.errorRed }
        return DesignSystem.Colors.secondaryText
    }

    private var stepsColor: Color {
        if steps >= 8000 { return DesignSystem.Colors.emerald }
        if steps >= 5000 { return DesignSystem.Colors.blue }
        if steps > 0 { return DesignSystem.Colors.amber }
        return DesignSystem.Colors.secondaryText
    }

    private var energyColor: Color {
        if energyPercent >= 60 { return DesignSystem.Colors.emerald }
        if energyPercent >= 30 { return DesignSystem.Colors.amber }
        return DesignSystem.Colors.errorRed
    }

    private var meetingsColor: Color {
        if meetingCount >= 6 { return DesignSystem.Colors.errorRed }
        if meetingCount >= 4 { return DesignSystem.Colors.amber }
        return DesignSystem.Colors.blue
    }

    // MARK: - Helpers

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000)
        }
        return "\(steps)"
    }

    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.2
        }
    }
}

// MARK: - Compact Metric Tile (for 2-metric row)

private struct CompactMetricTile: View {
    let icon: String
    let value: String
    let unit: String
    let label: String
    let color: Color
    var changePercent: Int? = nil

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )

            // Value and label
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 2) {
                    Text(value)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    // Change indicator
                    if let change = changePercent, change != 0 {
                        HStack(spacing: 1) {
                            Image(systemName: change > 0 ? "arrow.up" : "arrow.down")
                                .font(.system(size: 8, weight: .bold))
                            Text("\(abs(change))%")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(label == "Meetings" ? (change > 0 ? DesignSystem.Colors.errorRed : DesignSystem.Colors.emerald) : (change >= 0 ? DesignSystem.Colors.emerald : DesignSystem.Colors.errorRed))
                    }
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
        )
    }
}

// MARK: - Event Preview Row

private struct EventPreviewRow: View {
    let event: Event
    let onTap: () -> Void

    private var eventColor: Color {
        // Use source-based color
        switch event.source.lowercased() {
        case "google":
            return Color(hex: "4285F4")
        case "microsoft":
            return Color(hex: "FF6B35")
        case "eventkit", "apple":
            return Color(hex: "AF52DE")
        default:
            return DesignSystem.Colors.primary
        }
    }

    private var timeString: String {
        guard let startDate = event.startDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startDate)
    }

    private var isCurrentEvent: Bool {
        guard let start = event.startDate, let end = event.endDate else { return false }
        let now = Date()
        return now >= start && now <= end
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Color bar
                Rectangle()
                    .fill(eventColor)
                    .frame(width: 3, height: 36)
                    .cornerRadius(1.5)

                // Time
                Text(timeString)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(isCurrentEvent ? DesignSystem.Colors.emerald : .white.opacity(0.6))
                    .frame(width: 60, alignment: .leading)

                // Title
                Text(event.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)

                Spacer()

                // Current indicator
                if isCurrentEvent {
                    Text("NOW")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.emerald)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.emerald.opacity(0.2))
                        )
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(isCurrentEvent ? 0.08 : 0.04))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Hero Metric Tile (Original, kept for compatibility)

private struct HeroMetricTile: View {
    let icon: String
    let value: String
    let unit: String
    let label: String
    let color: Color
    let delay: Double
    var changePercent: Int? = nil  // Optional: percentage change from average/yesterday

    @State private var animateIn = false

    private var changeColor: Color {
        guard let change = changePercent else { return .white }
        // For sleep and steps: positive is good (green), negative is bad (red)
        // For meetings: positive is bad (more meetings = red), negative is good (green)
        if label == "Meetings" {
            return change > 0 ? DesignSystem.Colors.errorRed : DesignSystem.Colors.emerald
        }
        return change >= 0 ? DesignSystem.Colors.emerald : DesignSystem.Colors.errorRed
    }

    private var changeIcon: String {
        guard let change = changePercent else { return "" }
        return change > 0 ? "arrow.up" : (change < 0 ? "arrow.down" : "minus")
    }

    var body: some View {
        VStack(spacing: 6) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)

            // Value
            HStack(spacing: 1) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .offset(y: -2)
                }
            }

            // Change indicator (if available)
            if let change = changePercent, change != 0 {
                HStack(spacing: 2) {
                    Image(systemName: changeIcon)
                        .font(.system(size: 8, weight: .bold))
                    Text("\(abs(change))%")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(changeColor)
            } else {
                // Label when no change data
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.1))
        )
        .scaleEffect(animateIn ? 1.0 : 0.8)
        .opacity(animateIn ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay)) {
                animateIn = true
            }
        }
    }
}

// MARK: - Scale Button Style

private struct HeroScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

// MARK: - Action Button Style (prevents tap propagation)

private struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Drift Severity Extensions

extension DriftSeverity {
    var emoji: String {
        switch self {
        case .onTrack: return "✨"
        case .watch: return "👀"
        case .drifting: return "⚡"
        case .critical: return "🔥"
        }
    }

    var shortLabel: String {
        switch self {
        case .onTrack: return "On track"
        case .watch: return "Watch"
        case .drifting: return "Drifting"
        case .critical: return "Overloaded"
        }
    }
}

// MARK: - Drift Intervention Extension

extension DriftIntervention {
    var shortAction: String {
        let words = action.split(separator: " ").prefix(4)
        return words.joined(separator: " ")
    }
}

// MARK: - Backward Compatibility

extension HeroSummaryCard {
    init(
        overview: TodayOverviewResponse?,
        briefing: DailyBriefingResponse?,
        isLoading: Bool,
        onTap: @escaping () -> Void
    ) {
        self.overview = overview
        self.briefing = briefing
        self.driftStatus = nil
        self.freshHealth = nil
        self.intelligence = nil
        self.isLoading = isLoading
        self.onTap = onTap
        self.onInterventionTap = { _ in }
        self.todayEvents = []
        self.onEventTap = nil
    }

    init(
        overview: TodayOverviewResponse?,
        briefing: DailyBriefingResponse?,
        driftStatus: WeekDriftStatus?,
        isLoading: Bool,
        onTap: @escaping () -> Void,
        onInterventionTap: @escaping (DriftIntervention) -> Void
    ) {
        self.overview = overview
        self.briefing = briefing
        self.driftStatus = driftStatus
        self.freshHealth = nil
        self.intelligence = nil
        self.isLoading = isLoading
        self.onTap = onTap
        self.onInterventionTap = onInterventionTap
        self.todayEvents = []
        self.onEventTap = nil
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        HeroSummaryCard(
            overview: nil,
            briefing: nil,
            driftStatus: nil,
            freshHealth: nil,
            intelligence: nil,
            isLoading: false,
            onTap: {},
            onInterventionTap: { _ in }
        )
    }
    .padding()
    .background(DesignSystem.Colors.background)
}

// MARK: - Optimized Diagonal Pattern (no GeometryReader)
/// Static diagonal pattern that doesn't recalculate on every frame
/// Used for subtle card backgrounds without performance penalty
private struct DiagonalPatternView: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 30
            let lineCount = Int(max(size.width, size.height) / spacing) + 5

            var path = Path()
            for i in -5..<lineCount {
                let x = CGFloat(i) * spacing
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + size.height, y: size.height))
            }

            context.stroke(path, with: .color(.white), lineWidth: 1)
        }
    }
}
