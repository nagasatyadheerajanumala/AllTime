import SwiftUI

/// Card shown on weekends and holidays to encourage users to plan their day with AI
struct PlanMyDayCard: View {
    var holidayName: String? = nil
    let onTap: () -> Void

    private var title: String {
        if let holiday = holidayName, !holiday.isEmpty {
            return "Plan Your \(holiday)"
        } else if Calendar.current.isDateInWeekend(Date()) {
            return "Plan Your Weekend"
        } else {
            return "Plan Your Day Off"
        }
    }

    private var subtitle: String {
        if holidayName != nil {
            return "Make the most of your holiday with AI-powered suggestions"
        } else {
            return "Get AI-powered activity suggestions based on your interests"
        }
    }

    private var iconName: String {
        if holidayName != nil {
            return "star.fill"
        } else {
            return "wand.and.stars"
        }
    }

    private var iconColor: Color {
        holidayName != nil ? .orange : .purple
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [iconColor.opacity(0.25), Color.blue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: iconName)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                }

                // Content
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(
                        LinearGradient(
                            colors: [iconColor.opacity(0.2), Color.blue.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview("Weekend") {
    ZStack {
        DesignSystem.Colors.background.ignoresSafeArea()

        PlanMyDayCard(onTap: {})
            .padding()
    }
    .preferredColorScheme(.dark)
}

#Preview("Holiday") {
    ZStack {
        DesignSystem.Colors.background.ignoresSafeArea()

        PlanMyDayCard(holidayName: "Christmas", onTap: {})
            .padding()
    }
    .preferredColorScheme(.dark)
}
