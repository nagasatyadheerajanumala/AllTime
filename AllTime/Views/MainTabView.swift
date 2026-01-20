import SwiftUI

// ============================================================================
// PREMIUM GLASSY TAB BAR
// ============================================================================
//
// DESIGN PRINCIPLES:
// 1. Real blur using .ultraThinMaterial - content behind becomes unreadable
// 2. Subtle glass highlights - top sheen gradient + hairline stroke
// 3. Soft shadow to lift the bar off the background
// 4. Animated glow "blob" behind active tab for premium feel
// 5. Crisp icons with accent color for active state
//
// SAFE AREA HANDLING:
// - Bar sits close to bottom, respecting home indicator
// - No excessive padding that creates visual gaps
// - Material extends into safe area for seamless blur
// ============================================================================

// MARK: - Global Tab Bar Height (use this in content views for bottom padding)
enum TabBarMetrics {
    /// Height of the pill bar itself
    static let barHeight: CGFloat = 60
    /// Horizontal margin from screen edges
    static let horizontalMargin: CGFloat = 16
    /// Corner radius for the pill
    static let cornerRadius: CGFloat = 30
    /// Minimum touch target height (Apple HIG: 44pt)
    static let minTouchTarget: CGFloat = 44

    /// Total height including safe area - use this for content bottom padding
    static func totalHeight(safeAreaBottom: CGFloat) -> CGFloat {
        barHeight + safeAreaBottom + 8 // 8pt breathing room above bar
    }
}

// MARK: - Tab Definition
enum Tab: Int, CaseIterable, Identifiable {
    case today = 0
    case insights = 1
    case calendar = 2
    case health = 3
    case reminders = 4
    case settings = 5

    var id: Int { rawValue }

    var icon: String {
        switch self {
        case .today: return "sun.horizon"
        case .insights: return "lightbulb"
        case .calendar: return "calendar"
        case .health: return "heart"
        case .reminders: return "bell"
        case .settings: return "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .today: return "sun.horizon.fill"
        case .insights: return "lightbulb.fill"
        case .calendar: return "calendar"
        case .health: return "heart.fill"
        case .reminders: return "bell.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var title: String {
        switch self {
        case .today: return "Today"
        case .insights: return "Insights"
        case .calendar: return "Calendar"
        case .health: return "Health"
        case .reminders: return "Reminders"
        case .settings: return "Settings"
        }
    }

    var accentColor: Color {
        switch self {
        case .today: return .orange
        case .insights: return .indigo
        case .calendar: return .blue
        case .health: return .pink
        case .reminders: return .purple
        case .settings: return .gray
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @StateObject private var calendarViewModel = CalendarViewModel()
    @StateObject private var summaryViewModel = DailySummaryViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()

    @State private var selectedTab: Tab = .calendar
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var visitedTabs: Set<Tab> = [.calendar]

    // Sheets
    @State private var showingDaySummary = false
    @State private var showingDayReview = false

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let safeAreaBottom = geometry.safeAreaInsets.bottom

            ZStack(alignment: .bottom) {
                // LAYER 1: Tab content (scrollable, goes UNDER the tab bar)
                ZStack {
                    ForEach(Tab.allCases) { tab in
                        if visitedTabs.contains(tab) {
                            tabContent(for: tab)
                                .frame(width: screenWidth, height: geometry.size.height)
                                .offset(x: CGFloat(tab.rawValue - selectedTab.rawValue) * screenWidth + dragOffset)
                        }
                    }
                }
                .animation(isDragging ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: selectedTab)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            let h = value.translation.width
                            let v = abs(value.translation.height)
                            guard abs(h) > v * 0.5 else { return }
                            isDragging = true
                            preloadAdjacentTabs()
                            if (selectedTab == .today && h > 0) || (selectedTab == .settings && h < 0) {
                                dragOffset = h * 0.25
                            } else {
                                dragOffset = h
                            }
                        }
                        .onEnded { value in
                            isDragging = false
                            let h = value.translation.width
                            let v = value.predictedEndTranslation.width - h
                            let threshold = screenWidth * 0.2

                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                if abs(h) > threshold || abs(v) > 300 {
                                    if h < 0 || v < -300, let next = Tab(rawValue: selectedTab.rawValue + 1) {
                                        selectedTab = next
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    } else if h > 0 || v > 300, let prev = Tab(rawValue: selectedTab.rawValue - 1) {
                                        selectedTab = prev
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                }
                                dragOffset = 0
                            }
                        }
                )

                // LAYER 2: Premium Glassy Tab Bar (on TOP, samples content beneath)
                GlassyTabBar(
                    selectedTab: $selectedTab,
                    safeAreaBottom: safeAreaBottom,
                    onTabChange: { tab in
                        visitedTabs.insert(tab)
                    }
                )
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: selectedTab) { _, newTab in
            visitedTabs.insert(newTab)
        }
        .sheet(isPresented: $showingDaySummary) {
            DaySummaryView().environmentObject(calendarViewModel)
        }
        .sheet(isPresented: $showingDayReview) {
            DailyInsightsView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToEveningSummary)) { _ in
            showingDaySummary = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToDayReview)) { _ in
            showingDayReview = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToToday)) { _ in
            withAnimation { selectedTab = .today }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToCalendar)) { _ in
            withAnimation { selectedTab = .calendar }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToSummary)) { _ in
            showingDaySummary = true
        }
    }

    private func preloadAdjacentTabs() {
        if let prev = Tab(rawValue: selectedTab.rawValue - 1) { visitedTabs.insert(prev) }
        if let next = Tab(rawValue: selectedTab.rawValue + 1) { visitedTabs.insert(next) }
    }

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .today: TodayView().environmentObject(calendarViewModel)
        case .insights: InsightsTabView()
        case .calendar: CalendarView().environmentObject(calendarViewModel)
        case .health: HealthSummaryView()
        case .reminders: ReminderListView()
        case .settings: SettingsView().environmentObject(settingsViewModel)
        }
    }
}

// MARK: - Premium Glassy Tab Bar
/// A premium glass-effect tab bar with:
/// - Real blur using ultraThinMaterial (content behind is unreadable)
/// - Subtle glass highlights and hairline stroke
/// - Soft shadow to lift the bar off the background
/// - Animated glow "blob" behind the active tab
/// - Crisp icons with accent colors
/// - Proper safe area handling (sits close to bottom)
struct GlassyTabBar: View {
    @Binding var selectedTab: Tab
    let safeAreaBottom: CGFloat
    var onTabChange: ((Tab) -> Void)?

    @Environment(\.colorScheme) var colorScheme
    @Namespace private var glowNamespace

    private let tabCount = Tab.allCases.count

    var body: some View {
        VStack(spacing: 0) {
            // The floating glass pill bar
            GeometryReader { geo in
                let pillWidth = geo.size.width - (TabBarMetrics.horizontalMargin * 2)
                let tabWidth = pillWidth / CGFloat(tabCount)

                ZStack {
                    // LAYER 1: Glass background with blur
                    glassBackground

                    // LAYER 2: Animated glow behind active tab
                    activeTabGlow(tabWidth: tabWidth, pillWidth: pillWidth)

                    // LAYER 3: Tab buttons
                    tabButtons(tabWidth: tabWidth)
                }
                .frame(height: TabBarMetrics.barHeight)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, TabBarMetrics.horizontalMargin)
            }
            .frame(height: TabBarMetrics.barHeight)

            // Safe area fill - seamless blur extension
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: safeAreaBottom)
                .ignoresSafeArea(edges: .bottom)
        }
        .frame(height: TabBarMetrics.barHeight + safeAreaBottom)
        // Full-width blur background that extends into safe area
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Glass Background
    /// The main glass pill with blur, highlights, and shadow
    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: TabBarMetrics.cornerRadius, style: .continuous)
            // Base blur material - this actually blurs content behind
            .fill(.ultraThinMaterial)
            // Dark scrim for better contrast
            .overlay(
                RoundedRectangle(cornerRadius: TabBarMetrics.cornerRadius, style: .continuous)
                    .fill(
                        colorScheme == .dark
                            ? Color.black.opacity(0.25)
                            : Color.white.opacity(0.1)
                    )
            )
            // Inner sheen - top highlight gradient for glass effect
            .overlay(
                RoundedRectangle(cornerRadius: TabBarMetrics.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.12 : 0.25),
                                Color.white.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            )
            // Hairline stroke border
            .overlay(
                RoundedRectangle(cornerRadius: TabBarMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.2 : 0.4),
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.15)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            // Soft shadow to lift the bar
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    // MARK: - Active Tab Glow
    /// Animated glow "blob" behind the selected tab
    private func activeTabGlow(tabWidth: CGFloat, pillWidth: CGFloat) -> some View {
        let glowWidth: CGFloat = tabWidth * 0.85
        let glowHeight: CGFloat = TabBarMetrics.barHeight * 0.7
        let xOffset = calculateGlowOffset(tabWidth: tabWidth, pillWidth: pillWidth)

        return ZStack {
            // Outer soft glow
            Capsule()
                .fill(
                    RadialGradient(
                        colors: [
                            selectedTab.accentColor.opacity(0.4),
                            selectedTab.accentColor.opacity(0.15),
                            selectedTab.accentColor.opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: glowWidth * 0.6
                    )
                )
                .frame(width: glowWidth * 1.3, height: glowHeight * 1.2)
                .blur(radius: 8)

            // Inner bright glow
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            selectedTab.accentColor.opacity(colorScheme == .dark ? 0.5 : 0.35),
                            selectedTab.accentColor.opacity(colorScheme == .dark ? 0.25 : 0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: glowWidth, height: glowHeight)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            selectedTab.accentColor.opacity(0.5),
                            lineWidth: 1
                        )
                )
        }
        .offset(x: xOffset)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: selectedTab)
    }

    /// Calculate the x-offset for the glow based on selected tab
    private func calculateGlowOffset(tabWidth: CGFloat, pillWidth: CGFloat) -> CGFloat {
        let startX = -pillWidth / 2 + tabWidth / 2
        return startX + CGFloat(selectedTab.rawValue) * tabWidth
    }

    // MARK: - Tab Buttons
    /// The row of tab buttons
    private func tabButtons(tabWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                tabButton(for: tab)
                    .frame(width: tabWidth)
            }
        }
    }

    /// Individual tab button
    private func tabButton(for tab: Tab) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedTab = tab
            }
            onTabChange?(tab)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 4) {
                // Icon
                Image(systemName: selectedTab == tab ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 22, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundStyle(iconColor(for: tab))
                    .scaleEffect(selectedTab == tab ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedTab == tab)

                // Label
                Text(tab.title)
                    .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .medium))
                    .foregroundStyle(labelColor(for: tab))
            }
            .frame(maxWidth: .infinity)
            .frame(height: TabBarMetrics.barHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassButtonStyle())
    }

    // MARK: - Colors
    private func iconColor(for tab: Tab) -> Color {
        if selectedTab == tab {
            return tab.accentColor
        }
        return colorScheme == .dark
            ? .white.opacity(0.5)
            : .primary.opacity(0.45)
    }

    private func labelColor(for tab: Tab) -> Color {
        if selectedTab == tab {
            return tab.accentColor
        }
        return colorScheme == .dark
            ? .white.opacity(0.4)
            : .primary.opacity(0.35)
    }
}

// Button style moved to DesignSystem.swift (GlassButtonStyle)

// MARK: - Preview
#Preview("Dark") {
    MainTabView()
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    MainTabView()
        .preferredColorScheme(.light)
}
