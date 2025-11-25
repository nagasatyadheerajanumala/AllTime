import SwiftUI

/// Ultra-smooth circular week wheel with CALayer rendering (Apple-grade, 120fps)
struct CircularWeekWheelView: View {
    @Binding var selectedDate: Date
    let events: [Event]
    let onDateSelected: (Date) -> Void
    
    @StateObject private var viewModel = CircularWheelViewModel()
    
    private let calendar = Calendar.current
    private let containerSize: CGFloat = min(UIScreen.main.bounds.width - 40, 360)
    private let radius: CGFloat = 140
    private let dateBubbleSize: CGFloat = 50
    private let centerCapsuleSize: CGFloat = 110
    
    private var weekDays: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return []
        }
        var days: [Date] = []
        var currentDate = weekInterval.start
        while currentDate < weekInterval.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        return days
    }
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                // Liquid glass background (static)
                WheelBackground()
                    .frame(width: containerSize, height: containerSize)
                
                // Static date bubbles (NEVER move) - only highlighted one updates
                ForEach(Array(viewModel.days.enumerated()), id: \.element) { index, date in
                    OptimizedDateBubble(
                        dayNumber: calendar.component(.day, from: date),
                        isToday: calendar.isDate(date, inSameDayAs: Date()),
                        isHighlighted: index == viewModel.highlightedIndex,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        hasEvents: viewModel.hasEvents(at: index),
                        position: viewModel.position(at: index),
                        size: dateBubbleSize
                    )
                    .id("week-bubble-\(index)")
                    .transaction { $0.animation = nil }
                    .animation(nil, value: viewModel.highlightedIndex)
                }
                
                // Center highlight capsule (only this updates during drag)
                CenterHighlightCapsule(
                    date: viewModel.centerDate,
                    dayNumber: calendar.component(.day, from: viewModel.centerDate),
                    isToday: calendar.isDate(viewModel.centerDate, inSameDayAs: Date()),
                    hasEvents: viewModel.hasEvents(at: viewModel.highlightedIndex),
                    size: centerCapsuleSize
                )
                .transaction { $0.animation = nil }
                .animation(nil, value: viewModel.highlightedIndex)
                
                // Event indicator dots (static, precomputed)
                ForEach(Array(viewModel.days.enumerated()), id: \.element) { index, date in
                    if viewModel.hasEvents(at: index) && index != viewModel.highlightedIndex {
                        EventIndicatorDot(
                            position: viewModel.position(at: index),
                            radius: radius
                        )
                    }
                }
                
                // "Today" button
                VStack {
                    HStack {
                        Spacer()
                        TodayButton {
                            jumpToToday()
                        }
                        .padding(.top, 8)
                        .padding(.trailing, 8)
                    }
                    Spacer()
                }
                
                // Invisible touch area
                Circle()
                    .fill(Color.clear)
                    .frame(width: containerSize, height: containerSize)
                    .contentShape(Circle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                // Apple-grade: No animation during drag
                                var transaction = Transaction(animation: nil)
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    if let newDate = viewModel.updateFromDrag(value: value, center: center) {
                                        selectedDate = newDate
                                    }
                                }
                            }
                            .onEnded { value in
                                if let finalDate = viewModel.finishDrag(value: value, center: center) {
                                    selectedDate = finalDate
                                    // Animate only on release
                                    withAnimation(.interpolatingSpring(stiffness: 120, damping: 12)) {
                                        // Spring animation for final snap
                                    }
                                    
                                    // Load day details
                                    Task { @MainActor in
                                        onDateSelected(finalDate)
                                    }
                                }
                            }
                    )
            }
            .frame(width: containerSize, height: containerSize)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .frame(width: containerSize, height: containerSize)
        .onAppear {
            viewModel.setupDays(weekDays, events: events)
            viewModel.centerDate = selectedDate
        }
        .onChange(of: weekDays) { oldDays, newDays in
            viewModel.setupDays(newDays, events: events)
        }
        .onChange(of: events.count) { oldCount, newCount in
            viewModel.setupDays(viewModel.days, events: events)
        }
        .onChange(of: selectedDate) { oldDate, newDate in
            if !viewModel.isDragging {
                viewModel.centerDate = newDate
            }
        }
    }
    
    private func jumpToToday() {
        let today = Date()
        guard let todayIndex = viewModel.days.firstIndex(where: { calendar.isDate($0, inSameDayAs: today) }) else {
            selectedDate = today
            return
        }
        
        withAnimation(.interpolatingSpring(stiffness: 120, damping: 12)) {
            viewModel.highlightedIndex = todayIndex
            viewModel.centerDate = today
            selectedDate = today
        }
        
        Task { @MainActor in
            onDateSelected(today)
        }
    }
}
