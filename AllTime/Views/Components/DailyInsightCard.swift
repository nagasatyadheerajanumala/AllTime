import SwiftUI

/// The ONE daily insight card - Clara's opinionated point of view
/// This transforms Clara from a reporter to an advisor
struct DailyInsightCard: View {
    let recommendation: PrimaryRecommendation
    var onTap: (() -> Void)? = nil

    /// Urgency-based accent color
    private var accentColor: Color {
        switch recommendation.urgency?.lowercased() {
        case "now": return Color(red: 0.95, green: 0.3, blue: 0.3)  // Urgent red
        case "today": return Color(red: 0.95, green: 0.6, blue: 0.2) // Amber
        default: return Color(red: 0.4, green: 0.7, blue: 0.95)      // Calm blue
        }
    }

    /// Icon based on category
    private var categoryIcon: String {
        switch recommendation.category?.lowercased() {
        case "protect_time": return "shield.lefthalf.filled"
        case "reduce_load": return "arrow.down.circle.fill"
        case "health": return "heart.fill"
        case "catch_up": return "bolt.fill"
        case "focus": return "target"
        default: return recommendation.icon ?? "lightbulb.fill"
        }
    }

    /// Short urgency label
    private var urgencyLabel: String? {
        switch recommendation.urgency?.lowercased() {
        case "now": return "Act now"
        case "today": return "Today"
        default: return nil
        }
    }

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 14) {
                // Icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: categoryIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Urgency badge (if urgent)
                    if let urgency = urgencyLabel {
                        Text(urgency.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(accentColor)
                            .tracking(0.5)
                    }

                    // The insight - Clara's point of view
                    Text(recommendation.action)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Consequence (if available) - what happens if ignored
                    if let consequence = recommendation.ignoredConsequence, !consequence.isEmpty {
                        Text(consequence)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .lineLimit(1)
                    } else if let reason = recommendation.reason, !reason.isEmpty {
                        Text(reason)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignSystem.Colors.cardBackground)
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            )
            .overlay(
                // Subtle accent line on left edge
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [accentColor.opacity(0.5), accentColor.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(InsightScaleButtonStyle())
    }
}

/// Subtle scale effect on press for insight card
private struct InsightScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        DailyInsightCard(
            recommendation: PrimaryRecommendation(
                rawId: "1",
                action: "Protect your 2pm focus block — it's your only deep work window today",
                reason: "6 meetings already scheduled, this is your last chance for focused work",
                urgency: "now",
                impact: "high",
                category: "protect_time",
                icon: "shield.lefthalf.filled",
                deepLink: nil,
                confidence: 90,
                ignoredConsequence: "You'll end the day with zero deep work done"
            )
        )

        DailyInsightCard(
            recommendation: PrimaryRecommendation(
                rawId: "2",
                action: "Strong energy day — tackle your hardest task before noon",
                reason: "Good sleep + light morning = peak cognitive window",
                urgency: "today",
                impact: "high",
                category: "focus",
                icon: "bolt.fill",
                deepLink: nil,
                confidence: 85,
                ignoredConsequence: nil
            )
        )
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
