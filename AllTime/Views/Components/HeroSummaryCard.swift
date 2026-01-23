import SwiftUI

// MARK: - Hero Summary Card (Today's Overview)
/// The ONE tile that tells you everything about your day.
/// Design: Glanceable in < 1 second. Color = status. No scrolling.
struct HeroSummaryCard: View {
    let overview: TodayOverviewResponse?
    let briefing: DailyBriefingResponse?
    let driftStatus: WeekDriftStatus?
    let freshHealth: DailyHealthMetrics?
    let intelligence: TimeIntelligenceResponse?
    let isLoading: Bool
    let onTap: () -> Void
    let onInterventionTap: (DriftIntervention) -> Void

    // Animation
    @State private var animateIn = false
    @State private var pulseScale: CGFloat = 1.0

    // MARK: - Derived State

    private var severity: DriftSeverity {
        guard let drift = driftStatus else { return .onTrack }
        return DriftSeverity(rawValue: drift.severity) ?? .onTrack
    }

    private var severityColor: Color {
        Color(hex: severity.color)
    }

    private var primaryIntervention: DriftIntervention? {
        driftStatus?.interventions.first
    }

    // MARK: - Computed Metrics

    private var sleepHours: Double {
        Double(freshHealth?.sleepMinutes ?? 0) / 60.0
    }

    private var steps: Int {
        freshHealth?.steps ?? 0
    }

    private var energyPercent: Int {
        100 - min(intelligence?.capacityOverloadPercent ?? 50, 100)
    }

    private var meetingCount: Int {
        intelligence?.metrics?.meetingCount ?? 0
    }

    private var focusMinutes: Int {
        intelligence?.metrics?.largestFocusBlockMinutes ?? 0
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
        Button(action: onTap) {
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
            .shadow(color: severityColor.opacity(0.2), radius: 20, y: 10)
        }
        .buttonStyle(HeroScaleButtonStyle())
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateIn = true
            }
            startPulseAnimation()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 16) {
            // Header: Day progress circle + Date + Status badge
            headerSection
                .padding(.horizontal, 20)
                .padding(.top, 20)

            // Metrics Grid: 4 metrics, always visible, no scrolling
            metricsGrid
                .padding(.horizontal, 16)

            // Action button (if needed)
            if let intervention = primaryIntervention {
                actionButton(intervention)
                    .padding(.horizontal, 16)
            }

            Spacer().frame(height: 16)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 16) {
            // Day progress circle with weather
            dayProgressCircle

            // Date and greeting
            VStack(alignment: .leading, spacing: 4) {
                Text(dayName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

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
                .fill(severityColor)
                .frame(width: 8, height: 8)
                .scaleEffect(pulseScale)

            Text(severity.shortLabel)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(severityColor.opacity(0.2))
        )
    }

    // MARK: - Metrics Grid (No Scrolling)

    private var metricsGrid: some View {
        HStack(spacing: 10) {
            // Sleep
            HeroMetricTile(
                icon: "moon.fill",
                value: sleepHours > 0 ? String(format: "%.1f", sleepHours) : "--",
                unit: "h",
                label: "Sleep",
                color: sleepColor,
                delay: 0.0,
                changePercent: sleepChangePercent
            )

            // Steps
            HeroMetricTile(
                icon: "figure.walk",
                value: steps > 0 ? formatSteps(steps) : "--",
                unit: "",
                label: "Steps",
                color: stepsColor,
                delay: 0.05,
                changePercent: stepsChangePercent
            )

            // Energy
            HeroMetricTile(
                icon: "bolt.fill",
                value: "\(energyPercent)",
                unit: "%",
                label: "Energy",
                color: energyColor,
                delay: 0.1,
                changePercent: energyChangePercent
            )

            // Meetings
            HeroMetricTile(
                icon: "calendar",
                value: "\(meetingCount)",
                unit: "",
                label: "Meetings",
                color: meetingsColor,
                delay: 0.15,
                changePercent: meetingsChangePercent
            )
        }
    }

    // MARK: - Action Button

    private func actionButton(_ intervention: DriftIntervention) -> some View {
        Button(action: {
            HapticManager.shared.mediumTap()
            onInterventionTap(intervention)
        }) {
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
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Card Background

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

            // Subtle pattern overlay
            GeometryReader { geo in
                Path { path in
                    let spacing: CGFloat = 30
                    for i in 0..<Int(geo.size.width / spacing) {
                        let x = CGFloat(i) * spacing
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x + geo.size.height, y: geo.size.height))
                    }
                }
                .stroke(Color.white.opacity(0.02), lineWidth: 1)
            }
        }
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

// MARK: - Hero Metric Tile

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
