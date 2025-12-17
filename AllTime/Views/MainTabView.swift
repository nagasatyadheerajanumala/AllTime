import SwiftUI

// MARK: - Tab Definition
enum Tab: Int, CaseIterable {
    case today = 0
    case calendar = 1
    case health = 2
    case reminders = 3
    case settings = 4

    var icon: String {
        switch self {
        case .today: return "sun.horizon"
        case .calendar: return "calendar"
        case .health: return "heart"
        case .reminders: return "bell"
        case .settings: return "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .today: return "sun.horizon.fill"
        case .calendar: return "calendar"
        case .health: return "heart.fill"
        case .reminders: return "bell.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var title: String {
        switch self {
        case .today: return "Today"
        case .calendar: return "Calendar"
        case .health: return "Health"
        case .reminders: return "Reminders"
        case .settings: return "Settings"
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
    @Namespace private var tabAnimation

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width

            ZStack(alignment: .bottom) {
                // Horizontal paging content
                HStack(spacing: 0) {
                    // Today
                    TodayView()
                        .environmentObject(calendarViewModel)
                        .frame(width: screenWidth)

                    // Calendar
                    CalendarView()
                        .environmentObject(calendarViewModel)
                        .frame(width: screenWidth)

                    // Health
                    HealthSummaryView()
                        .frame(width: screenWidth)

                    // Reminders
                    ReminderListView()
                        .frame(width: screenWidth)

                    // Settings
                    SettingsView()
                        .environmentObject(settingsViewModel)
                        .frame(width: screenWidth)
                }
                .offset(x: -CGFloat(selectedTab.rawValue) * screenWidth + dragOffset)
                .animation(.spring(response: 0.35, dampingFraction: 0.86), value: selectedTab)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            let horizontalAmount = value.translation.width
                            let verticalAmount = abs(value.translation.height)

                            // Only allow horizontal swipes
                            guard abs(horizontalAmount) > verticalAmount * 0.5 else { return }

                            // Add rubber banding at edges
                            if (selectedTab == .today && horizontalAmount > 0) ||
                               (selectedTab == .settings && horizontalAmount < 0) {
                                // Rubber band effect at edges
                                dragOffset = horizontalAmount * 0.3
                            } else {
                                dragOffset = horizontalAmount
                            }
                        }
                        .onEnded { value in
                            handleSwipe(value: value, screenWidth: screenWidth)
                        }
                )

                // Custom floating tab bar
                iOS26TabBar(
                    selectedTab: $selectedTab,
                    namespace: tabAnimation,
                    safeAreaBottom: geometry.safeAreaInsets.bottom
                )
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Swipe Handling
    private func handleSwipe(value: DragGesture.Value, screenWidth: CGFloat) {
        let threshold: CGFloat = screenWidth * 0.15
        let velocity = value.predictedEndTranslation.width - value.translation.width
        let horizontalAmount = value.translation.width

        // Consider velocity for more natural feel
        let shouldSwipe = abs(horizontalAmount) > threshold || abs(velocity) > 200

        if shouldSwipe {
            if horizontalAmount < 0 || velocity < -200 {
                // Swipe left - next tab
                if let nextTab = Tab(rawValue: selectedTab.rawValue + 1) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        selectedTab = nextTab
                        dragOffset = 0
                    }
                    generateHaptic(.light)
                    return
                }
            } else if horizontalAmount > 0 || velocity > 200 {
                // Swipe right - previous tab
                if let prevTab = Tab(rawValue: selectedTab.rawValue - 1) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        selectedTab = prevTab
                        dragOffset = 0
                    }
                    generateHaptic(.light)
                    return
                }
            }
        }

        // Snap back
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            dragOffset = 0
        }
    }

    private func generateHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impact = UIImpactFeedbackGenerator(style: style)
        impact.impactOccurred()
    }
}

// MARK: - iOS 26 Style Tab Bar
struct iOS26TabBar: View {
    @Binding var selectedTab: Tab
    var namespace: Namespace.ID
    var safeAreaBottom: CGFloat

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar content
            HStack(spacing: 4) {
                ForEach(Tab.allCases, id: \.rawValue) { tab in
                    iOS26TabItem(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        namespace: namespace
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                            selectedTab = tab
                        }
                        generateHaptic()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background {
                // Glass container
                GlassBackground(colorScheme: colorScheme)
            }
            .padding(.horizontal, 12)
        }
        .padding(.bottom, safeAreaBottom > 0 ? safeAreaBottom : 16)
    }

    private func generateHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
}

// MARK: - Glass Background
struct GlassBackground: View {
    let colorScheme: ColorScheme

    private let cornerRadius: CGFloat = 28

    var body: some View {
        ZStack {
            // Base blur - thicker material for more premium feel
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.regularMaterial)

            // Subtle color tint for depth
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    colorScheme == .dark
                        ? Color.white.opacity(0.03)
                        : Color.black.opacity(0.02)
                )

            // Top highlight for 3D effect
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.15 : 0.5),
                            Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            // Inner border - subtle and elegant
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.3 : 0.6),
                            Color.white.opacity(colorScheme == .dark ? 0.1 : 0.2),
                            Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        }
        // Layered shadows for depth
        .shadow(color: Color.black.opacity(0.15), radius: 24, x: 0, y: 12)
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 2)
    }
}

// MARK: - Tab Item
struct iOS26TabItem: View {
    let tab: Tab
    let isSelected: Bool
    var namespace: Namespace.ID
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme

    // Animation values
    private var scale: CGFloat { isSelected ? 1.05 : 1.0 }
    private var yOffset: CGFloat { isSelected ? -2 : 0 }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    // Selected indicator pill (slides between tabs)
                    if isSelected {
                        Capsule()
                            .fill(selectedPillGradient)
                            .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                            .frame(width: 60, height: 36)
                            .shadow(color: accentColor.opacity(0.35), radius: 10, x: 0, y: 4)
                    }

                    // Icon
                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .white : secondaryColor)
                        .frame(width: 36, height: 36)
                }
                .frame(height: 36)

                // Label
                Text(tab.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? primaryColor : tertiaryColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .scaleEffect(scale)
            .offset(y: yOffset)
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isSelected)
        }
        .buttonStyle(TabItemButtonStyle())
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Colors
    private var accentColor: Color {
        switch tab {
        case .today: return .orange
        case .calendar: return .blue
        case .health: return .pink
        case .reminders: return .purple
        case .settings: return .gray
        }
    }

    private var selectedPillGradient: LinearGradient {
        LinearGradient(
            colors: [
                accentColor,
                accentColor.opacity(0.85)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var primaryColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var secondaryColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.6) : Color.primary.opacity(0.5)
    }

    private var tertiaryColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.45) : Color.primary.opacity(0.4)
    }
}

// MARK: - Button Style
struct TabItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    MainTabView()
        .preferredColorScheme(.light)
}
