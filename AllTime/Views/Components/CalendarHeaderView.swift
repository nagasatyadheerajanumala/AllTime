import SwiftUI

/// Premium calendar header with month selector and collapsible week strip
struct CalendarHeaderView: View {
    @Binding var selectedDate: Date
    @State private var isWeekStripExpanded = true
    
    private let calendar = Calendar.current
    
    private var monthYearText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Month selector row
            HStack {
                // Previous month button
                Button(action: {
                    withAnimation(DesignSystem.Animations.smooth) {
                        if let prevMonth = calendar.date(byAdding: .month, value: -1, to: selectedDate) {
                            selectedDate = prevMonth
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
                
                // Month/Year display
                VStack(spacing: 2) {
                    Text(monthYearText)
                        .font(DesignSystem.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    
                    Text("Tap a date to view events")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
                
                Spacer()
                
                // Next month button
                Button(action: {
                    withAnimation(DesignSystem.Animations.smooth) {
                        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: selectedDate) {
                            selectedDate = nextMonth
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
            .padding(.vertical, DesignSystem.Spacing.sm)
            
            // Collapsible week strip
            if isWeekStripExpanded {
                CalendarWeekStrip(
                    selectedDate: $selectedDate,
                    referenceDate: selectedDate
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Toggle button for week strip
            Button(action: {
                withAnimation(DesignSystem.Animations.smooth) {
                    isWeekStripExpanded.toggle()
                }
            }) {
                HStack(spacing: 4) {
                    Text(isWeekStripExpanded ? "Hide Week" : "Show Week")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.primary)
                    
                    Image(systemName: isWeekStripExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
                .padding(.vertical, DesignSystem.Spacing.xs)
            }
            .padding(.bottom, DesignSystem.Spacing.sm)
        }
        .background(
            ZStack {
                Color(UIColor.systemBackground)
                
                // Subtle gradient
                LinearGradient(
                    colors: [
                        Color(UIColor.systemBackground),
                        Color(UIColor.secondarySystemBackground).opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 8,
            x: 0,
            y: 2
        )
    }
}

