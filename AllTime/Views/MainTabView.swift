import SwiftUI

// ============================================================================
// iOS 26 PHONE APP STYLE TAB BAR
// ============================================================================
//
// Inspired by the iOS 26 Phone app navbar where:
// - Swipe on the tab bar itself to switch tabs
// - Liquid glass floating indicator slides between icons
// - Ultra-thin translucent material
// - Minimal, refined appearance
// ============================================================================

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

    @State private var selectedTab: Tab = .today
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    // Lazy loading
    @State private var visitedTabs: Set<Tab> = [.today]

    // Sheets
    @State private var showingDaySummary = false
    @State private var showingDayReview = false

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width

            ZStack(alignment: .bottom) {
                // Tab content with swipe
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

                // iOS 26 Phone-style Tab Bar
                iOS26PhoneTabBar(
                    selectedTab: $selectedTab,
                    safeAreaBottom: geometry.safeAreaInsets.bottom,
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
            DayReviewView()
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

// MARK: - iOS 26 Phone-Style Tab Bar
/// Swipeable tab bar like iOS 26 Phone app - swipe on the bar itself to switch tabs
struct iOS26PhoneTabBar: View {
    @Binding var selectedTab: Tab
    let safeAreaBottom: CGFloat
    var onTabChange: ((Tab) -> Void)?

    @Environment(\.colorScheme) var colorScheme
    @GestureState private var dragState: CGFloat = 0
    @State private var indicatorOffset: CGFloat = 0

    private let tabCount = Tab.allCases.count
    private let indicatorWidth: CGFloat = 56
    private let barHeight: CGFloat = 52

    var body: some View {
        GeometryReader { geo in
            let tabWidth = (geo.size.width - 32) / CGFloat(tabCount)

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    // Glass background
                    iOS26GlassBar()

                    // Sliding indicator
                    HStack(spacing: 0) {
                        // Calculate indicator position with drag
                        let baseOffset = CGFloat(selectedTab.rawValue) * tabWidth
                        let dragAdjusted = baseOffset - (dragState / geo.size.width) * tabWidth * 2

                        Capsule()
                            .fill(selectedTab.accentColor.opacity(colorScheme == .dark ? 0.35 : 0.25))
                            .frame(width: indicatorWidth, height: 36)
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        selectedTab.accentColor.opacity(0.4),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: selectedTab.accentColor.opacity(0.3), radius: 8, y: 2)
                            .offset(x: clampedOffset(dragAdjusted, tabWidth: tabWidth, totalWidth: geo.size.width - 32))
                            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.75), value: selectedTab)
                            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.8), value: dragState)

                        Spacer()
                    }
                    .padding(.horizontal, 16 + (tabWidth - indicatorWidth) / 2)

                    // Tab icons
                    HStack(spacing: 0) {
                        ForEach(Tab.allCases) { tab in
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    selectedTab = tab
                                }
                                onTabChange?(tab)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                VStack(spacing: 2) {
                                    Image(systemName: selectedTab == tab ? tab.selectedIcon : tab.icon)
                                        .font(.system(size: 22, weight: selectedTab == tab ? .semibold : .regular))
                                        .foregroundStyle(selectedTab == tab ? selectedTab.accentColor : iconColor)
                                        .scaleEffect(selectedTab == tab ? 1.1 : 1.0)

                                    Text(tab.title)
                                        .font(.system(size: 9, weight: selectedTab == tab ? .semibold : .medium))
                                        .foregroundStyle(selectedTab == tab ? selectedTab.accentColor : labelColor)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: barHeight)
                            }
                            .buttonStyle(iOS26TabButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: barHeight)
                .padding(.horizontal, 16)
                // Swipe gesture on the tab bar
                .gesture(
                    DragGesture()
                        .updating($dragState) { value, state, _ in
                            state = value.translation.width
                        }
                        .onEnded { value in
                            let velocity = value.predictedEndTranslation.width - value.translation.width
                            let threshold: CGFloat = 30

                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                if value.translation.width < -threshold || velocity < -200 {
                                    if let next = Tab(rawValue: selectedTab.rawValue + 1) {
                                        selectedTab = next
                                        onTabChange?(next)
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    }
                                } else if value.translation.width > threshold || velocity > 200 {
                                    if let prev = Tab(rawValue: selectedTab.rawValue - 1) {
                                        selectedTab = prev
                                        onTabChange?(prev)
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    }
                                }
                            }
                        }
                )

                // Safe area spacing
                Color.clear.frame(height: max(safeAreaBottom - 8, 4))
            }
        }
        .frame(height: barHeight + max(safeAreaBottom, 12))
    }

    private func clampedOffset(_ offset: CGFloat, tabWidth: CGFloat, totalWidth: CGFloat) -> CGFloat {
        let maxOffset = totalWidth - indicatorWidth
        return min(max(offset, 0), maxOffset)
    }

    private var iconColor: Color {
        colorScheme == .dark ? .white.opacity(0.5) : .primary.opacity(0.4)
    }

    private var labelColor: Color {
        colorScheme == .dark ? .white.opacity(0.35) : .primary.opacity(0.3)
    }
}

// MARK: - iOS 26 Glass Bar Background
struct iOS26GlassBar: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Ultra-thin glass material
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(colorScheme == .dark ? 0.85 : 0.9)

            // Subtle inner highlight
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(colorScheme == .dark ? 0.08 : 0.4),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            // Border glow
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(colorScheme == .dark ? 0.2 : 0.5),
                            .white.opacity(colorScheme == .dark ? 0.05 : 0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.1), radius: 20, y: 8)
    }
}

// MARK: - Tab Button Style
struct iOS26TabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview("Dark") {
    MainTabView()
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    MainTabView()
        .preferredColorScheme(.light)
}
