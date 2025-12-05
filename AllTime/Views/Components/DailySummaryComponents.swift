import SwiftUI

// MARK: - Summary Metrics Card

struct SummaryMetricsCard: View {
    let waterIntake: Double?
    let waterGoal: Double?
    let steps: Int?
    let stepsGoal: Int?
    let sleepHours: Double?

    var body: some View {
        VStack(spacing: 16) {
            // Water Metric
            if let water = waterIntake, let goal = waterGoal {
                MetricRow(
                    icon: "💧",
                    title: "Water Intake",
                    value: String(format: "%.1fL", water),
                    goal: String(format: "%.1fL", goal),
                    progress: water / goal,
                    color: waterColor(for: water / goal)
                )
            }

            // Steps Metric
            if let steps = steps, let goal = stepsGoal {
                MetricRow(
                    icon: "👟",
                    title: "Steps",
                    value: "\(steps.formatted())",
                    goal: "\(goal.formatted())",
                    progress: Double(steps) / Double(goal),
                    color: stepsColor(for: Double(steps) / Double(goal))
                )
            }

            // Sleep Metric
            if let sleep = sleepHours {
                MetricRow(
                    icon: "😴",
                    title: "Sleep",
                    value: String(format: "%.1fh", sleep),
                    goal: "7-9h",
                    progress: min(sleep / 8.0, 1.0),
                    color: sleepColor(for: sleep)
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private func waterColor(for progress: Double) -> Color {
        if progress >= 1.0 { return .green }
        if progress >= 0.7 { return .yellow }
        return .red
    }

    private func stepsColor(for progress: Double) -> Color {
        if progress >= 1.0 { return .green }
        if progress >= 0.7 { return .orange }
        return .red
    }

    private func sleepColor(for hours: Double) -> Color {
        if hours >= 7.0 { return .green }
        if hours >= 6.0 { return .yellow }
        return .red
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let icon: String
    let title: String
    let value: String
    let goal: String
    let progress: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(icon)
                    .font(.title2)
                Text(title)
                    .font(.headline)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(value)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Goal: \(goal)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * min(progress, 1.0), height: 8)
                        .cornerRadius(4)
                        .animation(.easeInOut, value: progress)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Break Recommendations View

struct BreakRecommendationsView: View {
    let breaks: [BreakWindow]
    let strategy: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Overall Strategy
            if let strategy = strategy {
                HStack(alignment: .top, spacing: 8) {
                    Text("🔄")
                        .font(.title2)
                    Text(strategy)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }

            // Individual Breaks
            if !breaks.isEmpty {
                Text("Suggested Breaks")
                    .font(.headline)
                    .padding(.top, 8)

                ForEach(breaks) { breakWindow in
                    BreakCard(break: breakWindow)
                }
            }
        }
        .padding()
    }
}

// MARK: - Break Card

struct BreakCard: View {
    let `break`: BreakWindow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Type Icon
            Text(breakType.rawValue)
                .font(.title)
                .frame(width: 40, height: 40)
                .background(Circle().fill(typeColor.opacity(0.2)))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(timeString)
                        .font(.headline)
                    Spacer()
                    Text("\(breakDuration) min")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text(breakType.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(typeColor)

                Text(breakReasoning)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }

    private var breakType: BreakType {
        return `break`.type
    }

    private var breakDuration: Int {
        return `break`.duration
    }

    private var breakReasoning: String {
        return `break`.reasoning
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: `break`.time)
    }

    private var typeColor: Color {
        switch breakType {
        case .hydration: return .blue
        case .meal: return .orange
        case .rest: return .purple
        case .movement: return .green
        case .prep: return .cyan
        }
    }
}

// MARK: - Alerts Banner

struct AlertsBanner: View {
    let alerts: [Alert]

    var body: some View {
        if !alerts.isEmpty {
            VStack(spacing: 8) {
                ForEach(alerts) { alert in
                    AlertRow(alert: alert)
                }
            }
            .padding()
        }
    }
}

// MARK: - Alert Row

struct AlertRow: View {
    let alert: Alert

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(severityIcon)
                .font(.title3)

            Text(alert.message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(8)
    }

    private var severityIcon: String {
        switch alert.severity {
        case .critical: return "🚨"
        case .warning: return "⚠️"
        case .info: return "ℹ️"
        }
    }

    private var backgroundColor: Color {
        switch alert.severity {
        case .critical: return Color.red.opacity(0.1)
        case .warning: return Color.orange.opacity(0.1)
        case .info: return Color.blue.opacity(0.1)
        }
    }
}

// MARK: - Water Intake Widget

struct WaterIntakeWidget: View {
    let current: Double
    let goal: Double

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("💧 Water Intake")
                    .font(.headline)
                Spacer()
            }

            // Water Glasses Visualization
            WaterGlassesView(current: current, goal: goal)

            HStack {
                Text(String(format: "%.1fL / %.1fL", current, goal))
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text("\(percentageString)%")
                    .font(.headline)
                    .foregroundColor(progressColor)
            }

            if current < goal * 0.7 {
                Text("⚠️ Dehydration risk - drink water!")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private var percentageString: String {
        return String(format: "%.0f", (current / goal) * 100)
    }

    private var progressColor: Color {
        let progress = current / goal
        if progress >= 1.0 { return .green }
        if progress >= 0.7 { return .orange }
        return .red
    }
}

// MARK: - Water Glasses View

struct WaterGlassesView: View {
    let current: Double
    let goal: Double

    var body: some View {
        let glassesNeeded = Int(ceil(goal / 0.25)) // 250ml per glass
        let glassesFilled = Int(floor(current / 0.25))

        HStack(spacing: 4) {
            ForEach(0..<min(glassesNeeded, 12), id: \.self) { index in
                Image(systemName: index < glassesFilled ? "drop.fill" : "drop")
                    .foregroundColor(index < glassesFilled ? .blue : .gray.opacity(0.3))
            }
        }
    }
}

// MARK: - Section Card

struct SectionCard: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}
