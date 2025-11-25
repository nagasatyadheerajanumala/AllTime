import SwiftUI
import Combine

/// Life Wheel View - Visualizes time distribution across contexts with health insights
struct LifeWheelView: View {
    @StateObject private var lifeWheelViewModel = LifeWheelViewModel()
    @StateObject private var healthInsightsViewModel = HealthInsightsViewModel()
    @ObservedObject private var healthMetricsService = HealthMetricsService.shared
    @State private var selectedRange: DateRange = .last7Days
    @State private var showingHealthPermission = false
    
    enum DateRange: String, CaseIterable {
        case last7Days = "7 Days"
        case last14Days = "14 Days"
        case last30Days = "30 Days"
        
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
                    // Range Selector
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
                            // Load both life wheel and health insights in parallel
                            async let lifeWheelTask = lifeWheelViewModel.loadLifeWheel(start: newValue.startDate, end: Date())
                            async let healthTask = healthInsightsViewModel.loadInsights(startDate: newValue.startDate, endDate: Date())
                            _ = try? await (lifeWheelTask, healthTask)
                        }
                    }
                    
                    // Health permission prompt if not authorized AND no health data
                    // NOTE: Authorization is requested automatically on app start (AllTimeApp.swift)
                    // This banner only shows if authorization failed or was denied
                    if !healthMetricsService.isAuthorized && !healthInsightsViewModel.hasAnyHealthData {
                        HealthPermissionCard(onRequestPermission: {
                            Task { @MainActor in
                                // Re-check authorization status (user may have enabled in Health app)
                                await healthMetricsService.checkAuthorizationStatus()
                                
                                // If still not authorized, open Health app settings
                                if !healthMetricsService.isAuthorized {
                                    HealthAppHelper.openHealthAppSettings()
                                } else {
                                    // Now authorized - reload insights
                                    await healthInsightsViewModel.loadInsights(startDate: selectedRange.startDate, endDate: Date())
                                }
                            }
                        })
                        .padding(.horizontal, DesignSystem.Spacing.md)
                    }
                    
                    if lifeWheelViewModel.isLoading || healthInsightsViewModel.isLoading {
                        ProgressView()
                            .padding(.top, 60)
                    } else if let healthInsights = healthInsightsViewModel.insights {
                        // Show health insights (prioritize health data)
                        HealthInsightsContentView(insights: healthInsights)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                    } else if let lifeWheel = lifeWheelViewModel.lifeWheel {
                        // Fallback to life wheel if no health insights
                        LifeWheelContentView(lifeWheel: lifeWheel)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                    } else if let errorMessage = healthInsightsViewModel.errorMessage ?? lifeWheelViewModel.errorMessage {
                        ErrorView(message: errorMessage) {
                            Task {
                                await healthInsightsViewModel.loadInsights(startDate: selectedRange.startDate, endDate: Date())
                                await lifeWheelViewModel.loadLifeWheel(start: selectedRange.startDate, end: Date())
                            }
                        }
                        .padding(.top, 60)
                    } else {
                        EmptyStateView()
                            .padding(.top, 60)
                    }
                }
                .padding(.bottom, 85)
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Refresh authorization status when view appears
                Task { @MainActor in
                    // Authorization is requested automatically on app start
                    // Just check HealthMetricsService status
                    await healthMetricsService.checkAuthorizationStatus()
                }
                
                if (healthInsightsViewModel.insights == nil && !healthInsightsViewModel.isLoading) ||
                   (lifeWheelViewModel.lifeWheel == nil && !lifeWheelViewModel.isLoading) {
                    Task {
                        // Load both in parallel
                        async let healthTask = healthInsightsViewModel.loadInsights(startDate: selectedRange.startDate, endDate: Date())
                        async let lifeWheelTask = lifeWheelViewModel.loadLifeWheel(start: selectedRange.startDate, end: Date())
                        _ = try? await (healthTask, lifeWheelTask)
                    }
                }
            }
            .onChange(of: healthMetricsService.isAuthorized) { oldValue, newValue in
                print("💚 LifeWheelView: Authorization changed from \(oldValue) to \(newValue)")
                if newValue {
                    // Reload insights when authorization is granted
                    Task {
                        // Wait a bit for sync to complete
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                        await healthInsightsViewModel.loadInsights(startDate: selectedRange.startDate, endDate: Date())
                    }
                }
            }
            .onChange(of: healthInsightsViewModel.hasAnyHealthData) { oldValue, newValue in
                // Hide banner when we get health data
                if newValue {
                    print("💚 LifeWheelView: Health data detected, banner should hide")
                }
            }
        }
    }
}

// MARK: - Life Wheel Content View
struct LifeWheelContentView: View {
    let lifeWheel: LifeWheelResponse
    
    private var totalMinutes: Int {
        lifeWheel.distribution.values.reduce(0) { $0 + $1.minutes }
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Summary Card
            VStack(spacing: 8) {
                Text("\(lifeWheel.totalEvents ?? 0)")
                    .font(DesignSystem.Typography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.primary)
                Text("Total Events")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.lg)
            .background(Color(.systemGroupedBackground))
            .cornerRadius(DesignSystem.CornerRadius.md)
            
            // Distribution Cards
            VStack(spacing: DesignSystem.Spacing.md) {
                ForEach(Array(lifeWheel.distribution.keys.sorted()), id: \.self) { context in
                    if let distribution = lifeWheel.distribution[context] {
                        ContextDistributionCard(
                            context: context,
                            distribution: distribution,
                            totalMinutes: totalMinutes
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Context Distribution Card
struct ContextDistributionCard: View {
    let context: String
    let distribution: ContextDistribution
    let totalMinutes: Int
    
    private var percentage: Double {
        guard totalMinutes > 0 else { return 0 }
        return Double(distribution.minutes) / Double(totalMinutes) * 100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(contextDisplayName)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Spacer()
                
                Text("\(Int(percentage))%")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(contextColor)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(contextColor)
                        .frame(width: geometry.size.width * CGFloat(percentage / 100), height: 8)
                }
            }
            .frame(height: 8)
            
            HStack {
                Label("\(distribution.minutes) min", systemImage: "clock.fill")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                
                Spacer()
                
                Label("\(distribution.count) events", systemImage: "calendar")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
    
    private var contextDisplayName: String {
        switch context.lowercased() {
        case "meeting":
            return "Meetings"
        case "deep_work", "deep work":
            return "Deep Work"
        case "social":
            return "Social"
        case "health":
            return "Health"
        default:
            return context.capitalized
        }
    }
    
    private var contextColor: Color {
        switch context.lowercased() {
        case "meeting":
            return .blue
        case "deep_work", "deep work":
            return .purple
        case "social":
            return .green
        case "health":
            return .red
        default:
            return DesignSystem.Colors.primary
        }
    }
}

// MARK: - Life Wheel View Model
@MainActor
class LifeWheelViewModel: ObservableObject {
    @Published var lifeWheel: LifeWheelResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService()
    private let cacheService = CacheService.shared
    
    func loadLifeWheel(start: Date, end: Date) async {
        // Step 1: Load from disk cache first (instant UI update)
        if let cached = await cacheService.loadCachedLifeWheel(startDate: start, endDate: end) {
            await MainActor.run {
                self.lifeWheel = cached
                self.isLoading = false
            }
        }
        
        isLoading = true
        errorMessage = nil
        
        // Step 2: Fetch from backend in background
        do {
            let fetchedLifeWheel = try await Task.detached { [apiService] in
                try await apiService.fetchLifeWheel(start: start, end: end)
            }.value
            
            // Save to disk cache
            await cacheService.cacheLifeWheel(fetchedLifeWheel, startDate: start, endDate: end)
            
            await MainActor.run {
                self.lifeWheel = fetchedLifeWheel
                self.isLoading = false
            }
        } catch {
            // On error, keep cached data if available
            await MainActor.run {
                if self.lifeWheel == nil {
                    self.errorMessage = error.localizedDescription
                }
                self.isLoading = false
                print("❌ LifeWheelViewModel: Failed to load life wheel: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Health Permission Card
struct HealthPermissionCard: View {
    let onRequestPermission: () -> Void
    @State private var hasTriedAuthorization = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Health Data")
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    
                    Text("Connect your health data to see how your calendar load affects your activity, sleep, and well-being.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if hasTriedAuthorization {
                        Text("If you denied permissions, you can enable them in Settings > Privacy & Security > Health > AllTime")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .padding(.top, 4)
                    }
                }
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    hasTriedAuthorization = true
                    onRequestPermission()
                }) {
                    Text("Enable Health Data")
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(DesignSystem.Colors.primary)
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                }
                
                if hasTriedAuthorization {
                    Button(action: {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }) {
                        Text("Open Settings")
                            .font(DesignSystem.Typography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(DesignSystem.Colors.primary.opacity(0.1))
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

// MARK: - Health Insights Content View
struct HealthInsightsContentView: View {
    let insights: HealthInsightsResponse
    @ObservedObject private var healthMetricsService = HealthMetricsService.shared
    
    // Check if we have any health data across all days
    private var hasAnyHealthData: Bool {
        insights.perDayMetrics.contains { day in
            day.steps != nil || day.sleepMinutes != nil || day.activeMinutes != nil ||
            day.workoutsCount != nil || day.restingHeartRate != nil
        }
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // REMOVED: Duplicate permission banner
            // Authorization is requested automatically on app start (AllTimeApp.swift)
            // Banner is only shown in main LifeWheelView if needed
            
            // Summary Stats Card (Health Metrics Overview)
            if !insights.perDayMetrics.isEmpty {
                SummaryStatsCard(stats: insights.summaryStats, dayCount: insights.perDayMetrics.count, hasHealthData: hasAnyHealthData)
            }
            
            // Trend Analysis Section
            if let trends = insights.trendAnalysis, !trends.isEmpty {
                TrendAnalysisSection(trends: trends)
            }
            
            // AI Narrative Section
            if !insights.aiNarrative.weeklyOverview.isEmpty {
                AINarrativeSection(narrative: insights.aiNarrative)
            }
            
            // Health Insights Section
            if !insights.insights.isEmpty {
                InsightsSection(insights: insights.insights)
            }
            
            // Structured Health Breakdown by Category
            if let breakdown = insights.healthBreakdown {
                HealthBreakdownSection(breakdown: breakdown)
            }
            
            // Per-Day Metrics List (Health Data + Calendar)
            if !insights.perDayMetrics.isEmpty {
                PerDayMetricsSection(metrics: insights.perDayMetrics)
            }
            
            // Context Breakdown (Calendar Time Distribution)
            ContextBreakdownSection(perDayMetrics: insights.perDayMetrics)
        }
    }
}

// MARK: - Summary Stats Card
struct SummaryStatsCard: View {
    let stats: SummaryStats
    let dayCount: Int
    let hasHealthData: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("\(dayCount) Days Overview")
                .font(DesignSystem.Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            // Use the passed hasHealthData parameter
            if hasHealthData {
                // Health Metrics Grid
                VStack(spacing: 16) {
                    // Row 1: Steps and Sleep
                    HStack(spacing: 12) {
                        if let avgSteps = stats.avgSteps, avgSteps > 0 {
                            HealthStatCard(
                                icon: "figure.walk",
                                value: "\(Int(avgSteps))",
                                label: "Avg Steps/Day",
                                color: .blue
                            )
                        }
                        
                        if let avgSleep = stats.avgSleepMinutes, avgSleep > 0 {
                            HealthStatCard(
                                icon: "bed.double.fill",
                                value: formatSleepHours(avgSleep),
                                label: "Avg Sleep",
                                color: .purple
                            )
                        }
                    }
                    
                    // Row 2: Active Minutes and Workouts
                    HStack(spacing: 12) {
                        if let avgActive = stats.avgActiveMinutes, avgActive > 0 {
                            HealthStatCard(
                                icon: "flame.fill",
                                value: "\(Int(avgActive))m",
                                label: "Avg Active/Day",
                                color: .orange
                            )
                        }
                        
                        if let totalWorkouts = stats.totalWorkouts, totalWorkouts > 0 {
                            HealthStatCard(
                                icon: "figure.run",
                                value: "\(totalWorkouts)",
                                label: "Total Workouts",
                                color: .green
                            )
                        }
                    }
                }
            }
            
            // Best Days (if available) - Always show calendar insights even without health data
            if stats.bestSleepDay != nil || stats.mostActiveDay != nil || stats.busiestMeetingDay != nil {
                if hasHealthData {
                    Divider()
                        .padding(.vertical, 8)
                }
                
                VStack(spacing: 8) {
                    if let bestSleep = stats.bestSleepDay {
                        BestDayRow(icon: "bed.double.fill", label: "Best Sleep Day", date: bestSleep, color: .purple)
                    }
                    
                    if let mostActive = stats.mostActiveDay {
                        BestDayRow(icon: "flame.fill", label: "Most Active Day", date: mostActive, color: .orange)
                    }
                    
                    if let busiest = stats.busiestMeetingDay {
                        BestDayRow(icon: "calendar", label: "Busiest Meeting Day", date: busiest, color: .blue)
                    }
                }
            } else if !hasHealthData {
                // Show message when no data at all
                Text("No health or calendar data available for this period")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.lg)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
    
    private func formatSleepHours(_ minutes: Double) -> String {
        let hours = Int(minutes / 60)
        let mins = Int(minutes.truncatingRemainder(dividingBy: 60))
        if mins == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(mins)m"
        }
    }
}

// MARK: - Health Stat Card
struct HealthStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(color)
                .frame(height: 30)
            
            Text(value)
                .font(DesignSystem.Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.md)
        .background(color.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }
}

// MARK: - Best Day Row
struct BestDayRow: View {
    let icon: String
    let label: String
    let date: String
    let color: Color
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    private var displayDate: String {
        if let dateObj = Self.dateFormatter.date(from: date) {
            return Self.displayFormatter.string(from: dateObj)
        }
        return date
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(label)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
            
            Spacer()
            
            Text(displayDate)
                .font(DesignSystem.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.primaryText)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
    }
}


// MARK: - AI Narrative Section
struct AINarrativeSection: View {
    let narrative: AINarrative
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
                Text("AI Insights")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            
            // Weekly Overview
            Text(narrative.weeklyOverview)
                .font(DesignSystem.Typography.body)
                .lineSpacing(6)
                .foregroundColor(DesignSystem.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            // Key Takeaways
            if !narrative.keyTakeaways.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key Takeaways")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    
                    ForEach(Array(narrative.keyTakeaways.enumerated()), id: \.offset) { _, takeaway in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(DesignSystem.Colors.primary)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(takeaway)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            
            // Suggestions
            if !narrative.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggestions")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    
                    ForEach(Array(narrative.suggestions.enumerated()), id: \.offset) { _, suggestion in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                                .padding(.top, 4)
                            Text(suggestion)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

// MARK: - Insights Section
struct InsightsSection: View {
    let insights: [InsightItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Insights")
                .font(DesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.primaryText)
                .padding(.horizontal, DesignSystem.Spacing.md)
            
            ForEach(insights) { insight in
                InsightCard(insight: insight)
            }
        }
    }
}

// MARK: - Insight Card
struct InsightCard: View {
    let insight: InsightItem
    
    private var severityColor: Color {
        switch insight.severity.uppercased() {
        case "HIGH":
            return .red
        case "MEDIUM":
            return .orange
        case "LOW":
            return .green
        default:
            return DesignSystem.Colors.primary
        }
    }
    
    private var typeIcon: String {
        switch insight.type.lowercased() {
        case "movement":
            return "figure.walk"
        case "sleep":
            return "bed.double.fill"
        case "stress":
            return "exclamationmark.triangle.fill"
        case "balance":
            return "scalemass.fill"
        default:
            return "info.circle.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: typeIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(severityColor)
                
                Text(insight.title)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Spacer()
                
                Text(insight.severity)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(severityColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(severityColor.opacity(0.15))
                    .cornerRadius(6)
            }
            
            Text(insight.details)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.md)
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
}

// MARK: - Context Breakdown Section
struct ContextBreakdownSection: View {
    let perDayMetrics: [PerDayMetrics]
    
    private var aggregatedBreakdown: [String: (minutes: Int, count: Int)] {
        var breakdown: [String: (minutes: Int, count: Int)] = [:]
        
        for day in perDayMetrics {
            for (context, minutes) in day.contextBreakdown {
                let existing = breakdown[context] ?? (0, 0)
                breakdown[context] = (existing.minutes + minutes, existing.count + (minutes > 0 ? 1 : 0))
            }
        }
        
        return breakdown
    }
    
    private var totalMinutes: Int {
        aggregatedBreakdown.values.reduce(0) { $0 + $1.minutes }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Distribution")
                .font(DesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.primaryText)
                .padding(.horizontal, DesignSystem.Spacing.md)
            
            ForEach(Array(aggregatedBreakdown.keys.sorted()), id: \.self) { context in
                if let data = aggregatedBreakdown[context], data.minutes > 0 {
                    ContextDistributionCard(
                        context: context,
                        distribution: ContextDistribution(minutes: data.minutes, count: data.count),
                        totalMinutes: totalMinutes
                    )
                }
            }
        }
    }
}

// MARK: - Per Day Metrics Section
struct PerDayMetricsSection: View {
    let metrics: [PerDayMetrics]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Breakdown")
                .font(DesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.primaryText)
                .padding(.horizontal, DesignSystem.Spacing.md)
            
            ForEach(metrics.reversed()) { day in
                PerDayMetricsCard(metrics: day)
            }
        }
    }
}

// MARK: - Per Day Metrics Card
struct PerDayMetricsCard: View {
    let metrics: PerDayMetrics
    @ObservedObject private var healthMetricsService = HealthMetricsService.shared
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    private var date: Date? {
        Self.dateFormatter.date(from: metrics.date)
    }
    
    private var displayDate: String {
        if let date = date {
            return Self.displayFormatter.string(from: date)
        }
        return metrics.date
    }
    
    private var eventLoadColor: Color {
        guard let load = metrics.eventLoadMinutes, load > 0 else { return .gray }
        if load > 480 { // > 8 hours
            return .red
        } else if load > 360 { // > 6 hours
            return .orange
        } else {
            return .green
        }
    }
    
    private var hasHealthData: Bool {
        // Check all health metrics
        metrics.steps != nil || metrics.sleepMinutes != nil || 
        metrics.activeMinutes != nil || metrics.workoutsCount != nil ||
        metrics.restingHeartRate != nil || metrics.hrv != nil ||
        metrics.walkingDistance != nil || metrics.caloriesConsumed != nil ||
        metrics.bodyWeight != nil || metrics.mindfulnessMinutes != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Date Header
            Text(displayDate)
                .font(DesignSystem.Typography.body)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            // Health Metrics Section
            if hasHealthData {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Health Metrics")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .textCase(.uppercase)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        // Basic Activity Metrics
                        if let steps = metrics.steps, steps > 0 {
                            HealthMetricBadge(
                                icon: "figure.walk",
                                value: formatNumber(steps),
                                label: "Steps",
                                color: .blue
                            )
                        }
                        
                        if let sleep = metrics.sleepMinutes, sleep > 0 {
                            HealthMetricBadge(
                                icon: "bed.double.fill",
                                value: formatSleep(sleep),
                                label: "Sleep",
                                color: .purple
                            )
                        }
                        
                        if let active = metrics.activeMinutes, active > 0 {
                            HealthMetricBadge(
                                icon: "flame.fill",
                                value: "\(active)m",
                                label: "Active",
                                color: .orange
                            )
                        }
                        
                        if let workouts = metrics.workoutsCount, workouts > 0 {
                            HealthMetricBadge(
                                icon: "figure.run",
                                value: "\(workouts)",
                                label: workouts == 1 ? "Workout" : "Workouts",
                                color: .green
                            )
                        }
                        
                        // Heart Health
                        if let restingHR = metrics.restingHeartRate, restingHR > 0 {
                            HealthMetricBadge(
                                icon: "heart.fill",
                                value: "\(Int(restingHR))",
                                label: "Resting HR",
                                color: .red
                            )
                        }
                        
                        if let hrv = metrics.hrv, hrv > 0 {
                            HealthMetricBadge(
                                icon: "waveform.path.ecg",
                                value: String(format: "%.1f", hrv),
                                label: "HRV",
                                color: .pink
                            )
                        }
                        
                        // Distance & Energy
                        if let walkingDist = metrics.walkingDistance, walkingDist > 0 {
                            HealthMetricBadge(
                                icon: "figure.walk",
                                value: formatDistance(walkingDist),
                                label: "Walked",
                                color: .cyan
                            )
                        }
                        
                        if let energy = metrics.activeEnergyBurned, energy > 0 {
                            HealthMetricBadge(
                                icon: "bolt.fill",
                                value: "\(Int(energy))",
                                label: "Calories",
                                color: .yellow
                            )
                        }
                        
                        // Nutrition
                        if let calories = metrics.caloriesConsumed, calories > 0 {
                            HealthMetricBadge(
                                icon: "fork.knife",
                                value: "\(Int(calories))",
                                label: "Calories",
                                color: .brown
                            )
                        }
                        
                        if let water = metrics.water, water > 0 {
                            HealthMetricBadge(
                                icon: "drop.fill",
                                value: formatWater(water),
                                label: "Water",
                                color: .blue
                            )
                        }
                        
                        // Body Measurements
                        if let weight = metrics.bodyWeight, weight > 0 {
                            HealthMetricBadge(
                                icon: "scalemass.fill",
                                value: String(format: "%.1f", weight),
                                label: "Weight",
                                color: .gray
                            )
                        }
                        
                        // Mindfulness
                        if let mindfulness = metrics.mindfulnessMinutes, mindfulness > 0 {
                            HealthMetricBadge(
                                icon: "leaf.fill",
                                value: "\(mindfulness)m",
                                label: "Mindful",
                                color: .mint
                            )
                        }
                    }
                }
            } else {
                // No health data available - show helpful message
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        Text("No health data available")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    
                    // Show explanation if HealthKit not authorized
                    if !healthMetricsService.isAuthorized {
                        Text("Enable Health Data permissions to see your activity, sleep, and wellness metrics.")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(DesignSystem.Colors.secondaryText.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Health data will appear here once it's synced from your device.")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(DesignSystem.Colors.secondaryText.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Calendar/Meeting Load Section - Always show if we have calendar data
            if let load = metrics.eventLoadMinutes {
                Divider()
                    .padding(.vertical, 4)
                
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(load > 0 ? eventLoadColor : .gray)
                    
                    if load > 0 {
                        Text("Meeting Load: \(formatMeetingTime(load))")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    } else {
                        Text("No meetings scheduled")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    
                    Spacer()
                    
                    if let meetingsCount = metrics.meetingsCount {
                        if meetingsCount > 0 {
                            Text("\(meetingsCount) \(meetingsCount == 1 ? "meeting" : "meetings")")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        } else {
                            Text("0 meetings")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText.opacity(0.6))
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.md)
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fk", Double(number) / 1000.0)
        }
        return "\(number)"
    }
    
    private func formatSleep(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(mins)m"
        }
    }
    
    private func formatMeetingTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours == 0 {
            return "\(mins)m"
        } else if mins == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(mins)m"
        }
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000.0)
        } else {
            return "\(Int(meters)) m"
        }
    }
    
    private func formatWater(_ liters: Double) -> String {
        if liters >= 1.0 {
            return String(format: "%.1f L", liters)
        } else {
            return "\(Int(liters * 1000)) mL"
        }
    }
}

// MARK: - Health Metric Badge
struct HealthMetricBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(DesignSystem.Typography.subheadline)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            Text(label)
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(color.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }
}



import SwiftUI

// MARK: - Trend Analysis Section
struct TrendAnalysisSection: View {
    let trends: [TrendAnalysis]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
                Text("Trend Analysis")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            
            ForEach(trends) { trend in
                TrendCard(trend: trend)
            }
        }
    }
}

// MARK: - Trend Card
struct TrendCard: View {
    let trend: TrendAnalysis
    
    private var trendColor: Color {
        switch trend.trend.lowercased() {
        case "improving":
            return .green
        case "declining":
            return .red
        case "stable":
            return .gray
        default:
            return DesignSystem.Colors.primary
        }
    }
    
    private var trendIcon: String {
        switch trend.trend.lowercased() {
        case "improving":
            return "arrow.up.right.circle.fill"
        case "declining":
            return "arrow.down.right.circle.fill"
        case "stable":
            return "minus.circle.fill"
        default:
            return "chart.line.uptrend.xyaxis"
        }
    }
    
    private var significanceColor: Color {
        switch trend.significance.lowercased() {
        case "high":
            return .red
        case "medium":
            return .orange
        case "low":
            return .gray
        default:
            return DesignSystem.Colors.secondaryText
        }
    }
    
    private var metricDisplayName: String {
        switch trend.metric.lowercased() {
        case "steps":
            return "Steps"
        case "sleep_minutes", "sleep":
            return "Sleep"
        case "active_minutes", "active":
            return "Active Minutes"
        case "resting_heart_rate", "heart_rate":
            return "Resting Heart Rate"
        case "hrv":
            return "Heart Rate Variability"
        case "active_energy_burned", "energy":
            return "Active Energy"
        default:
            return trend.metric.capitalized.replacingOccurrences(of: "_", with: " ")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: trendIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(trendColor)
                
                Text(metricDisplayName)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Spacer()
                
                Text(trend.trend.capitalized)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(trendColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(trendColor.opacity(0.15))
                    .cornerRadius(6)
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    Text(formatValue(trend.currentAvg))
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Previous")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    Text(formatValue(trend.previousAvg))
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Change")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    HStack(spacing: 4) {
                        Image(systemName: trend.trend == "improving" ? "arrow.up" : trend.trend == "declining" ? "arrow.down" : "minus")
                            .font(.system(size: 10))
                        Text(String(format: "%.1f%%", abs(trend.changePercentage)))
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(trendColor)
                }
            }
            
            if trend.significance.lowercased() != "low" {
                HStack {
                    Circle()
                        .fill(significanceColor)
                        .frame(width: 6, height: 6)
                    Text("\(trend.significance.capitalized) significance")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.md)
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
    
    private func formatValue(_ value: Double) -> String {
        // Format based on metric type
        switch trend.metric.lowercased() {
        case "steps":
            return formatNumber(Int(value))
        case "sleep_minutes", "sleep":
            return formatSleep(Int(value))
        case "active_minutes", "active":
            return "\(Int(value))m"
        case "resting_heart_rate", "heart_rate", "hrv":
            return String(format: "%.1f", value)
        case "active_energy_burned", "energy":
            return "\(Int(value))"
        default:
            return String(format: "%.1f", value)
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fk", Double(number) / 1000.0)
        }
        return "\(number)"
    }
    
    private func formatSleep(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(mins)m"
        }
    }
}

// MARK: - Health Breakdown Section
struct HealthBreakdownSection: View {
    let breakdown: HealthBreakdown
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health Breakdown")
                .font(DesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.primaryText)
                .padding(.horizontal, DesignSystem.Spacing.md)
            
            // Heart Health
            if let heartHealth = breakdown.heartHealth {
                HealthCategoryCard(
                    title: "Heart Health",
                    icon: "heart.fill",
                    color: .red,
                    metrics: [
                        ("Resting HR", heartHealth.restingHeartRateAvg, "bpm"),
                        ("Active HR", heartHealth.activeHeartRateAvg, "bpm"),
                        ("HRV", heartHealth.hrvAvg, "ms"),
                        ("SpO2", heartHealth.oxygenSaturationAvg, "%")
                    ]
                )
            }
            
            // Activity
            if let activity = breakdown.activity {
                HealthCategoryCard(
                    title: "Activity",
                    icon: "figure.walk",
                    color: .blue,
                    metrics: [
                        ("Steps", activity.stepsAvg, ""),
                        ("Active Min", activity.activeMinutesAvg, "m"),
                        ("Walking", activity.walkingDistanceAvg, "m"),
                        ("Energy", activity.activeEnergyBurnedAvg, "kcal")
                    ]
                )
            }
            
            // Sleep
            if let sleep = breakdown.sleep {
                HealthCategoryCard(
                    title: "Sleep",
                    icon: "bed.double.fill",
                    color: .purple,
                    metrics: [
                        ("Sleep", sleep.sleepMinutesAvg, "min"),
                        ("Quality", sleep.sleepQualityScoreAvg, "/100")
                    ]
                )
            }
            
            // Nutrition
            if let nutrition = breakdown.nutrition {
                HealthCategoryCard(
                    title: "Nutrition",
                    icon: "fork.knife",
                    color: .brown,
                    metrics: [
                        ("Calories", nutrition.caloriesConsumedAvg, "kcal"),
                        ("Protein", nutrition.proteinAvg, "g"),
                        ("Carbs", nutrition.carbohydratesAvg, "g"),
                        ("Water", nutrition.waterAvg, "L")
                    ]
                )
            }
            
            // Body Measurements
            if let body = breakdown.bodyMeasurements {
                HealthCategoryCard(
                    title: "Body Measurements",
                    icon: "scalemass.fill",
                    color: .gray,
                    metrics: [
                        ("Weight", body.bodyWeightAvg, "kg"),
                        ("BMI", body.bodyMassIndexAvg, ""),
                        ("Body Fat", body.bodyFatPercentageAvg, "%")
                    ]
                )
            }
            
            // Fitness
            if let fitness = breakdown.fitness {
                HealthCategoryCard(
                    title: "Fitness",
                    icon: "figure.run",
                    color: .green,
                    metrics: [
                        ("Workouts", fitness.workoutsCountTotal.map { Double($0) }, ""),
                        ("VO2 Max", fitness.vo2MaxAvg, "mL/kg/min")
                    ]
                )
            }
            
            // Mindfulness
            if let mindfulness = breakdown.mindfulness {
                HealthCategoryCard(
                    title: "Mindfulness",
                    icon: "leaf.fill",
                    color: .mint,
                    metrics: [
                        ("Minutes", mindfulness.mindfulnessMinutesAvg, "min")
                    ]
                )
            }
        }
    }
}

// MARK: - Health Category Card
struct HealthCategoryCard: View {
    let title: String
    let icon: String
    let color: Color
    let metrics: [(String, Double?, String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                    if let value = metric.1, value > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(metric.0)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(formatMetricValue(value, unit: metric.2))
                                    .font(DesignSystem.Typography.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                if !metric.2.isEmpty {
                                    Text(metric.2)
                                        .font(DesignSystem.Typography.caption2)
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DesignSystem.Spacing.sm)
                        .background(color.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.md)
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
    
    private func formatMetricValue(_ value: Double, unit: String) -> String {
        if unit == "min" || unit == "m" {
            return "\(Int(value))"
        } else if unit == "kg" || unit == "g" || unit == "L" || unit == "kcal" {
            return String(format: "%.1f", value)
        } else if unit == "%" || unit == "bpm" || unit == "ms" {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

