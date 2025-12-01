import SwiftUI

struct HealthGoalsSectionView: View {
    let goals: UserHealthGoals
    let suggestions: [HealthSuggestionItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Image(systemName: "target")
                    .font(.title3)
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text("Your Health Goals")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Spacer()
            }
            
            // Goals display
            VStack(spacing: 12) {
                if let sleep = goals.sleepHours {
                    GoalProgressRow(
                        label: "Sleep",
                        current: nil, // We don't have current value in this context
                        goal: sleep,
                        unit: "hours",
                        icon: "bed.double.fill",
                        color: .indigo
                    )
                }
                
                if let steps = goals.steps {
                    GoalProgressRow(
                        label: "Daily Steps",
                        current: nil,
                        goal: Double(steps),
                        unit: "steps",
                        icon: "figure.walk",
                        color: .blue
                    )
                }
                
                if let activeMinutes = goals.activeMinutes {
                    GoalProgressRow(
                        label: "Active Minutes",
                        current: nil,
                        goal: Double(activeMinutes),
                        unit: "min",
                        icon: "figure.run",
                        color: .green
                    )
                }
                
                if let energy = goals.activeEnergyBurned {
                    GoalProgressRow(
                        label: "Active Energy",
                        current: nil,
                        goal: energy,
                        unit: "kcal",
                        icon: "flame.fill",
                        color: .orange
                    )
                }
                
                if let rhr = goals.restingHeartRate {
                    GoalProgressRow(
                        label: "Resting Heart Rate",
                        current: nil,
                        goal: rhr,
                        unit: "bpm",
                        icon: "heart.fill",
                        color: .red
                    )
                }
                
                if let hrv = goals.hrv {
                    GoalProgressRow(
                        label: "HRV",
                        current: nil,
                        goal: hrv,
                        unit: "ms",
                        icon: "waveform.path.ecg",
                        color: .purple
                    )
                }
            }
            
            // Suggestions to achieve goals
            if !suggestions.isEmpty {
                Divider()
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.warning)
                        
                        Text("Suggestions to Achieve Your Goals")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }
                    
                    ForEach(suggestions.prefix(3)) { suggestion in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.primary)
                                .padding(.top, 2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(suggestion.title)
                                    .font(DesignSystem.Typography.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                
                                Text(suggestion.description)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Goal Progress Row

struct GoalProgressRow: View {
    let label: String
    let current: Double?
    let goal: Double
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
                .frame(width: 24)
            
            // Label and value
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if let current = current {
                        Text(String(format: "%.1f", current))
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        Text("/")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                    Text(String(format: formatString, goal))
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.primary)
                    Text(unit)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
            
            Spacer()
            
            // Goal badge
            Text("Goal")
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(color)
                )
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemGroupedBackground))
        )
    }
    
    private var formatString: String {
        if goal < 1 {
            return "%.1f"
        } else if goal < 100 {
            return "%.0f"
        } else {
            return "%.0f"
        }
    }
}

#Preview {
    HealthGoalsSectionView(
        goals: UserHealthGoals(
            sleepHours: 8.0,
            activeEnergyBurned: 500.0,
            hrv: 50.0,
            restingHeartRate: 60.0,
            activeMinutes: 30,
            steps: 10000,
            updatedAt: Date()
        ),
        suggestions: [
            HealthSuggestionItem(
                id: "1",
                title: "Increase Daily Steps",
                description: "Aim for 10,000 steps per day by taking short walks throughout the day.",
                category: .activity,
                priority: .high,
                actionable: true,
                estimatedImpact: "High impact"
            ),
            HealthSuggestionItem(
                id: "2",
                title: "Improve Sleep Quality",
                description: "Maintain a consistent sleep schedule and aim for 8 hours of sleep.",
                category: .sleep,
                priority: .medium,
                actionable: true,
                estimatedImpact: nil
            )
        ]
    )
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}

