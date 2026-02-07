import SwiftUI
import Combine
import Charts

/// Comprehensive Health Insights view with backend AI analysis
struct HealthInsightsDetailView: View {
    @StateObject private var viewModel = HealthInsightsDetailViewModel()
    @State private var selectedRange: DateRange = .last7Days
    @ObservedObject private var healthMetricsService = HealthMetricsService.shared
    @ObservedObject private var healthSyncService = HealthSyncService.shared
    
    enum DateRange: String, CaseIterable {
        case last7Days = "Last 7 Days"
        case last14Days = "Last 14 Days"
        case last30Days = "Last 30 Days"
        
        var days: Int {
            switch self {
            case .last7Days: return 7
            case .last14Days: return 14
            case .last30Days: return 30
            }
        }
        
        var startDate: Date {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            return calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Date Range Picker
                Picker("Range", selection: $selectedRange) {
                    ForEach(DateRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.top, DesignSystem.Spacing.sm)
                .onChange(of: selectedRange) { oldValue, newValue in
                    print("📊 HealthInsightsView: Date range changed from '\(oldValue.rawValue)' to '\(newValue.rawValue)'")
                    print("📊 HealthInsightsView: New range: \(newValue.days) days (from \(newValue.startDate))")
                    Task {
                        await viewModel.loadInsights(startDate: newValue.startDate, endDate: Date(), forceRefresh: false)
                    }
                }

                // Check HealthKit authorization status
                if !healthMetricsService.isAuthorized {
                    HealthInsightsPermissionRequiredView(
                        onPermissionGranted: {
                            Task {
                                await viewModel.loadInsights(startDate: selectedRange.startDate, endDate: Date(), forceRefresh: false)
                                await viewModel.refreshLocalChart(rangeDays: selectedRange.days)
                            }
                        }
                    )
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.top, 50)
                } else if viewModel.isLoading && viewModel.insights == nil {
                    // Only show loading if we don't have any data (including cached)
                    ProgressView("Loading insights...")
                        .padding(.top, 100)
                } else if let error = viewModel.errorMessage {
                    HealthInsightsErrorView(message: error) {
                        Task {
                            await viewModel.loadInsights(startDate: selectedRange.startDate, endDate: Date(), forceRefresh: false)
                            await viewModel.refreshLocalChart(rangeDays: selectedRange.days)
                        }
                    }
                } else if let insights = viewModel.insights {
                    VStack(spacing: 16) {
                        // 1. QUICK METRICS - scannable numbers at a glance
                        HealthQuickMetrics(stats: insights.summaryStats)

                        // 2. PATTERN HERO - the key insight, most prominent
                        if !insights.insights.isEmpty {
                            PatternHeroCard(insight: insights.insights[0])
                        }

                        // 3. OBSERVATIONS - what happened (muted, secondary)
                        if !insights.aiNarrative.keyTakeaways.isEmpty {
                            ObservationsSection(observations: insights.aiNarrative.keyTakeaways)
                        }

                        // 4. ACTION - what to do (distinct amber treatment)
                        if let firstSuggestion = insights.aiNarrative.suggestions.first {
                            HealthActionCard(suggestion: firstSuggestion)
                        }

                        // 5. VITALS - heart metrics only (non-redundant)
                        if let breakdown = insights.healthBreakdown {
                            VitalsSection(breakdown: breakdown)
                        }

                        // 6. TRENDS - detailed metric changes
                        if let trends = insights.trendAnalysis, !trends.isEmpty {
                            HealthTrendsSection(trends: trends)
                        }

                        // 7. DAILY CHART - visual data
                        WeeklyHealthChartsSection(metrics: viewModel.chartMetrics)
                            .padding(.bottom, 100)
                    }
                    .padding(.horizontal, 12)
                } else {
                    HealthInsightsEmptyState()
                }
            }
        }
        .background(DesignSystem.Colors.background)
        .refreshable {
            // User explicitly pulled to refresh - force refresh
            if healthMetricsService.isAuthorized {
                await viewModel.loadInsights(startDate: selectedRange.startDate, endDate: Date(), forceRefresh: true)
                await viewModel.refreshLocalChart(rangeDays: selectedRange.days)
            }
        }
        .onAppear {
            // Always re-check authorization when view appears (user may have enabled in Settings)
            Task {
                await healthMetricsService.checkAuthorizationStatus()
                await viewModel.refreshLocalChart(rangeDays: selectedRange.days)

                // ALWAYS try to load from cache first (even if insights exist in memory)
                // This ensures we show cached data immediately after tab switches
                if healthMetricsService.isAuthorized {
                    // Load from cache first - this will populate insights if cache exists
                    await viewModel.loadInsights(startDate: selectedRange.startDate, endDate: Date(), forceRefresh: false)
                }
            }
        }
        .onChange(of: healthMetricsService.isAuthorized) { oldValue, newValue in
            // When authorization changes from false to true, automatically load insights
            if !oldValue && newValue {
                Task {
                    // Small delay to ensure sync completes
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    await viewModel.loadInsights(startDate: selectedRange.startDate, endDate: Date(), forceRefresh: false)
                    await viewModel.refreshLocalChart(rangeDays: selectedRange.days)
                }
            }
        }
        .onChange(of: healthSyncService.lastSyncDate) { _, _ in
            Task {
                await viewModel.refreshLocalChart(rangeDays: selectedRange.days)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HealthGoalsUpdated"))) { _ in
            // Regenerate insights when goals are updated (invalidate cache first)
            print("📊 HealthInsightsView: Health goals updated, invalidating cache and regenerating insights...")
            Task {
                // Invalidate cache by clearing it, then reload
                await viewModel.invalidateCache()
                await viewModel.loadInsights(startDate: selectedRange.startDate, endDate: Date(), forceRefresh: false)
            }
        }
    }
}

// MARK: - Quick Metrics Row (Top-level scannable numbers)
struct HealthQuickMetrics: View {
    let stats: SummaryStats

    private var metrics: [(icon: String, value: String, label: String, color: Color)] {
        var result: [(icon: String, value: String, label: String, color: Color)] = []
        if let steps = stats.avgSteps, steps > 0 {
            result.append(("figure.walk", formatSteps(Int(steps)), "steps", .blue))
        }
        if let sleep = stats.avgSleepMinutes, sleep > 0 {
            result.append(("moon.fill", String(format: "%.1f", sleep / 60.0), "hrs sleep", .indigo))
        }
        if let active = stats.avgActiveMinutes, active > 0 {
            result.append(("flame.fill", "\(Int(active))", "min active", .orange))
        }
        if let workouts = stats.totalWorkouts, workouts > 0 {
            result.append(("figure.run", "\(workouts)", "workouts", .green))
        }
        return result
    }

    var body: some View {
        if !metrics.isEmpty {
            HStack(spacing: 0) {
                ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                    HealthMetricCell(
                        icon: metric.icon,
                        value: metric.value,
                        label: metric.label,
                        color: metric.color
                    )
                    if index < metrics.count - 1 {
                        Divider()
                            .frame(height: 32)
                            .background(DesignSystem.Colors.tertiaryText.opacity(0.3))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignSystem.Colors.cardBackground)
            )
        }
    }

    private func formatSteps(_ steps: Int) -> String {
        steps >= 1000 ? String(format: "%.1fk", Double(steps) / 1000.0) : "\(steps)"
    }
}

// MARK: - Health Metric Cell (Equal width metric display)
struct HealthMetricCell: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Health Quick Pill (Compact metric indicator - kept for compatibility)
struct HealthQuickPill: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
    }
}

// MARK: - Pattern Hero Card (Primary Insight)
struct PatternHeroCard: View {
    let insight: InsightItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section label with icon
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.violet)
                Text("KEY INSIGHT")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.violet)
                    .tracking(0.5)
            }

            // Pattern title
            Text(insight.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)

            // Supporting detail
            if !insight.details.isEmpty {
                Text(insight.details)
                    .font(.system(size: 15))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .lineSpacing(4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.violet.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(DesignSystem.Colors.violet.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Observations Section (Secondary - What Happened)
struct ObservationsSection: View {
    let observations: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                Text("OBSERVATIONS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .tracking(0.5)
            }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(observations.enumerated()), id: \.offset) { index, observation in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                            .frame(width: 18, height: 18)
                            .background(
                                Circle()
                                    .fill(DesignSystem.Colors.tertiaryText.opacity(0.15))
                            )

                        Text(observation)
                            .font(.system(size: 15))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .lineSpacing(4)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

// MARK: - Health Action Card (Distinct - What To Do)
struct HealthActionCard: View {
    let suggestion: String

    // Amber color for actions
    private let amberColor = Color(red: 1.0, green: 0.62, blue: 0.04) // #FF9F0A

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(amberColor)
                Text("RECOMMENDED ACTION")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(amberColor)
                    .tracking(0.5)
            }

            Text(suggestion)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .lineSpacing(4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(amberColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(amberColor.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - Vitals Section (Heart metrics only - non-redundant)
struct VitalsSection: View {
    let breakdown: HealthBreakdown

    private var hasHeartData: Bool {
        guard let h = breakdown.heartHealth else { return false }
        return h.restingHeartRateAvg != nil || h.hrvAvg != nil
    }

    private var vitalMetrics: [(value: String, unit: String, label: String, icon: String, color: Color)] {
        var result: [(value: String, unit: String, label: String, icon: String, color: Color)] = []
        if let heartHealth = breakdown.heartHealth {
            if let hr = heartHealth.restingHeartRateAvg {
                result.append((String(format: "%.0f", hr), "bpm", "Resting HR", "heart.fill", .red))
            }
            if let hrv = heartHealth.hrvAvg {
                result.append((String(format: "%.0f", hrv), "ms", "HRV", "waveform.path.ecg", .pink))
            }
        }
        return result
    }

    var body: some View {
        if hasHeartData {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 6) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    Text("VITALS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .tracking(0.5)
                }

                HStack(spacing: 0) {
                    ForEach(Array(vitalMetrics.enumerated()), id: \.offset) { index, metric in
                        VitalMetricCell(
                            value: metric.value,
                            unit: metric.unit,
                            label: metric.label,
                            icon: metric.icon,
                            color: metric.color
                        )
                        if index < vitalMetrics.count - 1 {
                            Divider()
                                .frame(height: 40)
                                .background(DesignSystem.Colors.tertiaryText.opacity(0.3))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignSystem.Colors.cardBackground)
            )
        }
    }
}

// MARK: - Vital Metric Cell
struct VitalMetricCell: View {
    let value: String
    let unit: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    Text(unit)
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Vital Card (kept for compatibility)
struct VitalCard: View {
    let value: String
    let unit: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(width: 70)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Secondary Insights (shown after first pattern)
struct SecondaryInsightsSection: View {
    let insights: [InsightItem]

    var body: some View {
        // Skip first insight (shown as hero), show remaining
        if insights.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(insights.dropFirst()) { insight in
                    SecondaryInsightRow(insight: insight)
                }
            }
        }
    }
}

// MARK: - Secondary Insight Row
struct SecondaryInsightRow: View {
    let insight: InsightItem

    private var categoryColor: Color {
        switch insight.type.lowercased() {
        case "movement": return .blue
        case "sleep": return .indigo
        case "stress": return .orange
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(categoryColor)
                .frame(width: 6, height: 6)

            Text(insight.title)
                .font(.system(size: 14))
                .foregroundColor(DesignSystem.Colors.secondaryText)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Health Trends Section (Compact)
struct HealthTrendsSection: View {
    let trends: [TrendAnalysis]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                Text("TRENDS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .tracking(0.5)
            }

            // Grid of trends
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(trends) { trend in
                    TrendCell(trend: trend)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

// MARK: - Trend Cell (Full width item)
struct TrendCell: View {
    let trend: TrendAnalysis

    private var trendColor: Color {
        switch trend.trend.lowercased() {
        case "improving": return .green
        case "declining": return .red
        default: return DesignSystem.Colors.secondaryText
        }
    }

    private var trendIcon: String {
        switch trend.trend.lowercased() {
        case "improving": return "arrow.up.right"
        case "declining": return "arrow.down.right"
        default: return "minus"
        }
    }

    private var shortName: String {
        let name = trend.metric.lowercased()
        if name.contains("step") { return "Steps" }
        if name.contains("sleep") { return "Sleep" }
        if name.contains("active") { return "Active" }
        if name.contains("heart") { return "HR" }
        if name.contains("hrv") { return "HRV" }
        return trend.metric.prefix(8).capitalized
    }

    var body: some View {
        HStack {
            Text(shortName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: trendIcon)
                    .font(.system(size: 10, weight: .bold))
                Text(String(format: "%.0f%%", abs(trend.changePercentage)))
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(trendColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(trendColor.opacity(0.1))
        )
    }
}

// MARK: - Trend Chip (Compact - kept for compatibility)
struct TrendChip: View {
    let trend: TrendAnalysis

    private var trendColor: Color {
        switch trend.trend.lowercased() {
        case "improving": return .green
        case "declining": return .red
        default: return .gray
        }
    }

    private var trendIcon: String {
        switch trend.trend.lowercased() {
        case "improving": return "arrow.up.right"
        case "declining": return "arrow.down.right"
        default: return "minus"
        }
    }

    private var shortName: String {
        let name = trend.metric.lowercased()
        if name.contains("step") { return "Steps" }
        if name.contains("sleep") { return "Sleep" }
        if name.contains("active") { return "Active" }
        if name.contains("heart") { return "HR" }
        if name.contains("hrv") { return "HRV" }
        return trend.metric.prefix(6).capitalized
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(shortName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DesignSystem.Colors.primaryText)

            HStack(spacing: 2) {
                Image(systemName: trendIcon)
                    .font(.system(size: 9, weight: .bold))
                Text(String(format: "%.0f%%", abs(trend.changePercentage)))
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(trendColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Comprehensive Health Breakdown
struct ComprehensiveHealthBreakdown: View {
    let breakdown: HealthBreakdown

    private var hasHeartHealthData: Bool {
        guard let h = breakdown.heartHealth else { return false }
        return h.restingHeartRateAvg != nil || h.hrvAvg != nil ||
               (h.bloodPressureSystolicAvg != nil && h.bloodPressureDiastolicAvg != nil)
    }

    private var hasActivityData: Bool {
        guard let a = breakdown.activity else { return false }
        return a.stepsAvg != nil || a.activeMinutesAvg != nil || a.walkingDistanceAvg != nil
    }

    private var hasSleepData: Bool {
        guard let s = breakdown.sleep else { return false }
        return s.sleepMinutesAvg != nil || s.sleepQualityScoreAvg != nil
    }

    private var hasAnyData: Bool {
        hasHeartHealthData || hasActivityData || hasSleepData
    }

    var body: some View {
        if hasAnyData {
            VStack(alignment: .leading, spacing: 10) {
                Text("Averages")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .textCase(.uppercase)

                // Horizontal scrollable stat cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        if hasHeartHealthData, let heartHealth = breakdown.heartHealth {
                            if let hr = heartHealth.restingHeartRateAvg {
                                HealthBreakdownStatCard(icon: "heart.fill", value: String(format: "%.0f", hr), label: "bpm", color: .red)
                            }
                            if let hrv = heartHealth.hrvAvg {
                                HealthBreakdownStatCard(icon: "waveform.path.ecg", value: String(format: "%.0f", hrv), label: "ms", color: .pink)
                            }
                            if let systolic = heartHealth.bloodPressureSystolicAvg,
                               let diastolic = heartHealth.bloodPressureDiastolicAvg {
                                HealthBreakdownStatCard(icon: "gauge.medium", value: String(format: "%.0f/%.0f", systolic, diastolic), label: "BP", color: .purple)
                            }
                        }

                        if hasSleepData, let sleep = breakdown.sleep {
                            if let sleepMin = sleep.sleepMinutesAvg {
                                HealthBreakdownStatCard(icon: "moon.fill", value: String(format: "%.1f", sleepMin / 60), label: "hrs", color: .indigo)
                            }
                            if let quality = sleep.sleepQualityScoreAvg {
                                HealthBreakdownStatCard(icon: "star.fill", value: String(format: "%.0f%%", quality), label: "quality", color: .yellow)
                            }
                        }

                        if hasActivityData, let activity = breakdown.activity {
                            if let steps = activity.stepsAvg {
                                HealthBreakdownStatCard(icon: "figure.walk", value: formatSteps(Int(steps)), label: "steps", color: .blue)
                            }
                            if let active = activity.activeMinutesAvg {
                                HealthBreakdownStatCard(icon: "flame.fill", value: String(format: "%.0f", active), label: "min", color: .orange)
                            }
                        }
                    }
                }
            }
        }
    }

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000.0)
        }
        return "\(steps)"
    }
}

// MARK: - Health Breakdown Stat Card
struct HealthBreakdownStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .frame(width: 70)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Weekly Health Charts Section
struct WeeklyHealthChartsSection: View {
    let metrics: [DailyHealthMetrics]
    @State private var selectedMetric: MetricType = .steps

    private var availableMetrics: [MetricType] {
        // Only show metrics that have at least one data point
        MetricType.allCases.filter { metricType in
            metrics.contains { entry in
                metricType.value(from: entry) != nil
            }
        }
    }

    /// Check if there's any health chart data to display
    private var hasAnyData: Bool {
        !metrics.isEmpty && !availableMetrics.isEmpty
    }
    
    private var chartPoints: [ChartPoint] {
        let activeMetric = effectiveMetric
        return metrics
            .compactMap { entry -> ChartPoint? in
                guard
                    let date = MetricType.dateFormatter.date(from: entry.date),
                    let value = activeMetric.value(from: entry)
                else { return nil }
                return ChartPoint(date: date, value: value)
            }
            .sorted(by: { $0.date < $1.date })
    }
    
    private var effectiveMetric: MetricType {
        let available = availableMetrics
        if available.contains(selectedMetric) {
            return selectedMetric
        } else if let first = available.first {
            return first
        } else {
            return .steps // Fallback
        }
    }
    
    var body: some View {
        // Only show the section if there's any chart data available
        if hasAnyData {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Trends")
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        Text(effectiveMetric.subtitle)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    Spacer()

                    if availableMetrics.count > 1 {
                        Picker("Metric", selection: $selectedMetric) {
                            ForEach(availableMetrics) { metric in
                                Text(metric.displayName).tag(metric)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                if chartPoints.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title3)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                        Text("Not enough data for this metric yet.")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
                } else {
                Chart {
                    ForEach(chartPoints) { point in
                        AreaMark(
                            x: .value("Day", point.date),
                            y: .value(effectiveMetric.displayName, point.value)
                        )
                        .foregroundStyle(effectiveMetric.color.opacity(0.15))
                        
                        LineMark(
                            x: .value("Day", point.date),
                            y: .value(effectiveMetric.displayName, point.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(effectiveMetric.color)
                        
                        PointMark(
                            x: .value("Day", point.date),
                            y: .value(effectiveMetric.displayName, point.value)
                        )
                        .foregroundStyle(effectiveMetric.color)
                        .annotation(position: .top) {
                            Text(effectiveMetric.formattedValue(point.value))
                                .font(.caption2)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel(MetricType.axisFormatter.string(from: date))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 240)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                )
                
                MetricSummaryView(metric: effectiveMetric, points: chartPoints)
            }
            }
            .onAppear {
                // Auto-select first available metric if current selection has no data
                let available = availableMetrics
                if !available.contains(selectedMetric) {
                    if let first = available.first {
                        selectedMetric = first
                    }
                }
            }
            .onChange(of: metrics) { _, _ in
                // Update selection when metrics change
                let available = availableMetrics
                if !available.contains(selectedMetric), let first = available.first {
                    selectedMetric = first
                }
            }
        }
    }

    // MARK: - Nested Types
    struct ChartPoint: Identifiable {
        let date: Date
        let value: Double
        var id: Date { date }
    }
    
    enum MetricType: String, CaseIterable, Identifiable {
        case steps
        case activeMinutes
        case sleepMinutes
        case activeEnergy
        case restingHeartRate
        case hrv
        
        var id: String { rawValue }
        
        static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            return formatter
        }()
        
        static let axisFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            return formatter
        }()
        
        var displayName: String {
            switch self {
            case .steps: return "Steps"
            case .activeMinutes: return "Active Minutes"
            case .sleepMinutes: return "Sleep"
            case .activeEnergy: return "Active Energy"
            case .restingHeartRate: return "Resting HR"
            case .hrv: return "HRV"
            }
        }
        
        var subtitle: String {
            switch self {
            case .steps:
                return "Track how many steps you took each day."
            case .activeMinutes:
                return "Minutes of exercise recorded each day."
            case .sleepMinutes:
                return "Total sleep duration (minutes)."
            case .activeEnergy:
                return "Active energy burned (kcal)."
            case .restingHeartRate:
                return "Average resting heart rate."
            case .hrv:
                return "Heart rate variability (ms)."
            }
        }
        
        var color: Color {
            switch self {
            case .steps: return .blue
            case .activeMinutes: return .orange
            case .sleepMinutes: return .indigo
            case .activeEnergy: return .red
            case .restingHeartRate: return .pink
            case .hrv: return .green
            }
        }
        
        var unitSuffix: String {
            switch self {
            case .steps: return ""
            case .activeMinutes, .sleepMinutes: return "m"
            case .activeEnergy: return "kcal"
            case .restingHeartRate: return "bpm"
            case .hrv: return "ms"
            }
        }
        
        func value(from metric: DailyHealthMetrics) -> Double? {
            switch self {
            case .steps:
                return metric.steps.map { Double($0) }
            case .activeMinutes:
                return metric.activeMinutes.map { Double($0) }
            case .sleepMinutes:
                return metric.sleepMinutes.map { Double($0) }
            case .activeEnergy:
                return metric.activeEnergyBurned
            case .restingHeartRate:
                return metric.restingHeartRate
            case .hrv:
                return metric.hrv
            }
        }
        
        func formattedValue(_ value: Double) -> String {
            switch self {
            case .steps:
                return Int(value).formatted()
            case .activeMinutes, .sleepMinutes:
                return "\(Int(value).formatted())\(unitSuffix)"
            case .activeEnergy:
                return "\(Int(value.rounded()).formatted()) \(unitSuffix)"
            case .restingHeartRate, .hrv:
                return "\(Int(value.rounded()).formatted()) \(unitSuffix)"
            }
        }
    }
    
    struct MetricSummaryView: View {
        let metric: MetricType
        let points: [ChartPoint]
        
        private var latestValue: Double? { points.last?.value }
        private var delta: Double? {
            guard points.count >= 2, let latest = latestValue else { return nil }
            return latest - points[points.count - 2].value
        }
        
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Latest")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    Text(latestValue.map { metric.formattedValue($0) } ?? "--")
                        .font(DesignSystem.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Change vs prev. day")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    Text(deltaText)
                        .font(DesignSystem.Typography.bodyBold)
                        .foregroundColor(deltaColor)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
        
        private var deltaText: String {
            guard let delta else { return "No change" }
            let sign = delta >= 0 ? "+" : ""
            return "\(sign)\(metric.formattedValue(delta))"
        }
        
        private var deltaColor: Color {
            guard let delta else { return DesignSystem.Colors.secondaryText }
            if delta > 0 {
                return .green
            } else if delta < 0 {
                return .red
            } else {
                return DesignSystem.Colors.secondaryText
            }
        }
    }
}

// MARK: - Health Insights Error View
struct HealthInsightsErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Unable to load insights")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            Text(message)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
            
            Button(action: onRetry) {
                Text("Try Again")
                    .font(DesignSystem.Typography.bodyBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.primary)
                    )
            }
        }
        .padding(DesignSystem.Spacing.xl)
    }
}

// MARK: - Health Insights Permission Required View
struct HealthInsightsPermissionRequiredView: View {
    let onPermissionGranted: (() -> Void)?
    
    init(onPermissionGranted: (() -> Void)? = nil) {
        self.onPermissionGranted = onPermissionGranted
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "lock.heart.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            Text("Health Data Access Required")
                .font(DesignSystem.Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            Text("To view your health insights, Clara needs access to your Health data.")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Enable permissions:")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                VStack(alignment: .leading, spacing: 8) {
                    InstructionStep(number: "1", text: "Open iOS Settings")
                    InstructionStep(number: "2", text: "Go to Health → Data Access & Devices")
                    InstructionStep(number: "3", text: "Select 'Clara'")
                    InstructionStep(number: "4", text: "Turn ON all health data types")
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            
            VStack(spacing: DesignSystem.Spacing.md) {
                Button(action: {
                    HealthAppHelper.openHealthAppSettings()
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Open Settings")
                    }
                    .font(DesignSystem.Typography.bodyBold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.primary)
                    )
                }
                
                Button(action: {
                    // Manual refresh after user enables permissions
                    Task {
                        await HealthMetricsService.shared.checkAuthorizationStatus()
                        
                        // If now authorized, trigger sync and load insights
                        if HealthMetricsService.shared.isAuthorized {
                            await HealthSyncService.shared.syncRecentDays()
                            // Call the callback if provided
                            await MainActor.run {
                                onPermissionGranted?()
                            }
                        } else {
                            print("⚠️ Permissions still denied. Make sure all 8 types are enabled in Settings.")
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Check Permissions")
                    }
                    .font(DesignSystem.Typography.bodyBold)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(
                        Capsule()
                            .fill(Color.white)
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            
            Text("After enabling all 8 health data types in Settings, tap 'Check Permissions' above")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.xs)
        }
        .padding(DesignSystem.Spacing.xl)
    }
}

// MARK: - Health Insights Empty State
struct HealthInsightsEmptyState: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 64))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
            
            Text("No health data yet")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            Text("Start collecting health data to see personalized insights")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.xl)
    }
}

// MARK: - ViewModel
@MainActor
class HealthInsightsDetailViewModel: ObservableObject {
    @Published var insights: HealthInsightsResponse?
    @Published var isLoading = false
    @Published var isRefreshing = false // Separate flag for background refresh
    @Published var errorMessage: String?
    @Published var chartMetrics: [DailyHealthMetrics] = []
    
    private let apiService = APIService()
    private let cacheService = CacheService.shared
    private let cacheKey = "health_insights"
    
    /// Invalidate cache when goals are updated
    func invalidateCache() async {
        // Clear insights cache to force fresh generation with updated goals
        insights = nil
        print("🗑️ HealthInsightsViewModel: Invalidated cache - will reload with fresh data")
    }
    
    private static let chartDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    /// Load insights with caching: instant from cache, then refresh in background
    func loadInsights(startDate: Date, endDate: Date, forceRefresh: Bool = false) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let startDateStr = formatter.string(from: startDate)
        let endDateStr = formatter.string(from: endDate)
        let cacheKeyWithRange = "\(cacheKey)_\(startDateStr)_\(endDateStr)"
        
        print("📊 HealthInsightsViewModel: Loading insights for range: \(startDateStr) to \(endDateStr), forceRefresh: \(forceRefresh)")
        
        // Step 1: Try to load from cache instantly FIRST (unless forcing refresh)
        // This ensures UI shows data immediately
        if !forceRefresh {
            if let cached = await cacheService.loadJSON(HealthInsightsResponse.self, filename: cacheKeyWithRange) {
                print("✅ HealthInsightsViewModel: Loaded from cache instantly - NOT refreshing")
                insights = cached
                // Refresh chart with cached data
                let days = max(1, (Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1)
                await refreshLocalChart(rangeDays: days)
                
                // Don't refresh if we have valid cache - just show it
                isLoading = false
                isRefreshing = false
                print("✅ HealthInsightsViewModel: Using cached data, skipping API call")
                return // Exit early - cache is valid, no need to refresh
            } else {
                print("❌ HealthInsightsViewModel: No cache found for \(cacheKeyWithRange)")
            }
        }
        
        // No cache or force refresh - show loading
        if insights == nil {
            // No cached data and no existing insights - show loading spinner
            isLoading = true
            isRefreshing = false
        } else if forceRefresh {
            // Force refresh - show refreshing indicator but keep existing content
            isRefreshing = true
            isLoading = false
        }
        
        errorMessage = nil
        
        // Step 2: Refresh from backend (only if no cache or force refresh)
        do {
            let response = try await apiService.fetchHealthInsights(startDate: startDate, endDate: endDate)
            insights = response
            
            // Cache the response for next time - IMPORTANT: Save with same key used for loading
            print("💾 HealthInsightsViewModel: Saving to cache with key: \(cacheKeyWithRange)")
            await cacheService.saveJSON(response, filename: cacheKeyWithRange, expiration: 60 * 60) // 1 hour cache
            print("💾 HealthInsightsViewModel: Cache saved successfully")
            
            print("📊 HealthInsightsViewModel: Received fresh insights from backend:")
            print("   - Response range: \(response.startDate) to \(response.endDate)")
            if let days = response.days {
                print("   - Backend days field: \(days)")
            }
            print("   - Per-day metrics count: \(response.perDayMetrics.count)")
            
            // Always refresh chart with the correct range after loading insights
            let days = max(1, (Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1)
            await refreshLocalChart(rangeDays: days)
            
            print("📊 HealthInsightsViewModel: After refresh, chart metrics count: \(chartMetrics.count)")
            if chartMetrics.count != response.perDayMetrics.count {
                print("⚠️ HealthInsightsViewModel: Chart metrics count (\(chartMetrics.count)) differs from backend count (\(response.perDayMetrics.count))")
            }
            
            isLoading = false
            isRefreshing = false
        } catch {
            print("❌ HealthInsightsViewModel: Failed to load insights: \(error.localizedDescription)")
            // Only show error if we don't have cached data
            if insights == nil {
                errorMessage = error.localizedDescription
            }
            isLoading = false
            isRefreshing = false
        }
    }
    
    func refreshLocalChart(rangeDays: Int) async {
        let history = await cacheService.loadHealthMetricsHistory() ?? []
        var combined = convertPerDayMetrics(insights?.perDayMetrics ?? [])
        
        if !history.isEmpty {
            var map = Dictionary(uniqueKeysWithValues: combined.map { ($0.date, $0) })
            for entry in history {
                map[entry.date] = entry
            }
            combined = map.values.sorted { $0.date < $1.date }
        }
        
        chartMetrics = filterMetrics(combined, rangeDays: rangeDays)
    }
    
    private func filterMetrics(_ metrics: [DailyHealthMetrics], rangeDays: Int) -> [DailyHealthMetrics] {
        guard !metrics.isEmpty else { return [] }
        let calendar = Calendar.current
        // CRITICAL FIX: Always use "today" as the anchor point, not the latest date in data
        let today = calendar.startOfDay(for: Date())
        let cutoff = calendar.date(byAdding: .day, value: -(max(rangeDays, 1) - 1), to: today) ?? today
        
        let datedEntries = metrics.compactMap { entry -> (Date, DailyHealthMetrics)? in
            guard let date = Self.chartDateFormatter.date(from: entry.date) else { return nil }
            let entryDate = calendar.startOfDay(for: date)
            // Only include entries within the range (from cutoff to today, inclusive)
            guard entryDate >= cutoff && entryDate <= today else { return nil }
            return (entryDate, entry)
        }
        
        return datedEntries
            .sorted { $0.0 < $1.0 }
            .map { $0.1 }
    }
    
    private func convertPerDayMetrics(_ perDay: [PerDayMetrics]) -> [DailyHealthMetrics] {
        guard !perDay.isEmpty else { return [] }
        return perDay.map { entry in
            DailyHealthMetrics(
                date: entry.date,
                steps: entry.steps,
                activeMinutes: entry.activeMinutes,
                standMinutes: nil,
                workoutsCount: entry.workoutsCount,
                restingHeartRate: entry.restingHeartRate,
                activeHeartRate: entry.activeHeartRate,
                maxHeartRate: entry.maxHeartRate,
                minHeartRate: entry.minHeartRate,
                walkingHeartRateAvg: entry.walkingHeartRateAvg,
                hrv: entry.hrv,
                bloodPressureSystolic: entry.bloodPressureSystolic,
                bloodPressureDiastolic: entry.bloodPressureDiastolic,
                respiratoryRate: entry.respiratoryRate,
                bloodOxygenSaturation: entry.oxygenSaturation,
                activeEnergyBurned: entry.activeEnergyBurned,
                basalEnergyBurned: entry.basalEnergyBurned,
                restingEnergyBurned: entry.restingEnergyBurned,
                walkingDistanceMeters: entry.walkingDistance,
                runningDistanceMeters: entry.runningDistance,
                cyclingDistanceMeters: entry.cyclingDistance,
                swimmingDistanceMeters: entry.swimmingDistance,
                flightsClimbed: entry.flightsClimbed,
                sleepMinutes: entry.sleepMinutes,
                sleepQualityScore: nil,
                caloriesConsumed: entry.caloriesConsumed,
                proteinGrams: entry.protein,
                carbsGrams: entry.carbohydrates,
                fatGrams: entry.fat,
                fiberGrams: entry.fiber,
                waterIntakeLiters: entry.water,
                caffeineMg: entry.caffeine,
                bodyWeight: entry.bodyWeight,
                bodyFatPercentage: entry.bodyFatPercentage,
                leanBodyMass: entry.leanBodyMass,
                bmi: entry.bodyMassIndex,
                bloodGlucose: nil,
                vo2Max: entry.vo2Max,
                mindfulMinutes: entry.mindfulnessMinutes,
                menstrualFlow: entry.menstrualFlow,
                isMenstrualPeriod: nil
            )
        }
    }
}

// MARK: - Instruction Step
struct InstructionStep: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(DesignSystem.Colors.primary)
                )

            Text(text)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
    }
}
