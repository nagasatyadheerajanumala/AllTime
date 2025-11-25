import SwiftUI

/// 24-hour timeline view - Google Calendar style
struct DayTimelineView: View {
    @Binding var selectedDate: Date
    let events: [Event]
    let onEventTap: (Event) -> Void
    
    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 60
    
    private var hours: [Int] {
        Array(0...23)
    }
    
    // Group events by their position in the timeline with overlap detection
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
            
            let startOffset = CGFloat(startHour) + CGFloat(startMinute) / 60.0
            let endOffset = CGFloat(endHour) + CGFloat(endMinute) / 60.0
            let duration = endOffset - startOffset
            
            return TimelineEvent(
                event: event,
                startOffset: startOffset,
                duration: max(duration, 0.5) // Minimum 30 minutes height
            )
        }
        
        // Sort by start time, then by duration (longer events first)
        let sortedEvents = rawEvents.sorted { e1, e2 in
            if e1.startOffset == e2.startOffset {
                return e1.duration > e2.duration
            }
            return e1.startOffset < e2.startOffset
        }
        
        // Calculate columns for overlapping events
        return calculateEventColumns(sortedEvents)
    }
    
    // Calculate column positions for overlapping events
    private func calculateEventColumns(_ events: [TimelineEvent]) -> [PositionedTimelineEvent] {
        var positioned: [PositionedTimelineEvent] = []
        
        // For each event, find all events that overlap with it
        for event in events {
            let eventEnd = event.startOffset + event.duration
            
            // Find all events that overlap with this event
            let overlappingEvents = events.filter { other in
                let otherEnd = other.startOffset + other.duration
                return event.startOffset < otherEnd && eventEnd > other.startOffset
            }
            
            // Sort overlapping events by start time to assign consistent columns
            let sortedOverlapping = overlappingEvents.sorted { e1, e2 in
                if e1.startOffset == e2.startOffset {
                    return e1.event.id < e2.event.id // Consistent ordering for same start time
                }
                return e1.startOffset < e2.startOffset
            }
            
            // Find this event's position in the sorted list
            guard let columnIndex = sortedOverlapping.firstIndex(where: { $0.event.id == event.event.id }) else {
                continue
            }
            
            let totalColumns = sortedOverlapping.count
            
            positioned.append(PositionedTimelineEvent(
                event: event.event,
                startOffset: event.startOffset,
                duration: event.duration,
                column: columnIndex,
                totalColumns: totalColumns
            ))
        }
        
        return positioned
    }
    
    // Current time indicator position
    private var currentTimeOffset: CGFloat? {
        guard calendar.isDateInToday(selectedDate) else { return nil }
        
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        
        return CGFloat(hour) + CGFloat(minute) / 60.0
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // Background
                    DesignSystem.Colors.background
                        .frame(minHeight: hourHeight * 24)
                    
                    // Hour labels and grid lines
                    VStack(spacing: 0) {
                        ForEach(hours, id: \.self) { hour in
                            HStack(alignment: .top, spacing: 0) {
                                // Hour label
                                Text(hourLabel(for: hour))
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.primaryText.opacity(0.6))
                                    .frame(width: 60, alignment: .trailing)
                                    .padding(.trailing, DesignSystem.Spacing.sm)
                                    .offset(y: -8)
                                
                                // Grid line
                                Rectangle()
                                    .fill(DesignSystem.Colors.tertiaryText.opacity(0.2))
                                    .frame(height: 0.5)
                                    .frame(maxWidth: .infinity)
                            }
                            .frame(height: hourHeight)
                            .id(hour)
                        }
                    }
                    
                    // Events overlay with proper positioning for overlaps
                    GeometryReader { geometry in
                        ForEach(Array(timelineEvents.enumerated()), id: \.element.event.id) { index, positionedEvent in
                            let availableWidth = geometry.size.width - 70 - DesignSystem.Spacing.md
                            let gapSize: CGFloat = 4 // Gap between events
                            let totalGaps = CGFloat(max(positionedEvent.totalColumns - 1, 0)) * gapSize
                            let eventWidth = (availableWidth - totalGaps) / CGFloat(positionedEvent.totalColumns)
                            let xOffset = 70 + (eventWidth * CGFloat(positionedEvent.column)) + (gapSize * CGFloat(positionedEvent.column))
                            
                            EventBlock(
                                event: positionedEvent.event,
                                onTap: { onEventTap(positionedEvent.event) }
                            )
                            .frame(width: eventWidth, height: positionedEvent.duration * hourHeight)
                            .offset(x: xOffset, y: positionedEvent.startOffset * hourHeight)
                        }
                    }
                    
                    // Current time indicator
                    if let currentOffset = currentTimeOffset {
                        HStack(spacing: 0) {
                            Circle()
                                .fill(DesignSystem.Colors.primary)
                                .frame(width: 10, height: 10)
                                .padding(.leading, 55)
                            
                            Rectangle()
                                .fill(DesignSystem.Colors.primary)
                                .frame(height: 2)
                        }
                        .offset(y: currentOffset * hourHeight)
                        .transition(.opacity)
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.md)
            }
            .onAppear {
                // Scroll to current hour or 8 AM
                if let currentOffset = currentTimeOffset {
                    let scrollToHour = max(Int(currentOffset) - 1, 0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(scrollToHour, anchor: .top)
                        }
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(8, anchor: .top) // Default to 8 AM
                        }
                    }
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

// MARK: - Event Block
struct EventBlock: View {
    let event: Event
    let onTap: () -> Void
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    // Generate distinct colors for different events
    private var eventColor: Color {
        // Use event source color if available
        return event.sourceColorAsColor
    }
    
    // Lighter shade for background
    private var backgroundColor: Color {
        eventColor.opacity(0.85)
    }
    
    // Darker shade for border
    private var borderColor: Color {
        eventColor.opacity(0.6)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                // Event title
                Text(event.title)
                    .font(DesignSystem.Typography.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Time range
                if let startDate = event.startDate, let endDate = event.endDate {
                    Text("\(timeFormatter.string(from: startDate)) - \(timeFormatter.string(from: endDate))")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                }
                
                // Location
                if let location = event.locationName, !location.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 8))
                        Text(location)
                            .font(DesignSystem.Typography.caption2)
                            .lineLimit(1)
                    }
                    .foregroundColor(.white.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(borderColor, lineWidth: 0.5)
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

