import SwiftUI

struct PremiumTabView: View {
    @ObservedObject private var navigationManager = NavigationManager.shared
    @Namespace private var tabAnimation
    @State private var hasRequestedHealthKit = false
    @State private var showingClaraChat = false

    // Pre-create views to preserve their state across tab switches
    // This prevents unnecessary reloading when switching tabs
    @State private var todayViewCreated = false
    @State private var calendarViewCreated = false
    @State private var insightsViewCreated = false
    @State private var remindersViewCreated = false
    @State private var settingsViewCreated = false

    // Clara button gradient
    private let claraGradient = LinearGradient(
        colors: [DesignSystem.Colors.violet, DesignSystem.Colors.claraPurpleLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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
                Color.clear.frame(height: 70) // barHeight (60) + padding (8) + buffer
            }

            // Floating Clara Button - bottom right, above tab bar
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showingClaraChat = true
                    }) {
                        ZStack {
                            // Outer glow
                            Circle()
                                .fill(claraGradient)
                                .frame(width: 56, height: 56)
                                .shadow(color: DesignSystem.Colors.violet.opacity(0.5), radius: 12, x: 0, y: 6)

                            // Sparkle icon
                            Image(systemName: "sparkles")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(FABButtonStyle())
                    .padding(.trailing, DesignSystem.Spacing.lg) // Match + FAB alignment
                    .padding(.bottom, 90) // Above tab bar
                }
            }

            // Floating Tab Bar
            FloatingTabBar(
                selectedTab: $navigationManager.selectedTab,
                namespace: tabAnimation
            )
        }
        .sheet(isPresented: $showingClaraChat) {
            ClaraChatView()
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

// MARK: - Premium Glassy Tab Bar
/// Clean floating pill navbar - no extra bars or backgrounds
struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    var namespace: Namespace.ID
    @Environment(\.colorScheme) var colorScheme

    private let tabs: [(icon: String, selectedIcon: String, title: String, color: Color)] = [
        ("sun.horizon", "sun.horizon.fill", "Today", .orange),
        ("calendar", "calendar", "Calendar", .blue),
        ("chart.bar.xaxis", "chart.bar.xaxis", "Insights", .indigo),
        ("bell", "bell.fill", "Reminders", .purple),
        ("gearshape", "gearshape.fill", "Settings", .gray)
    ]

    private let barHeight: CGFloat = 60
    private let cornerRadius: CGFloat = 30

    var body: some View {
        GeometryReader { geo in
            let tabWidth = (geo.size.width - 32) / CGFloat(tabs.count)

            ZStack {
                // Glass pill background
                glassBackground

                // Active tab glow
                activeTabGlow(tabWidth: tabWidth, totalWidth: geo.size.width - 32)

                // Tab buttons
                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        tabButton(index: index, tab: tab)
                    }
                }
            }
            .frame(height: barHeight)
            .padding(.horizontal, 16)
        }
        .frame(height: barHeight)
        .padding(.bottom, 8)
        // Gradient starts slightly above bottom of navbar
        .background(
            VStack(spacing: 0) {
                // Clear area above gradient
                Color.clear
                    .frame(height: barHeight - 15)

                // Gradient fade to bottom
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: Color(white: 0.05).opacity(0.9), location: 0.5),
                        .init(color: Color(white: 0.04), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Glass Background
    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            // Base blur - THIS is what makes content behind unreadable
            .fill(.ultraThinMaterial)
            // Dark scrim for better contrast
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.3))
            )
            // Inner sheen - top highlight for glass effect
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            )
            // Hairline stroke border
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            // Soft shadow
            .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 10)
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    // MARK: - Active Tab Glow
    private func activeTabGlow(tabWidth: CGFloat, totalWidth: CGFloat) -> some View {
        let currentColor = tabs[selectedTab].color

        // Calculate x offset from center of pill
        let xOffset = CGFloat(selectedTab) * tabWidth - totalWidth / 2 + tabWidth / 2

        return ZStack {
            // Outer soft glow
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            currentColor.opacity(0.5),
                            currentColor.opacity(0.2),
                            currentColor.opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 50
                    )
                )
                .frame(width: 80, height: 60)
                .blur(radius: 8)

            // Inner bright glow - covers icon + label
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            currentColor.opacity(0.75),
                            currentColor.opacity(0.45)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 58, height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(currentColor.opacity(0.5), lineWidth: 1)
                )
        }
        .offset(x: xOffset, y: 0) // Centered on icon + label
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: selectedTab)
    }

    // MARK: - Tab Button
    private func tabButton(index: Int, tab: (icon: String, selectedIcon: String, title: String, color: Color)) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedTab = index
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: selectedTab == index ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 22, weight: selectedTab == index ? .semibold : .regular))
                    .foregroundStyle(selectedTab == index ? .white : .white.opacity(0.5))
                    .scaleEffect(selectedTab == index ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedTab == index)

                Text(tab.title)
                    .font(.system(size: 10, weight: selectedTab == index ? .semibold : .medium))
                    .foregroundStyle(selectedTab == index ? .white : .white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .frame(height: barHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassButtonStyle())
    }
}

// Button styles moved to DesignSystem.swift (GlassButtonStyle, FABButtonStyle)


#Preview {
    PremiumTabView()
        .environmentObject(CalendarViewModel())
        .environmentObject(SummaryViewModel())
        .environmentObject(SettingsViewModel())
        .preferredColorScheme(.dark)
}
