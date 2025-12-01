import SwiftUI

struct SuggestionCardView: View {
    let suggestion: HealthSuggestionItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with category and priority
            HStack {
                // Category badge
                HStack(spacing: 6) {
                    Image(systemName: suggestion.category.icon)
                        .font(.caption)
                    Text(suggestion.category.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(categoryColor)
                .cornerRadius(8)
                
                Spacer()
                
                // Priority indicator
                if suggestion.priority != .low {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(priorityColor)
                            .frame(width: 6, height: 6)
                        Text(suggestion.priority.displayName)
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(priorityColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            // Title
            Text(suggestion.title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            // Description
            Text(suggestion.description)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            // Estimated impact (if available)
            if let impact = suggestion.estimatedImpact {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption2)
                    Text(impact)
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
    
    private var categoryColor: Color {
        switch suggestion.category {
        case .sleep: return .indigo
        case .activity: return .blue
        case .heart: return .red
        case .nutrition: return .orange
        case .recovery: return .green
        case .stress: return .purple
        case .general: return .gray
        }
    }
    
    private var priorityColor: Color {
        switch suggestion.priority {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        case .urgent: return .purple
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SuggestionCardView(suggestion: HealthSuggestionItem(
            id: "1",
            title: "Improve Sleep Quality",
            description: "Your average sleep duration has decreased by 15% this week. Try going to bed 30 minutes earlier to maintain consistent sleep patterns.",
            category: .sleep,
            priority: .high,
            actionable: true,
            estimatedImpact: "High impact"
        ))
        
        SuggestionCardView(suggestion: HealthSuggestionItem(
            id: "2",
            title: "Increase Daily Steps",
            description: "You're averaging 7,500 steps per day. Aim for 10,000 steps to improve cardiovascular health.",
            category: .activity,
            priority: .medium,
            actionable: true,
            estimatedImpact: nil
        ))
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}

