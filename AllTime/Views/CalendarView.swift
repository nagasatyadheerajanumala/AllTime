import SwiftUI

enum CalendarViewMode {
    case month, week, day
}

struct CalendarView: View {
    @EnvironmentObject var calendarViewModel: CalendarViewModel
    @State private var showingEventDetail = false
    @State private var selectedEventId: Int64?
    @State private var viewMode: CalendarViewMode = .month
    @State private var calendarStyle: CalendarStyle = .traditional
    @State private var showingAddEvent = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background - gradient for wheel, normal for traditional
                if calendarStyle == .wheel {
                    LinearGradient(
                        colors: [
                            Color(red: 0.35, green: 0.15, blue: 0.55), // Deep purple
                            Color(red: 0.55, green: 0.25, blue: 0.45)  // Magenta-purple
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                } else {
                    DesignSystem.Colors.background
                        .ignoresSafeArea()
                }
                
                if viewMode == .day {
                    // 24-hour timeline view
                    ZStack {
                        // Background
                        DesignSystem.Colors.background
                            .ignoresSafeArea()
                        
                        DayViewContent(
                            selectedDate: $calendarViewModel.selectedDate,
                            viewMode: $viewMode,
                            events: calendarViewModel.eventsForDate(calendarViewModel.selectedDate),
                            isRefreshing: calendarViewModel.isRefreshing,
                            onRefresh: {
                                Task {
                                    await calendarViewModel.refreshEvents()
                                }
                            },
                            onEventTap: { event in
                                selectedEventId = Int64(event.id)
                                showingEventDetail = true
                            },
                            onAddEvent: {
                                showingAddEvent = true
                            }
                        )
                    }
                } else {
                    // Month/Week view
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            // Premium Calendar Header with Month/Year and Week Strip
                            PremiumCalendarHeader(
                                selectedDate: $calendarViewModel.selectedDate,
                                viewMode: $viewMode,
                                calendarStyle: $calendarStyle,
                                isRefreshing: calendarViewModel.isRefreshing,
                                onRefresh: {
                                    Task {
                                        await calendarViewModel.refreshEvents()
                                    }
                                }
                            )
                            
                            // Calendar View (Traditional or Wheel)
                            if calendarStyle == .wheel {
                                if viewMode == .month {
                                    // Interactive Month Wheel View
                                    CircularDateWheelView(
                                        selectedDate: $calendarViewModel.selectedDate,
                                        events: calendarViewModel.events,
                                        onDateSelected: { date in
                                            // Load events asynchronously without blocking UI
                                            Task { @MainActor in
                                                await calendarViewModel.loadEventsForSelectedDate(date)
                                            }
                                        }
                                    )
                                    .frame(height: 400)
                                    .padding(.horizontal, DesignSystem.Spacing.md)
                                } else if viewMode == .week {
                                    // Interactive Week Wheel View
                                    CircularWeekWheelView(
                                        selectedDate: $calendarViewModel.selectedDate,
                                        events: calendarViewModel.events,
                                        onDateSelected: { date in
                                            // Load events asynchronously without blocking UI
                                            Task { @MainActor in
                                                await calendarViewModel.loadEventsForSelectedDate(date)
                                            }
                                        }
                                    )
                                    .frame(height: 400)
                                    .padding(.horizontal, DesignSystem.Spacing.md)
                                } else {
                                    // Day view - use traditional grid
                                    PremiumCalendarGrid(
                                        selectedDate: $calendarViewModel.selectedDate,
                                        events: calendarViewModel.events,
                                        viewMode: viewMode
                                    )
                                    .padding(.horizontal, DesignSystem.Spacing.md)
                                }
                            } else {
                                // Traditional Calendar Grid
                                PremiumCalendarGrid(
                                    selectedDate: $calendarViewModel.selectedDate,
                                    events: calendarViewModel.events,
                                    viewMode: viewMode
                                )
                                .padding(.horizontal, DesignSystem.Spacing.md)
                            }
                            
                            // Events for Selected Date
                            PremiumEventsSection(
                                headerText: formattedSelectedDate,
                                events: calendarViewModel.eventsForDate(calendarViewModel.selectedDate),
                                onEventTap: { event in
                                    selectedEventId = Int64(event.id)
                                    showingEventDetail = true
                                }
                            )
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.bottom, 100) // Space for FAB + tab bar
                        }
                    }
                    .refreshable {
                        await calendarViewModel.refreshEvents()
                    }
                }
                
                // Single Floating Action Button - only show for month/week views
                if viewMode != .day {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                showingAddEvent = true
                            }) {
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
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingEventDetail) {
                if let eventId = selectedEventId {
                    EventDetailView(eventId: eventId)
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(initialDate: calendarViewModel.selectedDate)
                    .onDisappear {
                        Task {
                            await calendarViewModel.refreshEvents()
                        }
                    }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EventCreated"))) { _ in
                Task {
                    await calendarViewModel.refreshEvents()
                }
            }
            .onAppear {
                Task {
                    if !calendarViewModel.isLoading {
                        await calendarViewModel.refreshEvents()
                    }
                }
            }
            .onChange(of: calendarViewModel.selectedDate) { oldDate, newDate in
                Task {
                    await calendarViewModel.loadEventsForSelectedDate(newDate)
                }
            }
        }
    }
    
    private var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: calendarViewModel.selectedDate)
    }
}
