import SwiftUI

/// InsightsRootView - Combined Health + Weekly Insights Tab
/// Moved from: Health tab (HealthInsightsDetailView) + Weekly Insights from TodayView
/// This is the main Insights tab replacing the old Health tab
/// Optimized with task cancellation and proper ViewModel lifecycle management
struct InsightsRootView: View {
    @State private var selectedSection: InsightsSection = .weekly
    @StateObject private var weeklyNarrativeViewModel = WeeklyNarrativeViewModel()
    @ObservedObject private var healthMetricsService = HealthMetricsService.shared
    @State private var loadTask: Task<Void, Never>?

    // Track which views have been loaded to preserve their state
    @State private var weeklyViewLoaded = false
    @State private var monthlyViewLoaded = false
    @State private var healthViewLoaded = false

    enum InsightsSection: String, CaseIterable {
        case weekly = "Weekly"
        case monthly = "Monthly"
        case health = "Health"

        var icon: String {
            switch self {
            case .weekly: return "calendar.badge.clock"
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

            // Content - use ZStack with opacity for instant switching
            ZStack {
                // Weekly View
                if weeklyViewLoaded || selectedSection == .weekly {
                    WeeklyInsightsView()
                        .opacity(selectedSection == .weekly ? 1 : 0)
                        .allowsHitTesting(selectedSection == .weekly)
                        .onAppear { weeklyViewLoaded = true }
                }

                // Monthly View
                if monthlyViewLoaded || selectedSection == .monthly {
                    LifeInsightsView()
                        .opacity(selectedSection == .monthly ? 1 : 0)
                        .allowsHitTesting(selectedSection == .monthly)
                        .onAppear { monthlyViewLoaded = true }
                }

                // Health View
                if healthViewLoaded || selectedSection == .health {
                    HealthInsightsDetailView()
                        .opacity(selectedSection == .health ? 1 : 0)
                        .allowsHitTesting(selectedSection == .health)
                        .onAppear { healthViewLoaded = true }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

            // Clara AI badge - premium, subtle
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.semibold))
                Text("Clara")
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.indigo.opacity(0.8), Color.purple.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
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
            }
            .padding(.horizontal, DesignSystem.Spacing.screenMargin)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.background)
    }

    private func sectionButton(_ section: InsightsSection) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSection = section
            }
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
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
        }
        .buttonStyle(PlainButtonStyle())
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
