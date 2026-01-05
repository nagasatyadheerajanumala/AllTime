import SwiftUI
import Combine

/// Global navigation manager for controlling app-wide navigation state
/// Used primarily for deep linking and notification-triggered navigation
@MainActor
class NavigationManager: ObservableObject {
    static let shared = NavigationManager()

    /// Currently selected tab index
    @Published var selectedTab: Int = 0

    /// Show day review sheet (triggered by evening summary notification)
    @Published var showDayReview: Bool = false

    /// Pending deep link destination (used when user needs to sign in first)
    @Published var pendingDestination: String? = nil

    /// Tab enumeration for type-safe navigation
    enum Tab: Int, CaseIterable {
        case today = 0
        case calendar = 1
        case health = 2
        case reminders = 3
        case settings = 4

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
    func navigateToDayReview() {
        print("📱 NavigationManager: Navigating to Day Review")
        selectedTab = Tab.today.rawValue
        showDayReview = true
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
