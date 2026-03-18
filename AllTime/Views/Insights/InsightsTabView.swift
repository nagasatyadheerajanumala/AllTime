import SwiftUI

/// Insights Tab View - Main tab for viewing all insights
/// Professional, clean design with Clara AI branding
struct InsightsTabView: View {
    @State private var selectedSection: InsightsSection = .forecast

    enum InsightsSection: String, CaseIterable {
        case forecast = "Forecast"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        case health = "Health"

        var icon: String {
            switch self {
            case .forecast: return "sparkles"
            case .daily: return "sun.max.fill"
            case .weekly: return "calendar"
            case .monthly: return "tablecells"
            case .health: return "waveform.path.ecg.rectangle"
            }
        }

        var iconColor: Color {
            switch self {
            case .forecast: return .indigo
            case .daily: return .orange
            case .weekly: return .blue
            case .monthly: return .green
            case .health: return .red
            }
        }

        var description: String {
            switch self {
            case .forecast:
                // Mon-Thu: show this week; Fri-Sun: show next week
                let weekday = Calendar.current.component(.weekday, from: Date())
                return (weekday >= 2 && weekday <= 5) ? "This Week" : "Next Week"
            case .daily: return "Today"
            case .weekly: return "7 days"
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
                case .forecast:
                    ForecastView()
                case .daily:
                    DailyInsightsView()
                case .weekly:
                    WeeklyInsightsView()
                case .monthly:
                    LifeInsightsView()
                case .health:
                    HealthInsightsTabContent()
                }
            }
        }
        .background(DesignSystem.Colors.background)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToDailyInsights)) { _ in
            withAnimation {
                selectedSection = .daily
            }
        }
        .onAppear {
            // Fallback: if navigated here via deep link, check insightsSection
            if let section = NavigationManager.shared.insightsSection {
                if section == "daily" { selectedSection = .daily }
                else if section == "weekly" { selectedSection = .weekly }
                else if section == "health" { selectedSection = .health }
                NavigationManager.shared.insightsSection = nil
            }
        }
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(InsightsSection.allCases, id: \.self) { section in
                    sectionButton(section)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenMargin)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.background)
    }

    private func sectionButton(_ section: InsightsSection) -> some View {
        let isSelected = selectedSection == section

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSection = section
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            VStack(spacing: 6) {
                Image(systemName: section.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isSelected ? .white : section.iconColor)
                Text(section.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : DesignSystem.Colors.primaryText)
                Text(section.description)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : DesignSystem.Colors.tertiaryText)
            }
            .frame(width: 72, height: 72)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(isSelected ? section.iconColor : DesignSystem.Colors.cardBackground)
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

// MARK: - Forecast View (Next Week Insights)
// Simply wraps WeeklyInsightsView in "Next Week" mode - no week picker, just next week content

struct ForecastView: View {
    var body: some View {
        WeeklyInsightsView(forceNextWeekMode: true)
    }
}
