import SwiftUI

/// Full day view with 24-hour timeline
struct DayViewContent: View {
    @Binding var selectedDate: Date
    @Binding var viewMode: CalendarViewMode
    let events: [Event]
    let isRefreshing: Bool
    let onRefresh: () -> Void
    let onEventTap: (Event) -> Void
    let onAddEvent: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Day header with navigation and view mode switcher
            DayViewHeader(
                selectedDate: $selectedDate,
                viewMode: $viewMode
            )
            .background(DesignSystem.Colors.background)
            .padding(.top, DesignSystem.Spacing.sm)

            // 24-hour timeline - fills remaining space
            DayTimelineView(
                selectedDate: $selectedDate,
                events: events,
                onEventTap: onEventTap
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignSystem.Colors.background)
        }
        .background(DesignSystem.Colors.background)
    }
}

