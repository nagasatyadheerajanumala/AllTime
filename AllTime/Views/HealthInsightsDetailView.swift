import SwiftUI
import Combine
import Charts

/// Comprehensive Health Insights view with backend AI analysis
struct HealthInsightsDetailView: View {
    @StateObject private var viewModel = HealthInsightsDetailViewModel()
    @State private var selectedRange: DateRange = .last7Days
    @State private var showingHealthGoals = false
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
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
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
                        // AI Narrative
                        AIWeeklyOverviewCard(narrative: insights.aiNarrative)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                        
                        // Summary Stats
                        HealthSummaryStatsGrid(stats: insights.summaryStats)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                        
                        // Insights Alerts
                        if !insights.insights.isEmpty {
                            HealthInsightsAlertsGrid(insights: insights.insights)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                        }
                        
                        // Trend Analysis
                        if let trends = insights.trendAnalysis, !trends.isEmpty {
                            HealthTrendsSection(trends: trends)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                        }
                        
                        // Health Breakdown
                        if let breakdown = insights.healthBreakdown {
                            ComprehensiveHealthBreakdown(breakdown: breakdown)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                        }
                        
                        // Daily Metrics Chart
                        WeeklyHealthChartsSection(metrics: viewModel.chartMetrics)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.bottom, 100)
                    } else {
                        HealthInsightsEmptyState()
                    }
                }
            }
            .navigationTitle("Health Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingHealthGoals = true
                    }) {
                        Image(systemName: "target")
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                }
            }
            .sheet(isPresented: $showingHealthGoals) {
                HealthGoalsView()
            }
            .refreshable {
                await viewModel.loadInsights(startDate: selectedRange.startDate, endDate: Date())
                await viewModel.refreshLocalChart(rangeDays: selectedRange.days)
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
            .refreshable {
                // User explicitly pulled to refresh - force refresh
                if healthMetricsService.isAuthorized {
                    await viewModel.loadInsights(startDate: selectedRange.startDate, endDate: Date(), forceRefresh: true)
                    await viewModel.refreshLocalChart(rangeDays: selectedRange.days)
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
}

// MARK: - AI Narrative Card
struct AIWeeklyOverviewCard: View {
    let narrative: AINarrative
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text("AI Analysis")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            
            Text(narrative.weeklyOverview)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.secondaryText)
            
            if !narrative.keyTakeaways.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Key Takeaways")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    
                    ForEach(narrative.keyTakeaways, id: \.self) { takeaway in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.top, 4)
                            
                            Text(takeaway)
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }
                }
                .padding(.top, DesignSystem.Spacing.sm)
            }
            
            if !narrative.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Suggestions")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    
                    ForEach(narrative.suggestions, id: \.self) { suggestion in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "lightbulb.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.top, 4)
                            
                            Text(suggestion)
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }
                }
                .padding(.top, DesignSystem.Spacing.sm)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.primary.opacity(0.1),
                            DesignSystem.Colors.accent.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }
}

// MARK: - Health Summary Stats Grid
struct HealthSummaryStatsGrid: View {
    let stats: SummaryStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Overview")
                .font(DesignSystem.Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.md) {
                if let steps = stats.avgSteps, steps > 0 {
                    HealthMetricCard(icon: "figure.walk", title: "Avg Steps", value: Int(steps).formatted(), color: .blue)
                }

                if let sleep = stats.avgSleepMinutes, sleep > 0 {
                    let hours = Int(sleep) / 60
                    let minutes = Int(sleep) % 60
                    HealthMetricCard(icon: "moon.fill", title: "Avg Sleep", value: "\(hours)h \(minutes)m", color: .indigo)
                }

                if let active = stats.avgActiveMinutes, active > 0 {
                    HealthMetricCard(icon: "flame.fill", title: "Avg Active", value: "\(Int(active).formatted()) min", color: .orange)
                }

                if let workouts = stats.totalWorkouts, workouts > 0 {
                    HealthMetricCard(icon: "figure.run", title: "Workouts", value: workouts.formatted(), color: .green)
                }
            }
        }
    }
}

// MARK: - Health Metric Card
struct HealthMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(DesignSystem.Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
    }
}

// MARK: - Health Insights Alerts Grid
struct HealthInsightsAlertsGrid: View {
    let insights: [InsightItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Insights")
                .font(DesignSystem.Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            ForEach(insights) { insight in
                HealthInsightAlertCard(insight: insight)
            }
        }
    }
}

// MARK: - Health Insight Alert Card
struct HealthInsightAlertCard: View {
    let insight: InsightItem
    
    private var severityColor: Color {
        switch insight.severity.uppercased() {
        case "HIGH":
            return .red
        case "MEDIUM":
            return .orange
        default:
            return .blue
        }
    }
    
    private var icon: String {
        switch insight.type.lowercased() {
        case "movement":
            return "figure.walk"
        case "sleep":
            return "moon.fill"
        case "stress":
            return "exclamationmark.triangle.fill"
        case "balance":
            return "leaf.fill"
        default:
            return "info.circle.fill"
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(severityColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(DesignSystem.Typography.bodyBold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Text(insight.details)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(severityColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(severityColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Health Trends Section
struct HealthTrendsSection: View {
    let trends: [TrendAnalysis]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Trends")
                .font(DesignSystem.Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            ForEach(trends) { trend in
                HealthTrendCard(trend: trend)
            }
        }
    }
}

// MARK: - Health Trend Card
struct HealthTrendCard: View {
    let trend: TrendAnalysis
    
    private var trendColor: Color {
        switch trend.trend.lowercased() {
        case "improving":
            return .green
        case "declining":
            return .red
        default:
            return .gray
        }
    }
    
    private var trendIcon: String {
        switch trend.trend.lowercased() {
        case "improving":
            return "arrow.up.right"
        case "declining":
            return "arrow.down.right"
        default:
            return "arrow.right"
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(trend.metric.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(DesignSystem.Typography.bodyBold)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Text("\(formatTrendValue(trend.previousAvg)) → \(formatTrendValue(trend.currentAvg))")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: trendIcon)
                    .font(.caption)
                Text(String(format: "%.1f%%", abs(trend.changePercentage)))
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(trendColor)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(trendColor.opacity(0.2))
            )
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
    }

    private func formatTrendValue(_ value: Double) -> String {
        // For large values (like steps), use integer with comma formatting
        // For small values (like HRV, sleep hours), use decimal
        let metric = trend.metric.lowercased()
        if metric.contains("step") || metric.contains("calorie") || metric.contains("energy") {
            return Int(value).formatted()
        } else if metric.contains("minute") || metric.contains("active") {
            return Int(value).formatted()
        } else if metric.contains("distance") {
            return Int(value).formatted()
        } else {
            // For heart rate, HRV, sleep hours, etc. - use one decimal
            return String(format: "%.1f", value)
        }
    }
}

// MARK: - Comprehensive Health Breakdown
struct ComprehensiveHealthBreakdown: View {
    let breakdown: HealthBreakdown
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Health Categories")
                .font(DesignSystem.Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            if let heartHealth = breakdown.heartHealth {
                DetailedHealthCategoryCard(
                    title: "Heart Health",
                    icon: "heart.fill",
                    color: .red,
                    items: [
                        ("Resting HR", heartHealth.restingHeartRateAvg != nil ? String(format: "%.0f BPM", heartHealth.restingHeartRateAvg!) : nil),
                        ("HRV", heartHealth.hrvAvg != nil ? String(format: "%.1f ms", heartHealth.hrvAvg!) : nil),
                        ("BP", heartHealth.bloodPressureSystolicAvg != nil && heartHealth.bloodPressureDiastolicAvg != nil ? String(format: "%.0f/%.0f", heartHealth.bloodPressureSystolicAvg!, heartHealth.bloodPressureDiastolicAvg!) : nil)
                    ]
                )
            }
            
            if let activity = breakdown.activity {
                DetailedHealthCategoryCard(
                    title: "Activity",
                    icon: "figure.walk",
                    color: .blue,
                    items: [
                        ("Steps", activity.stepsAvg != nil ? Int(activity.stepsAvg!).formatted() : nil),
                        ("Active", activity.activeMinutesAvg != nil ? String(format: "%.0f min", activity.activeMinutesAvg!) : nil),
                        ("Walking", activity.walkingDistanceAvg != nil ? String(format: "%.1f km", activity.walkingDistanceAvg! / 1000) : nil)
                    ]
                )
            }
            
            if let sleep = breakdown.sleep {
                DetailedHealthCategoryCard(
                    title: "Sleep",
                    icon: "moon.fill",
                    color: .indigo,
                    items: [
                        ("Duration", sleep.sleepMinutesAvg != nil ? String(format: "%.1f hrs", sleep.sleepMinutesAvg! / 60) : nil),
                        ("Quality", sleep.sleepQualityScoreAvg != nil ? String(format: "%.0f%%", sleep.sleepQualityScoreAvg!) : nil)
                    ]
                )
            }
        }
    }
}

// MARK: - Detailed Health Category Card
struct DetailedHealthCategoryCard: View {
    let title: String
    let icon: String
    let color: Color
    let items: [(String, String?)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Text(title)
                    .font(DesignSystem.Typography.bodyBold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            
            ForEach(items.filter { $0.1 != nil }, id: \.0) { item in
                HStack {
                    Text(item.0)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    
                    Spacer()
                    
                    Text(item.1!)
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(color.opacity(0.3), lineWidth: 1)
                )
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
            
            Text("To view your health insights, Chrona needs access to your Health data.")
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
                    InstructionStep(number: "3", text: "Select 'Chrona'")
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
