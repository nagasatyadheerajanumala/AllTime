import SwiftUI

struct PremiumTabView: View {
    @ObservedObject private var navigationManager = NavigationManager.shared
    @Namespace private var tabAnimation
    @State private var hasRequestedHealthKit = false

    // Pre-create views to preserve their state across tab switches
    // This prevents unnecessary reloading when switching tabs
    @State private var todayViewCreated = false
    @State private var calendarViewCreated = false
    @State private var insightsViewCreated = false
    @State private var remindersViewCreated = false
    @State private var settingsViewCreated = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            DesignSystem.Colors.background
                .ignoresSafeArea()

            // Content - use ZStack with opacity to preserve view state
            // This prevents views from being recreated on every tab switch
            ZStack {
                // Today View (Tab 0)
                if todayViewCreated || navigationManager.selectedTab == 0 {
                    TodayView()
                        .opacity(navigationManager.selectedTab == 0 ? 1 : 0)
                        .allowsHitTesting(navigationManager.selectedTab == 0)
                        .onAppear { todayViewCreated = true }
                }

                // Calendar View (Tab 1)
                if calendarViewCreated || navigationManager.selectedTab == 1 {
                    CalendarView()
                        .opacity(navigationManager.selectedTab == 1 ? 1 : 0)
                        .allowsHitTesting(navigationManager.selectedTab == 1)
                        .onAppear { calendarViewCreated = true }
                }

                // Insights View (Tab 2)
                if insightsViewCreated || navigationManager.selectedTab == 2 {
                    InsightsRootView()
                        .opacity(navigationManager.selectedTab == 2 ? 1 : 0)
                        .allowsHitTesting(navigationManager.selectedTab == 2)
                        .onAppear { insightsViewCreated = true }
                }

                // Reminders View (Tab 3)
                if remindersViewCreated || navigationManager.selectedTab == 3 {
                    ReminderListView()
                        .opacity(navigationManager.selectedTab == 3 ? 1 : 0)
                        .allowsHitTesting(navigationManager.selectedTab == 3)
                        .onAppear { remindersViewCreated = true }
                }

                // Settings View (Tab 4)
                if settingsViewCreated || navigationManager.selectedTab == 4 {
                    SettingsView()
                        .opacity(navigationManager.selectedTab == 4 ? 1 : 0)
                        .allowsHitTesting(navigationManager.selectedTab == 4)
                        .onAppear { settingsViewCreated = true }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Reserve space at bottom for tab bar
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 90)
            }

            // Floating Tab Bar
            FloatingTabBar(
                selectedTab: $navigationManager.selectedTab,
                namespace: tabAnimation
            )
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            guard !hasRequestedHealthKit else {
                print("🏥 PremiumTabView: Already requested HealthKit permissions, skipping")
                return
            }

            guard UIApplication.shared.applicationState == .active else {
                print("🏥 PremiumTabView: App not active yet, will check when active")
                return
            }

            print("🏥 PremiumTabView: Dashboard appeared - checking HealthKit permissions...")
            hasRequestedHealthKit = true

            HealthKitManager.shared.diagnoseHealthKitSetup()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                HealthKitManager.shared.safeRequestIfNeeded()
            }
        }
    }
}

// MARK: - Floating Tab Bar
struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    var namespace: Namespace.ID

    // Tab configuration: Health renamed to Insights, icon updated to chart.bar.xaxis
    private let tabs: [(icon: String, selectedIcon: String, title: String, color: Color)] = [
        ("sun.horizon", "sun.horizon.fill", "Today", .orange),
        ("calendar", "calendar", "Calendar", .blue),
        ("chart.bar.xaxis", "chart.bar.xaxis", "Insights", .indigo),
        ("bell", "bell.fill", "Reminders", .purple),
        ("gearshape", "gearshape.fill", "Settings", .gray)
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                TabBarButton(
                    icon: tab.icon,
                    selectedIcon: tab.selectedIcon,
                    title: tab.title,
                    color: tab.color,
                    isSelected: selectedTab == index,
                    namespace: namespace
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedTab = index
                    }
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.black.opacity(0.2))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                }
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let icon: String
    let selectedIcon: String
    let title: String
    let color: Color
    let isSelected: Bool
    var namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(color.gradient)
                            .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                            .frame(width: 52, height: 32)
                            .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)
                    }

                    Image(systemName: isSelected ? selectedIcon : icon)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .white : Color.white.opacity(0.5))
                        .frame(width: 32, height: 32)
                }
                .frame(height: 32)

                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : Color.white.opacity(0.4))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    PremiumTabView()
        .environmentObject(CalendarViewModel())
        .environmentObject(SummaryViewModel())
        .environmentObject(SettingsViewModel())
        .preferredColorScheme(.dark)
}
