import SwiftUI

/// Insights Tab View - Main tab for viewing all insights
/// Professional, clean design with Clara AI branding
struct InsightsTabView: View {
    @State private var selectedSection: InsightsSection = .weekly

    enum InsightsSection: String, CaseIterable {
        case weekly = "Weekly"
        case nextWeek = "Next Week"
        case monthly = "Monthly"
        case health = "Health"

        var icon: String {
            switch self {
            case .weekly: return "calendar.badge.clock"
            case .nextWeek: return "arrow.right.circle"
            case .monthly: return "calendar.circle"
            case .health: return "heart.fill"
            }
        }

        var description: String {
            switch self {
            case .weekly: return "7 days"
            case .nextWeek: return "Upcoming"
            case .monthly: return "30-60 days"
            case .health: return "Wellness"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Section Picker
            sectionPicker

            // Content
            Group {
                switch selectedSection {
                case .weekly:
                    WeeklyInsightsView()
                case .nextWeek:
                    NextWeekInsightsView()
                case .monthly:
                    LifeInsightsView()
                case .health:
                    HealthInsightsTabContent()
                }
            }
        }
        .background(DesignSystem.Colors.background)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Insights")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Text("Understand your patterns")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            Spacer()

            // Clara AI indicator with refined styling
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                Text("Clara")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [DesignSystem.Colors.indigo, DesignSystem.Colors.violet],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: DesignSystem.Colors.indigo.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal, DesignSystem.Spacing.screenMargin)
        .padding(.top, DesignSystem.Spacing.md)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }

    private var sectionPicker: some View {
        HStack(spacing: 6) {
            ForEach(InsightsSection.allCases, id: \.self) { section in
                sectionButton(section)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.screenMargin)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.background)
    }

    private func sectionButton(_ section: InsightsSection) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSection = section
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            VStack(spacing: 3) {
                Image(systemName: section.icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(section.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(selectedSection == section ? .white : DesignSystem.Colors.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(selectedSection == section ?
                          LinearGradient(colors: [DesignSystem.Colors.primary, DesignSystem.Colors.primaryDark], startPoint: .topLeading, endPoint: .bottomTrailing) :
                          LinearGradient(colors: [DesignSystem.Colors.cardBackground, DesignSystem.Colors.cardBackground], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(selectedSection == section ? Color.clear : DesignSystem.Colors.calmBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    InsightsTabView()
        .preferredColorScheme(.dark)
}
