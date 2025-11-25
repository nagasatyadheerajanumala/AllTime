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
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Day header with navigation and view mode switcher
                DayViewHeader(
                    selectedDate: $selectedDate,
                    viewMode: $viewMode
                )
                .background(DesignSystem.Colors.background)
                .padding(.top, DesignSystem.Spacing.sm)
                
                // 24-hour timeline
                DayTimelineView(
                    selectedDate: $selectedDate,
                    events: events,
                    onEventTap: onEventTap
                )
                .background(DesignSystem.Colors.background)
            }
            .background(DesignSystem.Colors.background)
            
            // FAB for Day view
            Button(action: onAddEvent) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.primary,
                                        DesignSystem.Colors.primaryLight
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: DesignSystem.Colors.primary.opacity(0.4), radius: 12, y: 6)
                    )
            }
            .hapticFeedback()
            .padding(.trailing, DesignSystem.Spacing.lg)
            .padding(.bottom, 100) // Above tab bar
        }
    }
}

