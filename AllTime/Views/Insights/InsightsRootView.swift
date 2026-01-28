import SwiftUI

/// InsightsRootView - Combined Health + Weekly Insights Tab
/// Moved from: Health tab (HealthInsightsDetailView) + Weekly Insights from TodayView
/// This is the main Insights tab replacing the old Health tab
/// Optimized with task cancellation and proper ViewModel lifecycle management
struct InsightsRootView: View {
    @State private var selectedSection: InsightsSection = .daily
    @State private var previousSection: InsightsSection = .daily
    @StateObject private var weeklyNarrativeViewModel = WeeklyNarrativeViewModel()
    @ObservedObject private var healthMetricsService = HealthMetricsService.shared
    @State private var loadTask: Task<Void, Never>?
    @State private var showingHealthGoals = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Track which views have been loaded to preserve their state
    @State private var dailyViewLoaded = false
    @State private var weeklyViewLoaded = false
    @State private var forecastViewLoaded = false
    @State private var monthlyViewLoaded = false
    @State private var healthViewLoaded = false

    // Direction of tab switch (for animation)
    private var isForwardTransition: Bool {
        let sections = InsightsSection.allCases
        guard let currentIndex = sections.firstIndex(of: selectedSection),
              let previousIndex = sections.firstIndex(of: previousSection) else {
            return true
        }
        return currentIndex > previousIndex
    }

    enum InsightsSection: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case forecast = "Forecast"
        case monthly = "Monthly"
        case health = "Health"

        var icon: String {
            switch self {
            case .daily: return "sun.max.fill"
            case .weekly: return "calendar.badge.clock"
            case .forecast: return "arrow.right.circle"
            case .monthly: return "calendar"
            case .health: return "heart.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Section Picker
            sectionPicker

            // Content - direction-aware transitions for smooth tab switching
            ZStack {
                // Daily View
                if selectedSection == .daily {
                    DailyInsightsTabView()
                        .transition(contentTransition)
                        .onAppear { dailyViewLoaded = true }
                }

                // Weekly View
                if selectedSection == .weekly {
                    WeeklyInsightsView()
                        .transition(contentTransition)
                        .onAppear { weeklyViewLoaded = true }
                }

                // Forecast View
                if selectedSection == .forecast {
                    NextWeekInsightsView()
                        .transition(contentTransition)
                        .onAppear { forecastViewLoaded = true }
                }

                // Monthly View
                if selectedSection == .monthly {
                    LifeInsightsView()
                        .transition(contentTransition)
                        .onAppear { monthlyViewLoaded = true }
                }

                // Health View
                if selectedSection == .health {
                    HealthInsightsDetailView()
                        .transition(contentTransition)
                        .onAppear { healthViewLoaded = true }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.9), value: selectedSection)
        }
        .background(DesignSystem.Colors.background)
        .task {
            // Load cached data first, then refresh in background
            await loadInitialData()
        }
        .onDisappear {
            // Cancel any pending requests when view disappears
            loadTask?.cancel()
            loadTask = nil
            weeklyNarrativeViewModel.cancelPendingRequests()
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToDailyInsights)) { _ in
            // Switch to Daily section when notification is received (from evening summary notification)
            withAnimation {
                previousSection = selectedSection
                selectedSection = .daily
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Insights")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Text("Understand your patterns")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.screenMargin)
        .padding(.top, DesignSystem.Spacing.md)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(InsightsSection.allCases, id: \.self) { section in
                    sectionButton(section)
                }

                // Health Goals button - shown inline with tabs when Health is selected
                if selectedSection == .health {
                    Button(action: {
                        showingHealthGoals = true
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }) {
                        Image(systemName: "target")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.primary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(DesignSystem.Colors.primary.opacity(0.15))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenMargin)
            .animation(.easeInOut(duration: 0.2), value: selectedSection)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.background)
        .sheet(isPresented: $showingHealthGoals) {
            HealthGoalsView()
        }
    }

    private func sectionButton(_ section: InsightsSection) -> some View {
        Button(action: {
            // Track previous section for direction-aware transition
            previousSection = selectedSection
            selectedSection = section
            HapticManager.shared.lightTap()
        }) {
            HStack(spacing: 4) {
                Image(systemName: section.icon)
                    .font(.caption2.weight(.semibold))
                Text(section.rawValue)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(selectedSection == section ? .white : DesignSystem.Colors.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(selectedSection == section ? Color.indigo : DesignSystem.Colors.cardBackground)
            )
            .scaleEffect(selectedSection == section ? 1.0 : 0.98)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: selectedSection)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Content Transition

    /// Direction-aware transition for tab content
    private var contentTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }

        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: isForwardTransition ? 30 : -30)),
            removal: .opacity.combined(with: .offset(x: isForwardTransition ? -30 : 30))
        )
    }

    // MARK: - Helper Functions

    private func loadInitialData() async {
        // Load cached data in parallel for instant UI
        async let narrativeTask: () = weeklyNarrativeViewModel.fetchNarrative()
        async let weeksTask: () = weeklyNarrativeViewModel.fetchAvailableWeeks()
        _ = await (narrativeTask, weeksTask)
    }
}

// MARK: - Supporting Views

struct InsightsStatRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)
        }
        .padding(.vertical, 4)
    }
}

struct InsightsHealthKitPermissionCard: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "heart.circle")
                .font(.system(size: 32))
                .foregroundColor(.pink.opacity(0.6))

            Text("Enable HealthKit")
                .font(.subheadline.weight(.medium))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text("Connect to see your health metrics")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)

            Button(action: {
                HealthKitManager.shared.safeRequestIfNeeded()
            }) {
                Text("Enable")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.pink))
            }
        }
        .padding(DesignSystem.Spacing.md)
    }
}

// MARK: - Preview

#Preview {
    InsightsRootView()
        .preferredColorScheme(.dark)
}
