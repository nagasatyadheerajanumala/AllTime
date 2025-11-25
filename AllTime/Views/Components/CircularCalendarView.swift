import SwiftUI

enum CalendarStyle {
    case traditional
    case wheel
}

// MARK: - Circular Calendar Month View
struct CircularCalendarMonthView: View {
    @Binding var selectedDate: Date
    let events: [Event]
    let onDateTap: (Date) -> Void
    
    private let calendar = Calendar.current
    
    // Calculate proper sizing based on screen width
    private var containerSize: CGFloat {
        min(UIScreen.main.bounds.width - 40, 360) // Max 360pt, with 20pt padding on each side (wider)
    }
    
    private var radius: CGFloat {
        containerSize * 0.45 // 45% of container for radius (increased for more spacing)
    }
    
    private var dayRadius: CGFloat {
        containerSize * 0.055 // 5.5% of container for day circle (kept small to prevent overlap)
    }
    
    private var daysInMonth: [Date] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }
    
    private var today: Date {
        calendar.startOfDay(for: Date())
    }
    
    // Rotation state for scrollable wheel
    @State private var rotationAngle: Double = 0
    @State private var lastDragValue: CGFloat = 0
    @State private var isDragging: Bool = false
    
    // Calculate which date should be at the top (0 degrees)
    private var selectedDateIndex: Int {
        guard let index = daysInMonth.firstIndex(where: { calendar.isDate($0, inSameDayAs: selectedDate) }) else {
            return 0
        }
        return index
    }
    
    // Calculate rotation to center selected date
    private var targetRotation: Double {
        let totalDays = Double(daysInMonth.count)
        let selectedIndex = Double(selectedDateIndex)
        // Rotate so selected date is at top (0 degrees = top)
        let baseRotation = -selectedIndex / totalDays * 2 * .pi
        return baseRotation + rotationAngle
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Circular Calendar Container with scrollable wheel
                ZStack {
                    // Glassy background effect
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: containerSize, height: containerSize)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                        .blur(radius: 10)
                    
                    // Days arranged in circle with rotation
                    ForEach(Array(daysInMonth.enumerated()), id: \.element) { index, date in
                        CircularDayView(
                            date: date,
                            dayNumber: calendar.component(.day, from: date),
                            isToday: calendar.isDate(date, inSameDayAs: today),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            hasEvents: hasEvents(for: date),
                            position: positionForDay(index: index, total: daysInMonth.count, rotation: targetRotation),
                            dayRadius: dayRadius,
                            onTap: {
                                // Animate to this date
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    selectedDate = date
                                    rotationAngle = 0
                                }
                            }
                        )
                    }
                    
                    // Center indicator (top position)
                    VStack {
                        Circle()
                            .fill(DesignSystem.Colors.primary.opacity(0.3))
                            .frame(width: dayRadius * 2 + 8, height: dayRadius * 2 + 8)
                            .overlay(
                                Circle()
                                    .stroke(DesignSystem.Colors.primary, lineWidth: 2)
                            )
                            .offset(y: -radius - dayRadius - 4)
                    }
                }
                .frame(width: containerSize, height: containerSize)
                .rotationEffect(.radians(targetRotation))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                lastDragValue = 0
                            }
                            
                            let delta = value.translation.height - lastDragValue
                            lastDragValue = value.translation.height
                            
                            // Convert vertical drag to rotation
                            let rotationDelta = -delta / radius * 0.5 // Scale factor for sensitivity
                            rotationAngle += rotationDelta
                        }
                        .onEnded { _ in
                            isDragging = false
                            lastDragValue = 0
                            
                            // Snap to nearest date
                            snapToNearestDate()
                        }
                )
                .padding(.top, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.md)
                
                // Legend
                HStack(spacing: DesignSystem.Spacing.md) {
                    LegendItem(color: Color(red: 0.2, green: 0.5, blue: 1.0), label: "Today")
                    LegendItem(color: Color(red: 1.0, green: 0.6, blue: 0.2), label: "Has Events", isOutlined: true)
                    LegendItem(color: Color(red: 1.0, green: 0.4, blue: 0.6), label: "Selected")
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)
                
                // Add Event Prompt Card
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Select a day to view or add events")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.Spacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.5, green: 0.25, blue: 0.45).opacity(0.8),
                                    Color(red: 0.6, green: 0.3, blue: 0.5).opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 15, y: 8)
                )
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, 100) // Space for navigation bar
            }
        }
    }
    
    // Snap to nearest date after drag ends
    private func snapToNearestDate() {
        let totalDays = Double(daysInMonth.count)
        let anglePerDay = 2 * .pi / totalDays
        
        // Calculate which date is closest to top (0 degrees)
        let normalizedAngle = (targetRotation.truncatingRemainder(dividingBy: 2 * .pi) + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
        let closestIndex = Int(round(-normalizedAngle / anglePerDay).truncatingRemainder(dividingBy: totalDays))
        let safeIndex = (closestIndex + daysInMonth.count) % daysInMonth.count
        
        guard safeIndex < daysInMonth.count else { return }
        
        let targetDate = daysInMonth[safeIndex]
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            selectedDate = targetDate
            rotationAngle = 0
            onDateTap(targetDate)
        }
    }
    
    private func hasEvents(for date: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return events.contains { event in
            guard let eventDate = event.startDate else { return false }
            return eventDate >= startOfDay && eventDate < endOfDay
        }
    }
    
    private func positionForDay(index: Int, total: Int, rotation: Double) -> CGPoint {
        // Calculate angle - start from top (12 o'clock)
        let baseAngle = (Double(index) / Double(total)) * 2 * .pi - .pi / 2
        let x = radius * cos(baseAngle)
        let y = radius * sin(baseAngle)
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Circular Day View
struct CircularDayView: View {
    let date: Date
    let dayNumber: Int
    let isToday: Bool
    let isSelected: Bool
    let hasEvents: Bool
    let position: CGPoint
    let dayRadius: CGFloat
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background circle
                Circle()
                    .fill(backgroundColor)
                    .frame(width: dayRadius * 2, height: dayRadius * 2)
                    .overlay(
                        Circle()
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
                    .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
                
                // Day number
                Text("\(dayNumber)")
                    .font(.system(size: fontSize, weight: isSelected || isToday ? .bold : .medium))
                    .foregroundColor(textColor)
            }
        }
        .offset(x: position.x, y: position.y)
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(DesignSystem.Animations.smooth, value: isSelected)
    }
    
    private var fontSize: CGFloat {
        // Scale font size based on circle size
        max(12, min(16, dayRadius * 0.5))
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color(red: 1.0, green: 0.4, blue: 0.6) // Pink-red for selected
        } else if isToday {
            return Color(red: 0.2, green: 0.5, blue: 1.0) // Blue for today
        } else {
            return Color(red: 0.6, green: 0.4, blue: 0.8).opacity(0.3) // Light purple for normal days
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return Color(red: 1.0, green: 0.4, blue: 0.6) // Pink-red border
        } else if hasEvents {
            return Color(red: 1.0, green: 0.6, blue: 0.2) // Orange border
        } else {
            return .clear
        }
    }
    
    private var borderWidth: CGFloat {
        if isSelected {
            return 2.5
        } else if hasEvents {
            return 2
        } else {
            return 0
        }
    }
    
    private var textColor: Color {
        if isSelected || isToday {
            return .white
        } else {
            return .white.opacity(0.95) // White text for better contrast
        }
    }
    
    private var shadowColor: Color {
        if isSelected {
            return Color(red: 1.0, green: 0.4, blue: 0.6).opacity(0.5)
        } else if isToday {
            return Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.4)
        } else {
            return .black.opacity(0.2)
        }
    }
    
    private var shadowRadius: CGFloat {
        isSelected ? 8 : 4
    }
    
    private var shadowY: CGFloat {
        isSelected ? 3 : 2
    }
}

// MARK: - Circular Calendar Week View
struct CircularCalendarWeekView: View {
    @Binding var selectedDate: Date
    let events: [Event]
    let onDateTap: (Date) -> Void
    
    private let calendar = Calendar.current
    
    // Calculate proper sizing based on screen width
    private var containerSize: CGFloat {
        min(UIScreen.main.bounds.width - 40, 360) // Max 360pt, with 20pt padding on each side (wider)
    }
    
    private var radius: CGFloat {
        containerSize * 0.48 // 48% of container for radius (increased for more spacing)
    }
    
    private var dayRadius: CGFloat {
        containerSize * 0.085 // 8.5% of container for day circle (kept small to prevent overlap)
    }
    
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
    
    private var today: Date {
        calendar.startOfDay(for: Date())
    }
    
    // Rotation state for scrollable wheel
    @State private var rotationAngle: Double = 0
    @State private var lastDragValue: CGFloat = 0
    @State private var isDragging: Bool = false
    
    // Calculate which date should be at the top (0 degrees)
    private var selectedDateIndex: Int {
        guard let index = weekDays.firstIndex(where: { calendar.isDate($0, inSameDayAs: selectedDate) }) else {
            return 0
        }
        return index
    }
    
    // Calculate rotation to center selected date
    private var targetRotation: Double {
        let totalDays = Double(weekDays.count)
        let selectedIndex = Double(selectedDateIndex)
        // Rotate so selected date is at top (0 degrees = top)
        let baseRotation = -selectedIndex / totalDays * 2 * .pi
        return baseRotation + rotationAngle
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Circular Week Calendar Container with scrollable wheel
                ZStack {
                    // Glassy background effect
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: containerSize, height: containerSize)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                        .blur(radius: 10)
                    
                    ForEach(Array(weekDays.enumerated()), id: \.element) { index, date in
                        CircularWeekDayView(
                            date: date,
                            dayName: dayName(for: date),
                            dayNumber: calendar.component(.day, from: date),
                            isToday: calendar.isDate(date, inSameDayAs: today),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            hasEvents: hasEvents(for: date),
                            position: positionForDay(index: index, total: weekDays.count, rotation: targetRotation),
                            dayRadius: dayRadius,
                            onTap: {
                                // Animate to this date
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    selectedDate = date
                                    rotationAngle = 0
                                }
                            }
                        )
                    }
                    
                    // Center indicator (top position)
                    VStack {
                        Circle()
                            .fill(DesignSystem.Colors.primary.opacity(0.3))
                            .frame(width: dayRadius * 2 + 8, height: dayRadius * 2 + 8)
                            .overlay(
                                Circle()
                                    .stroke(DesignSystem.Colors.primary, lineWidth: 2)
                            )
                            .offset(y: -radius - dayRadius - 4)
                    }
                }
                .frame(width: containerSize, height: containerSize)
                .rotationEffect(.radians(targetRotation))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                lastDragValue = 0
                            }
                            
                            let delta = value.translation.height - lastDragValue
                            lastDragValue = value.translation.height
                            
                            // Convert vertical drag to rotation
                            let rotationDelta = -delta / radius * 0.5 // Scale factor for sensitivity
                            rotationAngle += rotationDelta
                        }
                        .onEnded { _ in
                            isDragging = false
                            lastDragValue = 0
                            
                            // Snap to nearest date
                            snapToNearestDate()
                        }
                )
                .padding(.top, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.md)
                
                // Legend
                HStack(spacing: DesignSystem.Spacing.md) {
                    LegendItem(color: Color(red: 0.2, green: 0.5, blue: 1.0), label: "Today")
                    LegendItem(color: Color(red: 1.0, green: 0.6, blue: 0.2), label: "Has Events", isOutlined: true)
                    LegendItem(color: Color(red: 1.0, green: 0.4, blue: 0.6), label: "Selected")
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)
                
                // Add Event Prompt Card
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Select a day to view or add events")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.Spacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.5, green: 0.25, blue: 0.45).opacity(0.8),
                                    Color(red: 0.6, green: 0.3, blue: 0.5).opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 15, y: 8)
                )
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, 100) // Space for navigation bar
            }
        }
    }
    
    // Snap to nearest date after drag ends
    private func snapToNearestDate() {
        let totalDays = Double(weekDays.count)
        let anglePerDay = 2 * .pi / totalDays
        
        // Calculate which date is closest to top (0 degrees)
        let normalizedAngle = (targetRotation.truncatingRemainder(dividingBy: 2 * .pi) + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
        let closestIndex = Int(round(-normalizedAngle / anglePerDay).truncatingRemainder(dividingBy: totalDays))
        let safeIndex = (closestIndex + weekDays.count) % weekDays.count
        
        guard safeIndex < weekDays.count else { return }
        
        let targetDate = weekDays[safeIndex]
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            selectedDate = targetDate
            rotationAngle = 0
            onDateTap(targetDate)
        }
    }
    
    private func dayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private func hasEvents(for date: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return events.contains { event in
            guard let eventDate = event.startDate else { return false }
            return eventDate >= startOfDay && eventDate < endOfDay
        }
    }
    
    private func positionForDay(index: Int, total: Int, rotation: Double) -> CGPoint {
        let angle = (Double(index) / Double(total)) * 2 * .pi - .pi / 2
        let x = radius * cos(angle)
        let y = radius * sin(angle)
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Circular Week Day View
struct CircularWeekDayView: View {
    let date: Date
    let dayName: String
    let dayNumber: Int
    let isToday: Bool
    let isSelected: Bool
    let hasEvents: Bool
    let position: CGPoint
    let dayRadius: CGFloat
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(dayName)
                    .font(.system(size: max(9, min(12, dayRadius * 0.25)), weight: .medium))
                    .foregroundColor(textColor.opacity(0.9))
                
                Text("\(dayNumber)")
                    .font(.system(size: max(14, min(18, dayRadius * 0.5)), weight: isSelected || isToday ? .bold : .semibold))
                    .foregroundColor(textColor)
            }
            .frame(width: dayRadius * 2, height: dayRadius * 2)
            .background(
                Circle()
                    .fill(backgroundColor)
                    .overlay(
                        Circle()
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
            )
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
        }
        .offset(x: position.x, y: position.y)
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(DesignSystem.Animations.smooth, value: isSelected)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color(red: 1.0, green: 0.4, blue: 0.6)
        } else if isToday {
            return Color(red: 0.2, green: 0.5, blue: 1.0)
        } else {
            return Color(red: 0.6, green: 0.4, blue: 0.8).opacity(0.3)
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return Color(red: 1.0, green: 0.4, blue: 0.6)
        } else if hasEvents {
            return Color(red: 1.0, green: 0.6, blue: 0.2)
        } else {
            return .clear
        }
    }
    
    private var borderWidth: CGFloat {
        if isSelected {
            return 2.5
        } else if hasEvents {
            return 2
        } else {
            return 0
        }
    }
    
    private var textColor: Color {
        if isSelected || isToday {
            return .white
        } else {
            return .white.opacity(0.95)
        }
    }
    
    private var shadowColor: Color {
        if isSelected {
            return Color(red: 1.0, green: 0.4, blue: 0.6).opacity(0.5)
        } else if isToday {
            return Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.4)
        } else {
            return .black.opacity(0.2)
        }
    }
    
    private var shadowRadius: CGFloat {
        isSelected ? 8 : 4
    }
    
    private var shadowY: CGFloat {
        isSelected ? 3 : 2
    }
}

// MARK: - Legend Item
struct LegendItem: View {
    let color: Color
    let label: String
    var isOutlined: Bool = false
    
    var body: some View {
        HStack(spacing: 6) {
            if isOutlined {
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: 14, height: 14)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
            }
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.95))
        }
    }
}
