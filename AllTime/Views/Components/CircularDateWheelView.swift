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
    private let dateBubbleSize: CGFloat = 56  // Increased to fit day + date + event count
    private let centerCapsuleSize: CGFloat = 110

    // Day abbreviation formatter
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"  // Mon, Tue, Wed, etc.
        return formatter
    }
    
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
                        date: date,
                        dayNumber: calendar.component(.day, from: date),
                        dayAbbreviation: dayFormatter.string(from: date),
                        isToday: calendar.isDate(date, inSameDayAs: Date()),
                        isHighlighted: index == viewModel.highlightedIndex,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        eventCount: viewModel.eventCount(at: index),
                        severityLevel: viewModel.severityLevel(at: index),
                        isProblemDay: viewModel.isProblemDay(at: index),
                        position: viewModel.position(at: index),
                        size: dateBubbleSize
                    )
                    .id("bubble-\(index)")
                    .transaction { $0.animation = nil }
                    .animation(nil, value: viewModel.highlightedIndex)
                }
                
                // Center highlight capsule (only this updates during drag)
                // Tap handling is done in the gesture handler below
                CenterHighlightCapsule(
                    date: viewModel.centerDate,
                    dayNumber: calendar.component(.day, from: viewModel.centerDate),
                    isToday: calendar.isDate(viewModel.centerDate, inSameDayAs: Date()),
                    eventCount: viewModel.eventCount(at: viewModel.highlightedIndex),
                    severityLevel: viewModel.severityLevel(at: viewModel.highlightedIndex),
                    daySummary: viewModel.severity(at: viewModel.highlightedIndex)?.summary,
                    isProblemDay: viewModel.isProblemDay(at: viewModel.highlightedIndex),
                    problemDayLabel: viewModel.problemDay?.label,
                    size: centerCapsuleSize
                )
                .transaction { $0.animation = nil }
                .animation(nil, value: viewModel.highlightedIndex)
                
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
                                    // This was a tap - check if it's on the center capsule
                                    let tapLocation = value.location
                                    let distanceFromCenter = sqrt(
                                        pow(tapLocation.x - center.x, 2) +
                                        pow(tapLocation.y - center.y, 2)
                                    )

                                    // Center capsule is roughly 110pt wide, so check if tap is within ~60pt of center
                                    if distanceFromCenter < 60 {
                                        // Tapped on center capsule - show day details for current date
                                        HapticManager.shared.selectionChanged()
                                        Task { @MainActor in
                                            onDateSelected(viewModel.centerDate)
                                        }
                                    } else if let tappedDate = viewModel.handleTap(at: tapLocation, center: center) {
                                        // Tapped on a date bubble
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
        .task {
            // Load day severity data in background
            await viewModel.loadSeverityData()
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

// MARK: - Static Background (clean glass effect)
struct WheelBackground: View {
    var body: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 16, y: 6)
            .transaction { $0.animation = nil }
    }
}

// MARK: - Optimized Date Bubble (Clean - only busy days highlighted)
struct OptimizedDateBubble: View {
    let date: Date
    let dayNumber: Int
    let dayAbbreviation: String
    let isToday: Bool
    let isHighlighted: Bool
    let isSelected: Bool
    let eventCount: Int
    let severityLevel: SeverityLevel
    let isProblemDay: Bool
    let position: CGPoint
    let size: CGFloat

    /// Only highlight truly busy days (5+ events) or problem days
    private var isBusyDay: Bool {
        isProblemDay || eventCount >= 5
    }

    /// Tint color - only for busy/problem days
    private var tintColor: Color {
        if isProblemDay { return Color.red }
        if eventCount >= 7 { return Color.orange }
        if eventCount >= 5 { return Color(red: 0.95, green: 0.6, blue: 0.2) } // Amber
        return .clear
    }

    /// Ring color
    private var ringColor: Color {
        if isHighlighted { return .white.opacity(0.8) }
        if isProblemDay { return .red.opacity(0.5) }
        if eventCount >= 5 { return tintColor.opacity(0.4) }
        return .white.opacity(0.2)
    }

    var body: some View {
        ZStack {
            // Glass base
            Circle()
                .fill(.ultraThinMaterial.opacity(0.6))
                .frame(width: size, height: size)

            // Color tint - ONLY for busy days
            if isBusyDay {
                Circle()
                    .fill(tintColor.opacity(0.35))
                    .frame(width: size, height: size)
            }

            // Ring
            Circle()
                .stroke(ringColor, lineWidth: isHighlighted ? 2 : 1)
                .frame(width: size, height: size)

            // Content
            VStack(spacing: 2) {
                Text(dayAbbreviation)
                    .font(.system(size: size * 0.17, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))

                Text("\(dayNumber)")
                    .font(.system(size: size * 0.38, weight: isHighlighted ? .bold : .semibold, design: .rounded))
                    .foregroundColor(.white)

                // Event indicator
                if isBusyDay {
                    Text("\(eventCount)")
                        .font(.system(size: size * 0.18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                } else if eventCount > 0 {
                    Circle()
                        .fill(.white.opacity(0.5))
                        .frame(width: 4, height: 4)
                } else {
                    Color.clear.frame(height: size * 0.18)
                }
            }
        }
        .compositingGroup()  // Faster than drawingGroup, works with materials
        .offset(x: position.x, y: position.y)
        .scaleEffect(isHighlighted ? 1.12 : 1.0)
    }
}

// MARK: - Center Highlight Capsule (Premium glass design)
struct CenterHighlightCapsule: View {
    let date: Date
    let dayNumber: Int
    let isToday: Bool
    let eventCount: Int
    let severityLevel: SeverityLevel
    let daySummary: String?
    let isProblemDay: Bool
    let problemDayLabel: String?
    let size: CGFloat

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    /// Subtle severity indicator color
    private var indicatorColor: Color {
        if isProblemDay || severityLevel == .overloaded { return Color(red: 0.95, green: 0.3, blue: 0.3) }
        if severityLevel == .heavy { return Color(red: 1.0, green: 0.6, blue: 0.3) }
        if severityLevel == .moderate { return Color(red: 0.3, green: 0.7, blue: 0.9) }
        return Color(red: 0.4, green: 0.8, blue: 0.5)
    }

    /// Status text for busy days (kept short)
    private var statusText: String? {
        if isProblemDay || problemDayLabel != nil { return "Overloaded" }
        if eventCount >= 7 { return "Very busy" }
        if eventCount >= 5 { return "Busy" }
        return nil
    }

    // Cached gradient for performance
    private static let topEdgeGradient = LinearGradient(
        colors: [Color.white.opacity(0.35), Color.white.opacity(0.1), Color.clear],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ZStack {
            // Premium frosted glass (single layer, no shadow for perf)
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .frame(width: size, height: size)

            // Subtle inner highlight (cached gradient)
            RoundedRectangle(cornerRadius: 24)
                .stroke(Self.topEdgeGradient, lineWidth: 1)
                .frame(width: size, height: size)

            // Content - constrained to box
            VStack(spacing: 5) {
                // Day name
                Text(dayName)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))

                // Day number (large, elegant)
                Text("\(dayNumber)")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Event info
                if eventCount > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(indicatorColor)
                            .frame(width: 5, height: 5)
                        Text("\(eventCount) event\(eventCount == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                    }

                    // Status for busy/problem days
                    if let status = statusText {
                        Text(status)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundColor(indicatorColor.opacity(0.9))
                            .lineLimit(1)
                    }
                } else {
                    Text("No events")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .frame(width: size - 16) // Constrain content width
        }
        .transaction { $0.animation = nil }
    }
}

// MARK: - Today Button (Clean, minimal)
struct TodayButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Today")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

