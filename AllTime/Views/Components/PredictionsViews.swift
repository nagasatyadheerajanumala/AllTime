import SwiftUI

// MARK: - Predictions Tile Content
struct PredictionsTileContent: View {
    let predictions: PredictionsResponse?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Main capacity display
            if let capacity = predictions?.capacity {
                HStack(spacing: 6) {
                    Image(systemName: capacity.capacityIcon)
                        .font(.title3)
                    Text(capacity.capacityDisplayText)
                        .font(.headline)
                        .foregroundColor(.white)
                }

                // Capacity bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.8))
                            .frame(width: geometry.size.width * min(capacity.capacityPercentage / 100, 1.0), height: 6)
                    }
                }
                .frame(height: 6)
            } else {
                Text("No capacity data")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Spacer(minLength: 0)

            // Stats row
            HStack(spacing: DesignSystem.Spacing.md) {
                if let travel = predictions?.travelPredictions, !travel.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "car.fill")
                            .font(.caption2)
                        Text("\(travel.count)")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.15)))
                }

                if let warnings = predictions?.warningCount, warnings > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("\(warnings)")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(Color(hex: "FEF2F2"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.15)))
                }

                Spacer()
            }
        }
    }
}

// MARK: - Predictions Detail View
struct PredictionsDetailView: View {
    @StateObject private var viewModel = PredictionsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Today.sectionSpacing) {
                    // Capacity Overview Card
                    if let capacity = viewModel.predictions?.capacity {
                        capacityCard(capacity: capacity)
                    }

                    // Travel Predictions
                    if let travel = viewModel.predictions?.travelPredictions, !travel.isEmpty {
                        travelSection(predictions: travel)
                    }

                    // Warnings
                    if let capacity = viewModel.predictions?.capacity, !capacity.warnings.isEmpty {
                        warningsSection(warnings: capacity.warnings)
                    }

                    // Recommendations
                    if let capacity = viewModel.predictions?.capacity, !capacity.recommendations.isEmpty {
                        recommendationsSection(recommendations: capacity.recommendations)
                    }

                    // Patterns
                    if let patterns = viewModel.predictions?.patterns, !patterns.isEmpty {
                        patternsSection(patterns: patterns)
                    }

                    Spacer(minLength: DesignSystem.Spacing.xl)
                }
                .padding(.horizontal, DesignSystem.Spacing.screenMargin)
                .padding(.top, DesignSystem.Spacing.md)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.body.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .presentationDragIndicator(.visible)
        .task {
            await viewModel.fetchPredictions()
        }
    }

    // MARK: - Capacity Card
    private func capacityCard(capacity: CapacityPrediction) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                Image(systemName: capacity.capacityIcon)
                    .font(.title2)
                    .foregroundColor(Color(hex: capacity.capacityColor))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Capacity")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    Text(capacity.capacityDisplayText)
                        .font(.title2.weight(.bold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                }

                Spacer()

                // Percentage badge
                Text("\(Int(capacity.capacityPercentage))%")
                    .font(.headline.weight(.bold))
                    .foregroundColor(Color(hex: capacity.capacityColor))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(hex: capacity.capacityColor).opacity(0.15))
                    )
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: capacity.capacityColor).opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: capacity.capacityColor))
                        .frame(width: geometry.size.width * min(capacity.capacityPercentage / 100, 1.0), height: 8)
                }
            }
            .frame(height: 8)

            // Stats grid
            HStack(spacing: DesignSystem.Spacing.md) {
                statItem(icon: "calendar", value: "\(capacity.meetingCount)", label: "Meetings")
                statItem(icon: "clock", value: capacity.formattedDuration, label: "Total Time")
                statItem(icon: "arrow.right.arrow.left", value: "\(capacity.backToBackCount)", label: "Back-to-back")
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)
            Text(label)
                .font(.caption2)
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Travel Section
    private func travelSection(predictions: [TravelPrediction]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(icon: "car.fill", title: "Travel Alerts", color: Color(hex: "3B82F6"))

            ForEach(predictions) { prediction in
                travelRow(prediction: prediction)
            }
        }
    }

    private func travelRow(prediction: TravelPrediction) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Traffic indicator
            Circle()
                .fill(Color(hex: prediction.trafficColor))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(prediction.eventTitle ?? "Event")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(1)

                if let location = prediction.eventLocation {
                    Text(location)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Leave by")
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                Text(prediction.formattedLeaveBy)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // MARK: - Warnings Section
    private func warningsSection(warnings: [CapacityWarning]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(icon: "exclamationmark.triangle.fill", title: "Warnings", color: Color(hex: "F59E0B"))

            ForEach(warnings) { warning in
                warningRow(warning: warning)
            }
        }
    }

    private func warningRow(warning: CapacityWarning) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: warning.severityIcon)
                .font(.title3)
                .foregroundColor(Color(hex: warning.severityColor))
                .frame(width: 32)

            Text(warning.message)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(Color(hex: warning.severityColor).opacity(0.1))
        )
    }

    // MARK: - Recommendations Section
    private func recommendationsSection(recommendations: [String]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(icon: "lightbulb.fill", title: "Recommendations", color: Color(hex: "10B981"))

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                ForEach(recommendations, id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(Color(hex: "10B981"))
                            .padding(.top, 2)

                        Text(recommendation)
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(DesignSystem.Colors.cardBackground)
            )
        }
    }

    // MARK: - Patterns Section
    private func patternsSection(patterns: [EventPattern]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(icon: "repeat", title: "Detected Patterns", color: Color(hex: "8B5CF6"))

            ForEach(patterns) { pattern in
                patternRow(pattern: pattern)
            }
        }
    }

    private func patternRow(pattern: EventPattern) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Pattern icon
            ZStack {
                Circle()
                    .fill(Color(hex: "8B5CF6").opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "repeat")
                    .font(.body)
                    .foregroundColor(Color(hex: "8B5CF6"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(pattern.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(1)

                Text(pattern.formattedDaysOfWeek)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            Spacer()

            // Confidence badge
            Text(pattern.confidenceText)
                .font(.caption2.weight(.medium))
                .foregroundColor(Color(hex: "8B5CF6"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(hex: "8B5CF6").opacity(0.15))
                )
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // MARK: - Section Header
    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(color)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.secondaryText)
            Spacer()
        }
    }
}

// MARK: - Predictions Tile Type Extension
/// Adds the insights tile type alongside existing tiles
enum PredictionsTileType {
    case insights

    var title: String { "Insights" }
    var icon: String { "chart.line.uptrend.xyaxis" }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "8B5CF6"), Color(hex: "6D28D9")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Preview
#Preview {
    PredictionsDetailView()
}
