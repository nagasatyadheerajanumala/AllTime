import SwiftUI
import Combine

/// Comprehensive Health Insights view with backend AI analysis
struct HealthInsightsDetailView: View {
    @StateObject private var viewModel = HealthInsightsDetailViewModel()
    @State private var selectedRange: DateRange = .last7Days
    @ObservedObject private var healthMetricsService = HealthMetricsService.shared
    
    enum DateRange: String, CaseIterable {
        case last7Days = "Last 7 Days"
        case last14Days = "Last 14 Days"
        case last30Days = "Last 30 Days"
        
        var startDate: Date {
            let calendar = Calendar.current
            switch self {
            case .last7Days:
                return calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            case .last14Days:
                return calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()
            case .last30Days:
                return calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            }
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
                        Task {
                            await viewModel.loadInsights(startDate: newValue.startDate, endDate: Date())
                        }
                    }
                    
                    // Check HealthKit authorization status
                    if !healthMetricsService.isAuthorized {
                        HealthInsightsPermissionRequiredView(
                            onPermissionGranted: {
                                Task {
                                    await viewModel.loadInsights(startDate: selectedRange.startDate, endDate: Date())
                                }
                            }
                        )
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.top, 50)
                    } else if viewModel.isLoading {
                        ProgressView("Loading insights...")
                            .padding(.top, 100)
                    } else if let error = viewModel.errorMessage {
                        HealthInsightsErrorView(message: error) {
                            Task {
                                await viewModel.loadInsights(startDate: selectedRange.startDate, endDate: Date())
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
                        WeeklyHealthChartsSection(metrics: insights.perDayMetrics)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.bottom, 100)
                    } else {
                        HealthInsightsEmptyState()
                    }
                }
            }
            .navigationTitle("Health Insights")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.loadInsights(startDate: selectedRange.startDate, endDate: Date())
            }
            .onAppear {
                // Always re-check authorization when view appears (user may have enabled in Settings)
                Task {
                    await healthMetricsService.checkAuthorizationStatus()
                    
                    // Load insights if authorized and not already loading
                    if healthMetricsService.isAuthorized && viewModel.insights == nil && !viewModel.isLoading {
                        await viewModel.loadInsights(startDate: selectedRange.startDate, endDate: Date())
                    }
                }
            }
            .onChange(of: healthMetricsService.isAuthorized) { oldValue, newValue in
                // When authorization changes from false to true, automatically load insights
                if !oldValue && newValue {
                    Task {
                        // Small delay to ensure sync completes
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        await viewModel.loadInsights(startDate: selectedRange.startDate, endDate: Date())
                    }
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
                if let steps = stats.avgSteps {
                    HealthMetricCard(icon: "figure.walk", title: "Avg Steps", value: String(format: "%.0f", steps), color: .blue)
                }
                
                if let sleep = stats.avgSleepMinutes {
                    let hours = Int(sleep) / 60
                    let minutes = Int(sleep) % 60
                    HealthMetricCard(icon: "moon.fill", title: "Avg Sleep", value: "\(hours)h \(minutes)m", color: .indigo)
                }
                
                if let active = stats.avgActiveMinutes {
                    HealthMetricCard(icon: "flame.fill", title: "Avg Active", value: "\(Int(active)) min", color: .orange)
                }
                
                if let workouts = stats.totalWorkouts {
                    HealthMetricCard(icon: "figure.run", title: "Workouts", value: "\(workouts)", color: .green)
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
                
                Text(String(format: "%.1f → %.1f", trend.previousAvg, trend.currentAvg))
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
                        ("Steps", activity.stepsAvg != nil ? String(format: "%.0f", activity.stepsAvg!) : nil),
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
    let metrics: [PerDayMetrics]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Daily Trends")
                .font(DesignSystem.Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            // Simple bar chart placeholder
            Text("Chart showing daily steps, sleep, and activity trends")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.tertiaryText)
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                )
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
            
            Text("To view your health insights, AllTime needs access to your Health data.")
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
                    InstructionStep(number: "3", text: "Select 'AllTime'")
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
    @Published var errorMessage: String?
    
    private let apiService = APIService()
    
    func loadInsights(startDate: Date, endDate: Date) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.fetchHealthInsights(startDate: startDate, endDate: endDate)
            insights = response
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
