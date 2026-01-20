import SwiftUI
import Combine

/// Global navigation manager for controlling app-wide navigation state
/// Used primarily for deep linking and notification-triggered navigation
@MainActor
class NavigationManager: ObservableObject {
    static let shared = NavigationManager()

    /// Currently selected tab index
    @Published var selectedTab: Int = 0

    /// Show day review sheet (triggered by evening summary notification) - DEPRECATED, use navigateToDailyInsights instead
    @Published var showDayReview: Bool = false

    /// Selected section within Insights tab (for deep linking to Daily/Weekly/Monthly/Health)
    @Published var insightsSection: String? = nil

    /// Pending deep link destination (used when user needs to sign in first)
    @Published var pendingDestination: String? = nil

    /// Tab enumeration for type-safe navigation
    enum Tab: Int, CaseIterable {
        case today = 0
        case insights = 1
        case calendar = 2
        case health = 3
        case reminders = 4
        case settings = 5

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
    }

    private init() {}

    // MARK: - Navigation Methods

    /// Navigate to Today tab
    func navigateToToday() {
        selectedTab = Tab.today.rawValue
    }

    /// Navigate to Calendar tab
    func navigateToCalendar() {
        selectedTab = Tab.calendar.rawValue
    }

    /// Navigate to Health tab
    func navigateToHealth() {
        selectedTab = Tab.health.rawValue
    }

    /// Navigate to Reminders tab
    func navigateToReminders() {
        selectedTab = Tab.reminders.rawValue
    }

    /// Navigate to Settings tab
    func navigateToSettings() {
        selectedTab = Tab.settings.rawValue
    }

    /// Navigate to Insights tab
    func navigateToInsights() {
        selectedTab = Tab.insights.rawValue
    }

    /// Navigate to Daily Insights (Insights tab → Daily section)
    /// Used by evening summary notifications
    func navigateToDailyInsights() {
        print("📱 NavigationManager: Navigating to Daily Insights")
        insightsSection = "daily"
        selectedTab = Tab.insights.rawValue
        // Post notification so InsightsRootView can switch to Daily section
        NotificationCenter.default.post(name: .navigateToDailyInsights, object: nil)
    }

    /// Navigate to a specific tab
    func navigate(to tab: Tab) {
        selectedTab = tab.rawValue
    }

    /// Navigate to tab by raw value (for notification handling)
    func navigate(toTabIndex index: Int) {
        guard index >= 0 && index < Tab.allCases.count else { return }
        selectedTab = index
    }

    /// Navigate to day review (from evening summary notification)
    /// Shows the DailyInsightsView as a sheet
    func navigateToDayReview() {
        print("📱 NavigationManager: Navigating to Day Review")
        // Post notification that MainTabView listens to for showing the day review sheet
        NotificationCenter.default.post(name: .navigateToDayReview, object: nil)
    }

    /// Handle a destination string (from notification deep link)
    func handleDestination(_ destination: String) {
        print("📱 NavigationManager: Handling destination: \(destination)")
        switch destination {
        case "day-review":
            navigateToDayReview()
        case "today":
            navigateToToday()
        case "calendar":
            navigateToCalendar()
        case "health":
            navigateToHealth()
        case "reminders":
            navigateToReminders()
        case "settings":
            navigateToSettings()
        default:
            print("📱 NavigationManager: Unknown destination: \(destination)")
        }
    }

    /// Store a pending destination for after authentication
    func setPendingDestination(_ destination: String) {
        print("📱 NavigationManager: Storing pending destination: \(destination)")
        pendingDestination = destination
    }

    /// Process pending destination after successful authentication
    func processPendingDestination() {
        guard let destination = pendingDestination else { return }
        print("📱 NavigationManager: Processing pending destination: \(destination)")
        pendingDestination = nil

        // Small delay to ensure UI is ready
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            handleDestination(destination)
        }
    }
}
