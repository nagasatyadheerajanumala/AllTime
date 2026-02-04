import SwiftUI

/// Combined Insights View with Weekly Summary + Monthly Insights + Health Insights
/// This is the main view for the Insights/Health tab
struct CombinedInsightsView: View {
    @State private var selectedSection: InsightsSection = .weekly
    @Environment(\.dismiss) private var dismiss

    enum InsightsSection: String, CaseIterable {
        case weekly = "Weekly"
        case monthly = "Monthly"
        case health = "Health"

        var icon: String {
            switch self {
            case .weekly: return "calendar.badge.clock"
            case .monthly: return "calendar.circle"
            case .health: return "heart.fill"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Section Picker
                sectionPicker

                // Content
                Group {
                    switch selectedSection {
                    case .weekly:
                        WeeklyInsightsView()
                    case .monthly:
                        LifeInsightsView()
                    case .health:
                        HealthInsightsTabContent()
                    }
                }
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var sectionPicker: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(InsightsSection.allCases, id: \.self) { section in
                sectionButton(section)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.screenMargin)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.background)
    }

    private func sectionButton(_ section: InsightsSection) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSection = section
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: section.icon)
                    .font(.caption.weight(.semibold))
                Text(section.rawValue)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(selectedSection == section ? .white : DesignSystem.Colors.secondaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(selectedSection == section ? DesignSystem.Colors.primary : DesignSystem.Colors.cardBackground)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Health Insights Content for the Combined Insights Tab
struct HealthInsightsTabContent: View {
    @StateObject private var viewModel = HealthInsightsDetailViewModel()
    @State private var selectedRange: DateRange = .last7Days
    @ObservedObject private var healthMetricsService = HealthMetricsService.shared
    @ObservedObject private var healthSyncService = HealthSyncService.shared

    enum DateRange: String, CaseIterable {
        case last7Days = "7 Days"
        case last14Days = "14 Days"
        case last30Days = "30 Days"

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
                        await viewModel.loadInsights(startDate: newValue.startDate, endDate: Date(), forceRefresh: false)
                    }
                }

                // Check HealthKit authorization status
                if !healthMetricsService.isAuthorized {
                    HealthPermissionPromptView()
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.top, 30)
                } else if viewModel.isLoading && viewModel.insights == nil {
                    ProgressView("Loading insights...")
                        .padding(.top, 60)
                } else if let error = viewModel.errorMessage {
                    healthErrorView(error)
                } else if let insights = viewModel.insights {
                    VStack(spacing: 16) {
                        // 0. HEALTH GOAL STREAKS - Gamification at the top
                        if let streaks = viewModel.streaks {
                            HealthStreaksSection(
                                streaks: streaks,
                                isLoading: viewModel.isLoadingStreaks
                            )
                        } else if viewModel.isLoadingStreaks {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading streaks...")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }

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
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                }

                Spacer(minLength: DesignSystem.Spacing.xl)
            }
            .padding(.bottom, 100) // Space for tab bar
        }
        .background(DesignSystem.Colors.background)
        .refreshable {
            await viewModel.loadInsights(startDate: selectedRange.startDate, endDate: Date(), forceRefresh: true)
            await viewModel.loadStreaks(forceRefresh: true)
        }
        .task {
            print("🔥 HealthInsightsTabContent: .task started, isAuthorized=\(healthMetricsService.isAuthorized)")
            if healthMetricsService.isAuthorized {
                await viewModel.loadInsights(startDate: selectedRange.startDate, endDate: Date(), forceRefresh: false)
                print("🔥 HealthInsightsTabContent: loadInsights completed, now calling loadStreaks")
                await viewModel.loadStreaks(forceRefresh: false)
                print("🔥 HealthInsightsTabContent: loadStreaks completed")
            }
        }
    }

    private func healthErrorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(DesignSystem.Colors.secondaryText)
            Text("Unable to load health insights")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.primaryText)
            Text(message)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task {
                    await viewModel.loadInsights(startDate: selectedRange.startDate, endDate: Date(), forceRefresh: true)
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

/// Simple health permission prompt
struct HealthPermissionPromptView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.circle")
                .font(.system(size: 50))
                .foregroundColor(Color(hex: "EC4899"))

            Text("Health Data Required")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text("Enable Health permissions to see personalized health insights and correlations with your schedule.")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)

            Button(action: {
                HealthKitManager.shared.safeRequestIfNeeded()
            }) {
                Text("Enable Health Access")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .fill(DesignSystem.Colors.primary)
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

// MARK: - Preview

#Preview {
    CombinedInsightsView()
}
