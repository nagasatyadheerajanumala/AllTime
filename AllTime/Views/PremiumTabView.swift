import SwiftUI

struct PremiumTabView: View {
    @State private var selectedTab = 0
    @Namespace private var animation
    @State private var hasRequestedHealthKit = false
    
    // Classic tab bar height - positioned lower with minimal safe area padding
    // Icon: 24px, Spacing: 6px, Text: ~11px, Vertical padding: 8px, Bottom padding: 2px (minimal)
    // Total: ~51px + safe area bottom (~34px) = ~85px total
    private let tabBarHeight: CGFloat = 85
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background gradient for iOS 18 style
            LinearGradient(
                colors: [
                    Color(UIColor.systemBackground),
                    Color(UIColor.secondarySystemBackground).opacity(0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
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
                    DailySummaryView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                case 3:
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
            
            // Use safeRequestIfNeeded which checks statuses and only requests if needed
            // CRITICAL: This will NOT request if all types are .sharingDenied
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
        ("sparkles", "Summary"),
        ("gearshape.fill", "Settings")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 6) {
                        ZStack {
                            // Classic selected indicator - subtle and elegant
                            if selectedTab == index {
                                Circle()
                                    .fill(DesignSystem.Colors.primary.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                    .matchedGeometryEffect(id: "tab_\(index)", in: animation)
                            }
                            
                            Image(systemName: tab.icon)
                                .font(.system(size: 22, weight: selectedTab == index ? .semibold : .regular))
                                .foregroundColor(selectedTab == index ? DesignSystem.Colors.primary : DesignSystem.Colors.secondaryText)
                                .frame(width: 40, height: 40)
                                .symbolEffect(.bounce, value: selectedTab == index)
                        }
                        
                        Text(tab.title)
                            .font(.system(size: 11, weight: selectedTab == index ? .semibold : .regular))
                            .foregroundColor(selectedTab == index ? DesignSystem.Colors.primary : DesignSystem.Colors.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, 8)
        .padding(.bottom, 2) // Minimal bottom padding - let safe area handle it
        .background(
            // Glassmorphism effect - iOS 18 style
            ZStack {
                // Ultra thin material with blur
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .background(
                        // Subtle gradient overlay
                        LinearGradient(
                            colors: [
                                Color(UIColor.systemBackground).opacity(0.8),
                                Color(UIColor.systemBackground).opacity(0.6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Subtle top border for separation
                VStack {
                    Rectangle()
                        .fill(Color(UIColor.separator).opacity(0.3))
                        .frame(height: 0.5)
                    Spacer()
                }
            }
        )
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 12,
            x: 0,
            y: -3
        )
    }
}

#Preview {
    PremiumTabView()
        .environmentObject(CalendarViewModel())
        .environmentObject(SummaryViewModel())
        .environmentObject(SettingsViewModel())
}

