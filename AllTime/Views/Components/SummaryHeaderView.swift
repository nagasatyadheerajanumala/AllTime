import SwiftUI

struct SummaryHeaderView: View {
    let summary: HealthSummary
    let expiresAt: Date?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Overview text
            Text(summary.overview)
                .font(.body)
                .foregroundColor(DesignSystem.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            // Key metrics grid
            if !keyMetrics.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Key Metrics")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(keyMetrics, id: \.label) { metric in
                            MetricCard(label: metric.label, value: metric.value, unit: metric.unit)
                        }
                    }
                }
            }
            
            // Trends
            if !summary.trends.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Trends")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    
                    ForEach(summary.trends) { trend in
                        TrendRow(trend: trend)
                    }
                }
            }
            
            // Expiration info
            if let expiresAt = expiresAt {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(expirationText(expiresAt))
                        .font(.caption)
                }
                .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
    
    private var keyMetrics: [(label: String, value: String, unit: String)] {
        var metrics: [(String, String, String)] = []
        
        if let steps = summary.keyMetrics.averageSteps {
            metrics.append(("Steps", String(format: "%.0f", steps), ""))
        }
        if let sleep = summary.keyMetrics.averageSleepHours {
            metrics.append(("Sleep", String(format: "%.1f", sleep), "hrs"))
        }
        if let active = summary.keyMetrics.averageActiveMinutes {
            metrics.append(("Active", String(format: "%.0f", active), "min"))
        }
        if let rhr = summary.keyMetrics.averageRestingHeartRate {
            metrics.append(("RHR", String(format: "%.0f", rhr), "bpm"))
        }
        if let hrv = summary.keyMetrics.averageHRV {
            metrics.append(("HRV", String(format: "%.0f", hrv), "ms"))
        }
        if let energy = summary.keyMetrics.averageActiveEnergy {
            metrics.append(("Energy", String(format: "%.0f", energy), "kcal"))
        }
        
        return metrics
    }
    
    private func expirationText(_ date: Date) -> String {
        let now = Date()
        if date <= now {
            return "Expired"
        }
        
        let interval = date.timeIntervalSince(now)
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "Expires in \(hours)h \(minutes)m"
        } else {
            return "Expires in \(minutes)m"
        }
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let label: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemGroupedBackground))
        )
    }
}

// MARK: - Trend Row

struct TrendRow: View {
    let trend: TrendItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Trend indicator
            Image(systemName: trendIcon)
                .font(.caption)
                .foregroundColor(trendColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(trend.metric.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Text(trend.description)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            
            Spacer()
            
            if let change = trend.changePercentage {
                Text(String(format: "%.1f%%", change))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(trendColor)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(trendColor.opacity(0.1))
        )
    }
    
    private var trendIcon: String {
        switch trend.direction {
        case "improving": return "arrow.up.right"
        case "declining": return "arrow.down.right"
        default: return "arrow.right"
        }
    }
    
    private var trendColor: Color {
        switch trend.direction {
        case "improving": return .green
        case "declining": return .red
        default: return .gray
        }
    }
}

#Preview {
    SummaryHeaderView(
        summary: HealthSummary(
            overview: "This week you've shown consistent activity levels with an average of 8,500 steps per day. Your sleep quality has improved, averaging 7.5 hours per night.",
            keyMetrics: KeyMetrics(
                averageSteps: 8500,
                averageSleepHours: 7.5,
                averageActiveMinutes: 45,
                averageRestingHeartRate: 58,
                averageHRV: 52,
                averageActiveEnergy: 450
            ),
            trends: [
                TrendItem(
                    id: "1",
                    metric: "sleep",
                    direction: "improving",
                    changePercentage: 12.5,
                    description: "Sleep duration increased"
                ),
                TrendItem(
                    id: "2",
                    metric: "activity",
                    direction: "stable",
                    changePercentage: 2.1,
                    description: "Activity levels consistent"
                )
            ],
            suggestions: []
        ),
        expiresAt: Date().addingTimeInterval(3600)
    )
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}

