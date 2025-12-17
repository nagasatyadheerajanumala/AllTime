import SwiftUI

struct PremiumTabView: View {
    @State private var selectedTab = 0
    @Namespace private var tabAnimation
    @State private var hasRequestedHealthKit = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            DesignSystem.Colors.background
                .ignoresSafeArea()

            // Content - using switch for proper view lifecycle
            Group {
                switch selectedTab {
                case 0:
                    TodayView()
                case 1:
                    CalendarView()
                case 2:
                    HealthInsightsDetailView()
                case 3:
                    ReminderListView()
                case 4:
                    SettingsView()
                default:
                    TodayView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Reserve space at bottom for tab bar
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 90)
            }

            // Floating Tab Bar
            FloatingTabBar(
                selectedTab: $selectedTab,
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

    private let tabs: [(icon: String, selectedIcon: String, title: String, color: Color)] = [
        ("sun.horizon", "sun.horizon.fill", "Today", .orange),
        ("calendar", "calendar", "Calendar", .blue),
        ("heart", "heart.fill", "Health", .pink),
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
