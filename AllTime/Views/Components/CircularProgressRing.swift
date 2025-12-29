import SwiftUI

// MARK: - Circular Progress Ring

struct CircularProgressRing: View {
    let progress: Double // 0.0 to 1.0
    let lineWidth: CGFloat
    let gradientColors: [Color]
    let backgroundColor: Color

    init(
        progress: Double,
        lineWidth: CGFloat = 12,
        gradientColors: [Color] = [Color(hex: "3B82F6"), Color(hex: "8B5CF6")],
        backgroundColor: Color = Color(hex: "2A2A3C")
    ) {
        self.progress = min(max(progress, 0), 1)
        self.lineWidth = lineWidth
        self.gradientColors = gradientColors
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: gradientColors),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: progress)
        }
    }
}

// MARK: - Balance Score Ring

struct BalanceScoreRing: View {
    let score: Int
    let previousScore: Int?
    let size: CGFloat

    private var progress: Double {
        Double(score) / 100.0
    }

    private var gradientColors: [Color] {
        switch score {
        case 70...100: return [Color(hex: "10B981"), Color(hex: "34D399")]
        case 40...69: return [Color(hex: "F59E0B"), Color(hex: "FBBF24")]
        default: return [Color(hex: "EF4444"), Color(hex: "F87171")]
        }
    }

    private var scoreLabel: String {
        switch score {
        case 80...100: return "Excellent"
        case 60...79: return "Good"
        case 40...59: return "Fair"
        case 20...39: return "Needs Work"
        default: return "Critical"
        }
    }

    private var delta: Int? {
        guard let prev = previousScore else { return nil }
        return score - prev
    }

    var body: some View {
        ZStack {
            CircularProgressRing(
                progress: progress,
                lineWidth: size * 0.08,
                gradientColors: gradientColors
            )
            .frame(width: size, height: size)

            VStack(spacing: 4) {
                Text("\(score)")
                    .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(scoreLabel)
                    .font(.system(size: size * 0.1, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                if let d = delta, d != 0 {
                    HStack(spacing: 2) {
                        Image(systemName: d > 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: size * 0.08, weight: .semibold))
                        Text("\(abs(d))")
                            .font(.system(size: size * 0.09, weight: .semibold))
                    }
                    .foregroundColor(d > 0 ? Color(hex: "10B981") : Color(hex: "EF4444"))
                }
            }
        }
    }
}

// MARK: - Metric Comparison Card

struct MetricComparisonCard: View {
    let title: String
    let icon: String
    let currentValue: String
    let previousValue: String?
    let delta: Int
    let trend: String
    let unit: String
    let color: Color
    let higherIsBetter: Bool

    private var trendColor: Color {
        switch trend {
        case "up": return higherIsBetter ? Color(hex: "10B981") : Color(hex: "EF4444")
        case "down": return higherIsBetter ? Color(hex: "EF4444") : Color(hex: "10B981")
        default: return Color(hex: "6B7280")
        }
    }

    private var trendIcon: String {
        switch trend {
        case "up": return "arrow.up"
        case "down": return "arrow.down"
        default: return "minus"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                Spacer()

                // Trend indicator
                if delta != 0 {
                    HStack(spacing: 3) {
                        Image(systemName: trendIcon)
                            .font(.system(size: 10, weight: .bold))
                        Text("\(abs(delta))\(unit)")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(trendColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(trendColor.opacity(0.15))
                    )
                }
            }

            // Value
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(currentValue)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            // Previous week comparison
            if let prev = previousValue, delta != 0 {
                Text("vs \(prev)\(unit) last week")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Mini Progress Ring

struct MiniProgressRing: View {
    let progress: Double
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: size * 0.15)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.15, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        BalanceScoreRing(score: 72, previousScore: 65, size: 160)

        MetricComparisonCard(
            title: "Meetings",
            icon: "person.2.fill",
            currentValue: "12",
            previousValue: "15",
            delta: -3,
            trend: "down",
            unit: "h",
            color: Color(hex: "8B5CF6"),
            higherIsBetter: false
        )
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
