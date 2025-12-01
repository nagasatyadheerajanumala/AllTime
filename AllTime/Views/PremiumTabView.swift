import SwiftUI

struct PremiumTabView: View {
    @State private var selectedTab = 0
    @Namespace private var animation
    @State private var hasRequestedHealthKit = false
    
    // iOS Native Tab Bar Height
    // Standard iOS tab bar: 49pt + safe area bottom (~34pt on iPhone) = ~83pt total
    private let tabBarHeight: CGFloat = 49
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Official Chrona Dark Theme - Pure Black Background
            DesignSystem.Colors.background
                .ignoresSafeArea()
            
            // Tab Content - Switch instead of TabView for better performance
            Group {
                switch selectedTab {
                case 0:
                    TodayView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                case 1:
                    CalendarView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                case 2:
                    HealthInsightsDetailView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                case 3:
                    ReminderListView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                case 4:
                    SettingsView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                default:
                    TodayView()
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedTab)
            .safeAreaInset(edge: .bottom) {
                // Reserve space for the tab bar so content doesn't go behind it
                Color.clear
                    .frame(height: tabBarHeight)
            }
            
            // Classic Tab Bar - positioned at bottom with minimal safe area
            VStack {
                Spacer()
                PremiumTabBar(selectedTab: $selectedTab, animation: animation)
                    .padding(.bottom, 0) // No extra padding - let safe area handle it naturally
            }
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            // Request HealthKit permissions AFTER UI is fully ready and user is logged in
            // This ensures the permission popup appears at the right time
            // Only request once per app session
            guard !hasRequestedHealthKit else {
                print("🏥 PremiumTabView: Already requested HealthKit permissions, skipping")
                return
            }
            
            // CRITICAL: Ensure app is active before requesting
            guard UIApplication.shared.applicationState == .active else {
                print("🏥 PremiumTabView: App not active yet, will check when active")
                return
            }
            
            print("🏥 PremiumTabView: Dashboard appeared - checking HealthKit permissions...")
            print("🏥 PremiumTabView: App state: \(UIApplication.shared.applicationState.rawValue) (0=active)")
            print("🏥 PremiumTabView: Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
            
            hasRequestedHealthKit = true
            
            // Use safeRequestIfNeeded which only checks for .notDetermined and otherwise proceeds
            // Run diagnostic first to check capability
            HealthKitManager.shared.diagnoseHealthKitSetup()
            
            // Small delay to ensure everything is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                HealthKitManager.shared.safeRequestIfNeeded()
            }
        }
    }
}

struct PremiumTabBar: View {
    @Binding var selectedTab: Int
    let animation: Namespace.ID
    
    private let tabs: [(icon: String, title: String)] = [
        ("calendar.day.timeline.left", "Today"),
        ("calendar", "Calendar"),
        ("heart.text.square", "Health"),
        ("bell.fill", "Reminders"),
        ("gearshape.fill", "Settings")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 4) {
                        // Icon
                        Image(systemName: tab.icon)
                            .font(.system(size: 23, weight: selectedTab == index ? .semibold : .regular))
                            .foregroundColor(selectedTab == index ? DesignSystem.Colors.primary : DesignSystem.Colors.secondaryText)
                            .frame(width: 28, height: 28)
                            .symbolEffect(.bounce, value: selectedTab == index)
                        
                        // Label
                        Text(tab.title)
                            .font(.system(size: 10, weight: selectedTab == index ? .semibold : .regular))
                            .foregroundColor(selectedTab == index ? DesignSystem.Colors.primary : DesignSystem.Colors.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(height: 49) // iOS standard tab bar height
        .background(
            // iOS Native Tab Bar Style
            ZStack {
                // Ultra thin material with blur - iOS native style
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .background(
                        // Subtle dark background for dark theme
                        DesignSystem.Colors.cardBackground.opacity(0.95)
                    )
                
                // Top border - subtle separation
                VStack {
                    Rectangle()
                        .fill(DesignSystem.Colors.tertiaryText.opacity(0.2))
                        .frame(height: 0.5)
                    Spacer()
                }
            }
        )
        .overlay(
            // Subtle shadow for depth
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 1)
                .allowsHitTesting(false)
        )
    }
}

#Preview {
    PremiumTabView()
        .environmentObject(CalendarViewModel())
        .environmentObject(SummaryViewModel())
        .environmentObject(SettingsViewModel())
}

