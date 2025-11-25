import SwiftUI

/// Horizontal scrolling week strip - Apple Calendar style
struct CalendarWeekStrip: View {
    @Binding var selectedDate: Date
    let referenceDate: Date
    
    private let calendar = Calendar.current
    
    // Generate dates for the week containing referenceDate
    private var weekDates: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
            return []
        }
        
        var dates: [Date] = []
        var currentDate = weekInterval.start
        
        while currentDate < weekInterval.end {
            dates.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }
        
        return dates
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(weekDates, id: \.self) { date in
                    WeekDayButton(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        onTap: {
                            withAnimation(DesignSystem.Animations.smooth) {
                                selectedDate = date
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
}

// MARK: - Week Day Button
struct WeekDayButton: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var weekdayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Weekday name
                Text(weekdayName)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : DesignSystem.Colors.secondaryText)
                
                // Day number
                Text(dayNumber)
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(isSelected || isToday ? .bold : .regular)
                    .foregroundColor(isSelected ? .white : (isToday ? DesignSystem.Colors.primary : DesignSystem.Colors.primaryText))
            }
            .frame(width: 50, height: 70)
            .background(
                ZStack {
                    // Selected background
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(DesignSystem.Colors.primaryGradient)
                    } else if isToday {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(DesignSystem.Colors.primary.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(DesignSystem.Colors.primary, lineWidth: 2)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(UIColor.secondarySystemBackground).opacity(0.5))
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
        .hapticFeedback(.light)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

