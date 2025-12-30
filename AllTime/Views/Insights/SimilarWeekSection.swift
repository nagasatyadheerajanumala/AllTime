import SwiftUI
import Combine

// MARK: - Similar Week Alert Section (for WeeklyInsightsView)

struct SimilarWeekSection: View {
    @StateObject private var viewModel = SimilarWeekViewModel()
    @State private var isExpanded = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.insight == nil {
                // Initial loading - show nothing
                EmptyView()
            } else if let insight = viewModel.insight, insight.hasSimilarWeek {
                similarWeekCard(insight)
            }
            // If no similar week, show nothing
        }
        .task {
            await viewModel.fetchSimilarWeek()
        }
    }

    // MARK: - Similar Week Card

    @ViewBuilder
    private func similarWeekCard(_ insight: SimilarWeekInsight) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "6366F1").opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "6366F1"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Similar Week Detected")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    if let match = insight.similarWeek {
                        Text("This week looks like \(match.weekOf)")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }

                Spacer()

                // Similarity badge
                if let match = insight.similarWeek {
                    Text(match.similarityPercentage)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "6366F1"))
                        .cornerRadius(6)
                }
            }

            // Pattern description
            if let pattern = insight.currentPattern, !pattern.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text(pattern)
                        .font(.caption)
                }
                .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            // Prediction (the key insight)
            if let prediction = insight.prediction, !prediction.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(Color(hex: "F59E0B"))

                    Text(prediction)
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "F59E0B").opacity(0.1))
                .cornerRadius(8)
            }

            // Expandable health outcomes
            if let outcomes = insight.thatWeekOutcomes {
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    HStack {
                        Text(isExpanded ? "Hide Details" : "View Week Details")
                            .font(.caption.weight(.medium))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                }

                if isExpanded {
                    healthOutcomesView(outcomes)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // Recommendation
            if let recommendation = insight.recommendation, !recommendation.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundColor(Color(hex: "10B981"))

                    Text(recommendation)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(Color(hex: "6366F1").opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Health Outcomes View

    @ViewBuilder
    private func healthOutcomesView(_ outcomes: HealthOutcome) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Sleep
                if outcomes.avgSleep != nil {
                    VStack(spacing: 4) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "8B5CF6"))
                        Text(outcomes.formattedSleep)
                            .font(.headline)
                        if let vs = outcomes.sleepVsBaseline, vs != "normal" {
                            Text(vs)
                                .font(.caption2)
                                .foregroundColor(vs.hasPrefix("-") ? Color(hex: "EF4444") : Color(hex: "10B981"))
                        }
                        Text("Sleep")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Steps
                if outcomes.avgSteps != nil {
                    VStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "22C55E"))
                        Text(outcomes.formattedSteps)
                            .font(.headline)
                        if let vs = outcomes.stepsVsBaseline, vs != "normal" {
                            Text(vs)
                                .font(.caption2)
                                .foregroundColor(vs.hasPrefix("-") ? Color(hex: "EF4444") : Color(hex: "10B981"))
                        }
                        Text("Steps")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Stress
                if let stress = outcomes.stressIndicator, stress != "unknown" {
                    VStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 20))
                            .foregroundColor(outcomes.stressColor)
                        Text(stress.capitalized)
                            .font(.headline)
                        Text("Stress")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(12)
        .background(Color(hex: "6366F1").opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - ViewModel

@MainActor
class SimilarWeekViewModel: ObservableObject {
    @Published var insight: SimilarWeekInsight?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService()

    func fetchSimilarWeek() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            print("🔍 SimilarWeekViewModel: Fetching similar week insight...")
            insight = try await apiService.getSimilarWeekInsight()
            print("✅ SimilarWeekViewModel: Got response - hasSimilarWeek: \(insight?.hasSimilarWeek ?? false)")
            if let insight = insight {
                print("   - similarWeek: \(insight.similarWeek?.weekOf ?? "nil")")
                print("   - prediction: \(insight.prediction ?? "nil")")
            }
        } catch {
            print("❌ SimilarWeekViewModel: Failed to fetch similar week: \(error)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        SimilarWeekSection()
            .padding()
    }
    .background(DesignSystem.Colors.background)
}
