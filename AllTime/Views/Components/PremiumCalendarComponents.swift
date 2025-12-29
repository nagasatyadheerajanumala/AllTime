import SwiftUI

// MARK: - Premium Calendar Header
struct PremiumCalendarHeader: View {
    @Binding var selectedDate: Date
    @Binding var viewMode: CalendarViewMode
    @Binding var calendarStyle: CalendarStyle
    let isRefreshing: Bool
    let onRefresh: () -> Void

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    private let weekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private var dateRangeText: String {
        let calendar = Calendar.current
        switch viewMode {
        case .month:
            return dateFormatter.string(from: selectedDate)
        case .week:
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) {
                let start = weekFormatter.string(from: weekInterval.start)
                let end = weekFormatter.string(from: weekInterval.end - 1)
                return "\(start) - \(end)"
            }
            return weekFormatter.string(from: selectedDate)
        case .day:
            return dayFormatter.string(from: selectedDate)
        }
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Top Row: Month Navigation + Action Buttons
            HStack(spacing: 12) {
                // Previous Period Button
                Button(action: {
                    withAnimation(DesignSystem.Animations.smooth) {
                        let calendar = Calendar.current
                        switch viewMode {
                        case .month:
                            selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                        case .week:
                            selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
                        case .day:
                            selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                        }
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(calendarStyle == .wheel ? .white : DesignSystem.Colors.primary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(calendarStyle == .wheel ? .white.opacity(0.15) : DesignSystem.Colors.primary.opacity(0.1))
                        )
                }

                // Date Range Display - Clean, centered
                Text(dateRangeText)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(calendarStyle == .wheel ? .white : DesignSystem.Colors.primaryText)
                    .frame(maxWidth: .infinity)

                // Next Period Button
                Button(action: {
                    withAnimation(DesignSystem.Animations.smooth) {
                        let calendar = Calendar.current
                        switch viewMode {
                        case .month:
                            selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                        case .week:
                            selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
                        case .day:
                            selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                        }
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(calendarStyle == .wheel ? .white : DesignSystem.Colors.primary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(calendarStyle == .wheel ? .white.opacity(0.15) : DesignSystem.Colors.primary.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.lg)

            // Bottom Row: View Mode Selector + Style/Refresh Buttons
            HStack(spacing: 16) {
                // Segmented control for Month/Week/Day
                HStack(spacing: 2) {
                    ForEach([CalendarViewMode.month, .week, .day], id: \.self) { mode in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                viewMode = mode
                            }
                        }) {
                            Text(mode == .month ? "Month" : mode == .week ? "Week" : "Day")
                                .font(.subheadline.weight(viewMode == mode ? .semibold : .medium))
                                .foregroundColor(
                                    viewMode == mode
                                        ? .white
                                        : (calendarStyle == .wheel ? .white.opacity(0.7) : DesignSystem.Colors.secondaryText)
                                )
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Group {
                                        if viewMode == mode {
                                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                                .fill(DesignSystem.Colors.primary)
                                        } else {
                                            Color.clear
                                        }
                                    }
                                )
                        }
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(calendarStyle == .wheel ? .white.opacity(0.1) : DesignSystem.Colors.cardBackgroundElevated)
                )

                Spacer()

                // Action buttons with proper spacing
                HStack(spacing: 12) {
                    // Calendar Style Toggle
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            calendarStyle = calendarStyle == .traditional ? .wheel : .traditional
                        }
                    }) {
                        Image(systemName: calendarStyle == .traditional ? "circle.dotted" : "square.grid.2x2")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(calendarStyle == .wheel ? .white : DesignSystem.Colors.primary)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(calendarStyle == .wheel ? .white.opacity(0.15) : DesignSystem.Colors.primary.opacity(0.1))
                            )
                    }

                    // Refresh Button
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(calendarStyle == .wheel ? .white : DesignSystem.Colors.primary)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(calendarStyle == .wheel ? .white.opacity(0.15) : DesignSystem.Colors.primary.opacity(0.1))
                            )
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                    }
                    .disabled(isRefreshing)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.md)
        }
        .background(
            Group {
                if calendarStyle == .wheel {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.5)
                } else {
                    DesignSystem.Colors.background
                }
            }
        )
    }
}

// MARK: - Premium Calendar Grid
struct PremiumCalendarGrid: View {
    @Binding var selectedDate: Date
    let events: [Event]
    let viewMode: CalendarViewMode
    var onDayTap: ((Date, [Event]) -> Void)? = nil  // New callback for day tap

    private let calendar = Calendar.current

    // Pre-computed event index (built once when events change)
    @State private var eventsByDate: [Date: [Event]] = [:]

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Weekday Headers - Apple-like styling
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { weekday in
                    Text(weekday.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.xs)
            .padding(.bottom, DesignSystem.Spacing.xs)

            // Calendar Days Grid with better spacing
            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: columnCount)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(calendarDays, id: \.self) { date in
                    PremiumCalendarDayCell(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        isCurrentMonth: isDateInCurrentRange(date),
                        hasEvents: hasEventsOnDate(date),
                        eventCount: eventCountOnDate(date),
                        events: eventsForDay(date),
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedDate = date
                            }
                            // Call the day tap callback to open detail sheet
                            onDayTap?(date, eventsForDay(date))
                        }
                    )
                }
            }
        }
        .padding(DesignSystem.Today.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Today.innerCardCornerRadius)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .onAppear {
            // Build index when view appears
            buildEventsIndex()
        }
        .onChange(of: events.count) { _, _ in
            // Rebuild index when event count changes (indicates events changed)
            buildEventsIndex()
        }
    }
    
    // Build event index once (called when events change)
    private func buildEventsIndex() {
        var index: [Date: [Event]] = [:]
        for event in events {
            guard let eventDate = event.startDate else { continue }
            let normalizedDate = calendar.startOfDay(for: eventDate)
            if index[normalizedDate] == nil {
                index[normalizedDate] = []
            }
            index[normalizedDate]?.append(event)
        }
        eventsByDate = index
    }
    
    private var columnCount: Int {
        switch viewMode {
        case .month:
            return 7
        case .week:
            return 7
        case .day:
            return 1
        }
    }
    
    private var weekdaySymbols: [String] {
        switch viewMode {
        case .month, .week:
            return calendar.shortWeekdaySymbols
        case .day:
            return ["Time"]
        }
    }
    
    private var calendarDays: [Date] {
        switch viewMode {
        case .month:
            return monthDays
        case .week:
            return weekDays
        case .day:
            return [selectedDate]
        }
    }
    
    private var monthDays: [Date] {
        // Apple Calendar-style: Always show 42 days (6 weeks)
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate) else {
            return []
        }
        
        // Get first day of the month
        let firstDayOfMonth = monthInterval.start
        
        // Get the first day of the week that contains the first day of the month
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) - 1 // 0 = Sunday, 6 = Saturday
        
        // Calculate the start date (first day of the first week shown)
        guard let startDate = calendar.date(byAdding: .day, value: -firstWeekday, to: firstDayOfMonth) else {
            return []
        }
        
        // Generate exactly 42 days (6 weeks × 7 days)
        var days: [Date] = []
        var currentDate = startDate
        
        for _ in 0..<42 {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
    
    private var weekDays: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return []
        }
        
        var days: [Date] = []
        var currentDate = weekInterval.start
        
        while currentDate < weekInterval.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
    
    private func isDateInCurrentRange(_ date: Date) -> Bool {
        switch viewMode {
        case .month:
            return calendar.isDate(date, equalTo: selectedDate, toGranularity: .month)
        case .week:
            return calendar.isDate(date, equalTo: selectedDate, toGranularity: .weekOfYear)
        case .day:
            return calendar.isDate(date, inSameDayAs: selectedDate)
        }
    }
    
    // Optimized: Use pre-computed index for O(1) lookups
    private func hasEventsOnDate(_ date: Date) -> Bool {
        let normalizedDate = calendar.startOfDay(for: date)
        return (eventsByDate[normalizedDate]?.count ?? 0) > 0
    }
    
    private func eventCountOnDate(_ date: Date) -> Int {
        let normalizedDate = calendar.startOfDay(for: date)
        return eventsByDate[normalizedDate]?.count ?? 0
    }
    
    private func eventsForDay(_ date: Date) -> [Event] {
        let normalizedDate = calendar.startOfDay(for: date)
        return eventsByDate[normalizedDate] ?? []
    }
}

// MARK: - Premium Calendar Day Cell
struct PremiumCalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let hasEvents: Bool
    let eventCount: Int
    let events: [Event]
    let onTap: () -> Void

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    var body: some View {
        Button(action: {
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 3) {
                // Day number - cleaner Apple-like styling
                HStack {
                    Text(dateFormatter.string(from: date))
                        .font(.system(size: 14, weight: isToday ? .bold : .medium))
                        .foregroundColor(textColor)

                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)

                // Event bullet labels (max 2 lines)
                if hasEvents && isCurrentMonth {
                    VStack(alignment: .leading, spacing: 2) {
                        let eventsToShow = Array(events.prefix(2))
                        ForEach(eventsToShow, id: \.id) { event in
                            HStack(spacing: 3) {
                                // Small colored dot indicator (uses displayColor for user-set eventColor)
                                Circle()
                                    .fill(event.displayColor)
                                    .frame(width: 4, height: 4)

                                // Event title bullet (truncated)
                                Text(event.title.isEmpty ? "No Title" : event.title)
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(isSelected ? .white.opacity(0.9) : DesignSystem.Colors.secondaryText)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .padding(.horizontal, 4)
                        }

                        // Show "+N" indicator if more events
                        if eventCount > 2 {
                            Text("+\(eventCount - 2)")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(isSelected ? .white.opacity(0.7) : DesignSystem.Colors.tertiaryText)
                                .padding(.horizontal, 4)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(minHeight: 56, maxHeight: 70)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(backgroundColor)
            .cornerRadius(DesignSystem.CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .stroke(borderColor, lineWidth: isToday && !isSelected ? 1.5 : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var textColor: Color {
        if !isCurrentMonth {
            return DesignSystem.Colors.tertiaryText.opacity(0.3)
        } else if isSelected {
            return .white
        } else if isToday {
            return DesignSystem.Colors.primary
        } else {
            return DesignSystem.Colors.primaryText
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return DesignSystem.Colors.primary
        } else if isToday {
            return DesignSystem.Colors.primary.opacity(0.08)
        } else if !isCurrentMonth {
            return Color.clear
        } else {
            return DesignSystem.Colors.cardBackgroundElevated.opacity(0.5)
        }
    }

    private var borderColor: Color {
        if isToday && !isSelected {
            return DesignSystem.Colors.primary.opacity(0.5)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Premium Events Section
struct PremiumEventsSection: View {
    let headerText: String
    let events: [Event]
    let onEventTap: (Event) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(headerText)
                        .font(DesignSystem.Typography.title3)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    
                    if !events.isEmpty {
                        Text("\(events.count) event\(events.count == 1 ? "" : "s")")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.md)
            
            // Events List (no nested ScrollView - parent handles scrolling)
            if events.isEmpty {
                // Empty State
                VStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 56))
                        .foregroundColor(DesignSystem.Colors.tertiaryText.opacity(0.5))
                    
                    Text("No events scheduled")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    
                    Text("Tap + to add a new event")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 200) // Ensure minimum height for visibility
                .padding(.vertical, DesignSystem.Spacing.xxl)
            } else {
                // Events list (no ScrollView - parent CalendarView handles scrolling)
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(events) { event in
                        PremiumEventRow(event: event)
                            .onTapGesture {
                                // Premium iOS 18-style tap animation
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    onEventTap(event)
                                }
                            }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
        }
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Premium Event Row
struct PremiumEventRow: View {
    let event: Event
    
    // Cache DateFormatter as static to avoid repeated allocation
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter
    }()
    
    private var eventColor: Color {
        let hash = abs(event.title.hashValue)
        return DesignSystem.Colors.eventColors[hash % DesignSystem.Colors.eventColors.count]
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Color Bar
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(eventColor)
                .frame(width: 4)
            
            // Event Details
            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(DesignSystem.Typography.bodyBold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(2)
                
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // Time
                    if let startDate = event.startDate {
                        Label(Self.timeFormatter.string(from: startDate), systemImage: "clock")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    
                    // Location
                    if let location = event.location {
                        if let locationName = location.name, !locationName.isEmpty {
                            Label(locationName, systemImage: "location")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .lineLimit(1)
                        } else if let locationAddress = location.address, !locationAddress.isEmpty {
                            Label(locationAddress, systemImage: "location")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }
                
                // Source Badge
                HStack(spacing: 4) {
                    Image(systemName: sourceIcon)
                        .font(.system(size: 10))
                    Text(event.source.capitalized)
                        .font(DesignSystem.Typography.caption2)
                }
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, 4)
                .background(eventColor.opacity(0.8))
                .cornerRadius(DesignSystem.CornerRadius.sm)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.md)
        .shadow(
            color: DesignSystem.Shadow.small.color,
            radius: DesignSystem.Shadow.small.radius,
            x: DesignSystem.Shadow.small.x,
            y: DesignSystem.Shadow.small.y
        )
        .hapticFeedback(.light)
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: event.id)
    }
    
    private var sourceIcon: String {
        switch event.source.lowercased() {
        case "google":
            return "g.circle.fill"
        case "microsoft", "outlook":
            return "m.circle.fill"
        case "apple", "eventkit":
            return "applelogo"
        default:
            return "calendar"
        }
    }
}

