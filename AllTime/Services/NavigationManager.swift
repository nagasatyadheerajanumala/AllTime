import SwiftUI
import Combine

/// Global navigation manager for controlling app-wide navigation state
/// Used primarily for deep linking and notification-triggered navigation
@MainActor
class NavigationManager: ObservableObject {
    static let shared = NavigationManager()

    /// Currently selected tab index
    @Published var selectedTab: Int = 0

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
}
