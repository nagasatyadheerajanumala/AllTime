import SwiftUI

/// Ultra-smooth circular date wheel with CALayer rendering (Apple-grade, 120fps)
struct CircularDateWheelView: View {
    @Binding var selectedDate: Date
    let events: [Event]
    let onDateSelected: (Date) -> Void
    
    @StateObject private var viewModel = CircularWheelViewModel()
    
    private let calendar = Calendar.current
    private let containerSize: CGFloat = min(UIScreen.main.bounds.width - 40, 360)
    private let radius: CGFloat = 140
    private let dateBubbleSize: CGFloat = 50
    private let centerCapsuleSize: CGFloat = 110
    
    private var daysInMonth: [Date] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                // Liquid glass background (static, never changes)
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
                    .id("bubble-\(index)")
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
                
                // Invisible touch area with drag gesture (handles both tap and drag)
                Circle()
                    .fill(Color.clear)
                    .frame(width: containerSize, height: containerSize)
                    .contentShape(Circle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                // Apple-grade: No animation during drag - instant updates
                                var transaction = Transaction(animation: nil)
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    if let newDate = viewModel.updateFromDrag(value: value, center: center) {
                                        selectedDate = newDate
                                    }
                                }
                            }
                            .onEnded { value in
                                // Check if this was a tap (minimal movement)
                                let translation = value.translation
                                let dragDistance = sqrt(translation.width * translation.width + translation.height * translation.height)
                                
                                if dragDistance < 5 {
                                    // This was a tap - use tap handler for precise selection
                                    if let tappedDate = viewModel.handleTap(at: value.location, center: center) {
                                        selectedDate = tappedDate
                                        Task { @MainActor in
                                            onDateSelected(tappedDate)
                                        }
                                    }
                                } else {
                                    // This was a drag - use drag handler
                                    if let finalDate = viewModel.finishDrag(value: value, center: center) {
                                        selectedDate = finalDate
                                        // Smooth spring animation for final snap
                                        withAnimation(.interpolatingSpring(stiffness: 120, damping: 12)) {
                                            // Animation handled by viewModel
                                        }
                                        
                                        // Load day details
                                        Task { @MainActor in
                                            onDateSelected(finalDate)
                                        }
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
            viewModel.setupDays(daysInMonth, events: events)
            viewModel.centerDate = selectedDate
        }
        .onChange(of: daysInMonth) { oldDays, newDays in
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

// MARK: - Static Background (never changes)
struct WheelBackground: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.clear,
                            Color.purple.opacity(0.08)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
        }
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.purple.opacity(0.2),
                            Color.blue.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 8)
        .transaction { $0.animation = nil }
    }
}

// MARK: - Optimized Date Bubble (minimal SwiftUI)
struct OptimizedDateBubble: View {
    let dayNumber: Int
    let isToday: Bool
    let isHighlighted: Bool
    let isSelected: Bool
    let hasEvents: Bool
    let position: CGPoint
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Liquid glass bubble
            ZStack {
                Circle()
                    .fill(
                        isHighlighted
                            ? AnyShapeStyle(.ultraThinMaterial)
                            : AnyShapeStyle(.ultraThinMaterial.opacity(0.8))
                    )
                
                if isHighlighted {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.purple.opacity(0.15)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: size / 2
                            )
                        )
                }
            }
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(
                        isHighlighted
                            ? LinearGradient(
                                colors: [
                                    Color.white.opacity(0.7),
                                    Color.white.opacity(0.4),
                                    Color.purple.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: isHighlighted ? 2.5 : 1
                    )
            )
            .shadow(
                color: isHighlighted
                    ? Color.purple.opacity(0.6)
                    : Color.black.opacity(0.1),
                radius: isHighlighted ? 16 : 4,
                x: 0,
                y: isHighlighted ? 6 : 2
            )
            
            // Day number
            Text("\(dayNumber)")
                .font(.system(size: size * 0.42, weight: isHighlighted || isSelected ? .bold : .semibold))
                .foregroundColor(isHighlighted || isSelected ? .white : .white.opacity(0.9))
                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
        }
        .offset(x: position.x, y: position.y)
        .scaleEffect(isHighlighted ? 1.2 : (isSelected ? 1.08 : 1.0))
        .transaction { $0.animation = nil }
        .animation(nil, value: isHighlighted)
    }
}

// MARK: - Center Highlight Capsule
struct CenterHighlightCapsule: View {
    let date: Date
    let dayNumber: Int
    let isToday: Bool
    let hasEvents: Bool
    let size: CGFloat
    
    private var dayNameFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }
    
    private var dayName: String {
        dayNameFormatter.string(from: date)
    }
    
    var body: some View {
        ZStack {
            // Clean capsule background
            RoundedRectangle(cornerRadius: size / 2)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.6),
                            Color.blue.opacity(0.5),
                            Color.purple.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size * 0.65)
                .overlay(
                    RoundedRectangle(cornerRadius: size / 2)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.8),
                                    Color.white.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color.purple.opacity(0.6), radius: 20, x: 0, y: 8)
                .shadow(color: Color.blue.opacity(0.4), radius: 12, x: 0, y: 4)
            
            // Date display
            VStack(spacing: 4) {
                Text(dayName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                Text("\(dayNumber)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
                
                if hasEvents {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange.opacity(0.95))
                            .frame(width: 6, height: 6)
                            .shadow(color: Color.orange.opacity(0.6), radius: 3)
                        Circle()
                            .fill(Color.orange.opacity(0.95))
                            .frame(width: 6, height: 6)
                            .shadow(color: Color.orange.opacity(0.6), radius: 3)
                    }
                }
            }
        }
        .transaction { $0.animation = nil }
    }
}

// MARK: - Today Button
struct TodayButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 14, weight: .semibold))
                Text("Today")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.8),
                                Color.purple.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.blue.opacity(0.4), radius: 12, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Event Indicator Dot
struct EventIndicatorDot: View {
    let position: CGPoint
    let radius: CGFloat
    
    var body: some View {
        Circle()
            .fill(Color.orange.opacity(0.9))
            .frame(width: 8, height: 8)
            .offset(
                x: position.x * 1.12,
                y: position.y * 1.12
            )
            .shadow(color: Color.orange.opacity(0.7), radius: 5, x: 0, y: 2)
            .transaction { $0.animation = nil }
    }
}
