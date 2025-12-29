import SwiftUI

/// 24-hour timeline view - Apple Calendar style with unified coordinate system
///
/// LAYOUT ARCHITECTURE (Single Source of Truth):
/// All vertical positioning uses the SAME formula:
///   yPosition = minutesSinceMidnight * pxPerMinute
///
/// This ensures hour labels, grid lines, events, and current-time indicator
/// are ALL perfectly aligned using ONE coordinate system.
struct DayTimelineView: View {
    @Binding var selectedDate: Date
    let events: [Event]
    let onEventTap: (Event) -> Void

    private let calendar = Calendar.current

    // MARK: - Layout Constants (SINGLE SOURCE OF TRUTH)
    // These values MUST be used consistently across ALL positioning calculations

    /// Points per minute - the fundamental unit for all vertical positioning
    private let pxPerMinute: CGFloat = 1.0

    /// Derived: points per hour = 60 minutes * 1 px/minute = 60 points
    private var hourHeight: CGFloat { 60.0 * pxPerMinute }

    /// Total timeline height = 24 hours * 60 points = 1440 points
    private var totalTimelineHeight: CGFloat { 24.0 * hourHeight }

    /// Width of the time label column on the left
    private let timeColumnWidth: CGFloat = 56

    /// Gap between time column and event area
    private let timeColumnGap: CGFloat = 8

    /// Start X position for events (after time labels)
    private var eventAreaStartX: CGFloat { timeColumnWidth + timeColumnGap }

    /// Right margin for events
    private let eventAreaEndMargin: CGFloat = 8

    // MARK: - Unified Positioning Function
    // This is the ONLY function that should calculate Y positions

    /// Calculate Y position for any time. This formula is used by:
    /// - Hour labels
    /// - Grid lines
    /// - Event blocks
    /// - Current time indicator
    private func yPosition(forHour hour: Int, minute: Int = 0) -> CGFloat {
        let totalMinutes = CGFloat(hour * 60 + minute)
        return totalMinutes * pxPerMinute
    }

    /// Calculate Y position from hours as decimal (e.g., 14.5 = 2:30 PM)
    private func yPosition(forHourDecimal hourDecimal: CGFloat) -> CGFloat {
        let totalMinutes = hourDecimal * 60.0
        return totalMinutes * pxPerMinute
    }

    private var hours: [Int] {
        Array(0...23)
    }

    // MARK: - Event Processing

    private var timelineEvents: [PositionedTimelineEvent] {
        let rawEvents = events.compactMap { event -> TimelineEvent? in
            guard let startDate = event.startDate,
                  let endDate = event.endDate,
                  calendar.isDate(startDate, inSameDayAs: selectedDate) else {
                return nil
            }

            let startHour = calendar.component(.hour, from: startDate)
            let startMinute = calendar.component(.minute, from: startDate)
            let endHour = calendar.component(.hour, from: endDate)
            let endMinute = calendar.component(.minute, from: endDate)

            // Calculate as decimal hours for positioning
            let startOffset = CGFloat(startHour) + CGFloat(startMinute) / 60.0
            let endOffset = CGFloat(endHour) + CGFloat(endMinute) / 60.0
            let duration = endOffset - startOffset

            return TimelineEvent(
                event: event,
                startOffset: startOffset,
                duration: max(duration, 0.5)
            )
        }

        let sortedEvents = rawEvents.sorted { e1, e2 in
            if e1.startOffset == e2.startOffset {
                return e1.duration > e2.duration
            }
            return e1.startOffset < e2.startOffset
        }

        return calculateEventColumns(sortedEvents)
    }

    private func calculateEventColumns(_ events: [TimelineEvent]) -> [PositionedTimelineEvent] {
        var positioned: [PositionedTimelineEvent] = []

        for event in events {
            let eventEnd = event.startOffset + event.duration

            let overlappingEvents = events.filter { other in
                let otherEnd = other.startOffset + other.duration
                return event.startOffset < otherEnd && eventEnd > other.startOffset
            }

            let sortedOverlapping = overlappingEvents.sorted { e1, e2 in
                if e1.startOffset == e2.startOffset {
                    return e1.event.id < e2.event.id
                }
                return e1.startOffset < e2.startOffset
            }

            guard let columnIndex = sortedOverlapping.firstIndex(where: { $0.event.id == event.event.id }) else {
                continue
            }

            positioned.append(PositionedTimelineEvent(
                event: event.event,
                startOffset: event.startOffset,
                duration: event.duration,
                column: columnIndex,
                totalColumns: sortedOverlapping.count
            ))
        }

        return positioned
    }

    // Current time as decimal hours (e.g., 14.5 = 2:30 PM)
    private var currentTimeDecimal: CGFloat? {
        guard calendar.isDateInToday(selectedDate) else { return nil }

        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)

        return CGFloat(hour) + CGFloat(minute) / 60.0
    }

    // MARK: - Body

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                GeometryReader { geometry in
                    let eventAreaWidth = geometry.size.width - eventAreaStartX - eventAreaEndMargin

                    // Single Canvas for the entire timeline
                    // All elements positioned using the SAME coordinate system
                    ZStack(alignment: .topLeading) {

                        // LAYER 1: Hour grid lines (drawn at exact hour positions)
                        ForEach(hours, id: \.self) { hour in
                            // Grid line - uses unified yPosition function
                            Rectangle()
                                .fill(DesignSystem.Colors.tertiaryText.opacity(0.15))
                                .frame(height: 0.5)
                                .frame(maxWidth: .infinity)
                                .offset(x: timeColumnWidth, y: yPosition(forHour: hour))
                        }

                        // LAYER 2: Hour labels (positioned at exact hour positions)
                        // Label CENTER aligns with the grid line
                        ForEach(hours, id: \.self) { hour in
                            Text(hourLabel(for: hour))
                                .font(.system(size: 11, weight: .regular, design: .default))
                                .foregroundColor(DesignSystem.Colors.secondaryText.opacity(0.8))
                                .frame(width: timeColumnWidth - 8, alignment: .trailing)
                                // Position so the text baseline aligns with grid line
                                // Using same yPosition function, offset up by half line height
                                .offset(x: 0, y: yPosition(forHour: hour) - 6)
                                .id(hour)
                        }

                        // LAYER 3: Events (positioned using unified coordinate system)
                        ForEach(timelineEvents, id: \.event.id) { positionedEvent in
                            let gapSize: CGFloat = 2
                            let totalGaps = CGFloat(max(positionedEvent.totalColumns - 1, 0)) * gapSize
                            let eventWidth = (eventAreaWidth - totalGaps) / CGFloat(positionedEvent.totalColumns)
                            let eventX = eventAreaStartX + (eventWidth + gapSize) * CGFloat(positionedEvent.column)

                            // Use unified positioning function
                            let eventY = yPosition(forHourDecimal: positionedEvent.startOffset)
                            let eventHeight = max(positionedEvent.duration * hourHeight, 24)

                            EventBlock(
                                event: positionedEvent.event,
                                onTap: { onEventTap(positionedEvent.event) }
                            )
                            .frame(width: eventWidth, height: eventHeight)
                            .offset(x: eventX, y: eventY)
                        }

                        // LAYER 4: Current time indicator (positioned using unified coordinate system)
                        if let currentTime = currentTimeDecimal {
                            // Use unified positioning function
                            let timeY = yPosition(forHourDecimal: currentTime)

                            HStack(spacing: 0) {
                                // Red dot at the time label column
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: timeColumnWidth - 4)

                                // Red line across the event area
                                Rectangle()
                                    .fill(Color.red)
                                    .frame(height: 2)
                                    .offset(x: timeColumnWidth - 4)
                            }
                            .offset(y: timeY - 4) // Center the dot on the line
                        }
                    }
                }
                .frame(height: totalTimelineHeight + 40)
                .padding(.vertical, DesignSystem.Spacing.md)
            }
            .background(DesignSystem.Colors.background)
            .onAppear {
                scrollToAppropriateTime(proxy: proxy)
            }
        }
    }

    private func scrollToAppropriateTime(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                if let currentTime = currentTimeDecimal {
                    // Scroll to 1 hour before current time
                    let scrollToHour = max(Int(currentTime) - 1, 0)
                    proxy.scrollTo(scrollToHour, anchor: .top)
                } else {
                    // Default to 8 AM for non-today dates
                    proxy.scrollTo(8, anchor: .top)
                }
            }
        }
    }

    private func hourLabel(for hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"

        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = hour
        components.minute = 0

        guard let date = calendar.date(from: components) else {
            return "\(hour):00"
        }

        return formatter.string(from: date)
    }
}

// MARK: - Timeline Event Models
struct TimelineEvent {
    let event: Event
    let startOffset: CGFloat // Hours from midnight
    let duration: CGFloat // Duration in hours
}

struct PositionedTimelineEvent {
    let event: Event
    let startOffset: CGFloat // Hours from midnight
    let duration: CGFloat // Duration in hours
    let column: Int // Which column (0, 1, 2...) for side-by-side display
    let totalColumns: Int // Total columns needed at this time
}

// MARK: - Event Block - iOS Calendar Style
struct EventBlock: View {
    let event: Event
    let onTap: () -> Void
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    // Generate subtle colors for events - iOS Calendar style
    private var eventColor: Color {
        // Use displayColor which respects user-set eventColor or falls back to type-based color
        return event.displayColor
    }
    
    // Subtle background color - iOS Calendar style (more muted for dark theme)
    private var backgroundColor: Color {
        let baseColor = eventColor
        // For dark theme, use very subtle opacity - iOS Calendar style
        // Make colors more muted by reducing saturation
        return baseColor.opacity(0.2)
    }
    
    // Left border accent - iOS Calendar style (slightly more visible)
    private var borderColor: Color {
        eventColor.opacity(0.7)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left accent border - iOS Calendar style
                Rectangle()
                    .fill(borderColor)
                    .frame(width: 3)
                
                // Event content
                VStack(alignment: .leading, spacing: 3) {
                    // Event title
                    Text(event.title)
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Time range
                    if let startDate = event.startDate, let endDate = event.endDate {
                        Text("\(timeFormatter.string(from: startDate)) - \(timeFormatter.string(from: endDate))")
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .lineLimit(1)
                    }
                    
                    // Location (if available and space permits)
                    if let location = event.locationName, !location.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 9, weight: .regular))
                            Text(location)
                                .font(.system(size: 10, weight: .regular, design: .default))
                                .lineLimit(1)
                        }
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(DesignSystem.Colors.tertiaryText.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Day View Header
struct DayViewHeader: View {
    @Binding var selectedDate: Date
    @Binding var viewMode: CalendarViewMode
    
    private let calendar = Calendar.current
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Navigation row
            HStack {
                // Previous day
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if let prevDay = calendar.date(byAdding: .day, value: -1, to: selectedDate) {
                            selectedDate = prevDay
                        }
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(DesignSystem.Colors.primary.opacity(0.1))
                        )
                }
                .hapticFeedback(.light)
                
                Spacer()
                
                // Date display
                VStack(spacing: 2) {
                    Text(dateFormatter.string(from: selectedDate))
                        .font(DesignSystem.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    
                    if calendar.isDateInToday(selectedDate) {
                        Text("Today")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                }
                
                Spacer()
                
                // Next day
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if let nextDay = calendar.date(byAdding: .day, value: 1, to: selectedDate) {
                            selectedDate = nextDay
                        }
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(DesignSystem.Colors.primary.opacity(0.1))
                        )
                }
                .hapticFeedback(.light)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            
            // View Mode Switcher
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach([CalendarViewMode.month, .week, .day], id: \.self) { mode in
                    Button(action: {
                        withAnimation(DesignSystem.Animations.smooth) {
                            viewMode = mode
                        }
                    }) {
                        Text(mode == .month ? "Month" : mode == .week ? "Week" : "Day")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(viewMode == mode ? .semibold : .regular)
                            .foregroundColor(viewMode == mode ? .white : DesignSystem.Colors.primary)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(
                                viewMode == mode ? DesignSystem.Colors.primaryGradient : LinearGradient(
                                    colors: [DesignSystem.Colors.primary.opacity(0.1)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                    }
                    .hapticFeedback()
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.sm)
        }
        .padding(.top, DesignSystem.Spacing.sm)
        .background(
            Color(UIColor.systemBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }
}

