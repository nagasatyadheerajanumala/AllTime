import SwiftUI
import Combine

// MARK: - Energy Patterns Section (for WeeklyInsightsView)

struct EnergyPatternsSection: View {
    @StateObject private var viewModel = EnergyPatternsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.violet.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.violet)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Energy Patterns")
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    if viewModel.isLoaded {
                        Text(viewModel.analysisWindow)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.md)

            // Content
            if viewModel.isLoading && viewModel.patterns.isEmpty {
                loadingContent
            } else if !viewModel.hasEnoughData {
                insufficientDataContent
            } else if viewModel.patterns.isEmpty {
                noPatternDetectedContent
            } else {
                patternsContent
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5)
                )
        )
        .task {
            await viewModel.fetchPatterns()
        }
    }

    // MARK: - Content Views

    private var loadingContent: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Analyzing your patterns...")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var insufficientDataContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundColor(DesignSystem.Colors.tertiaryText)

            Text("More Data Needed")
                .font(.subheadline.weight(.medium))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text("Keep syncing your health data and calendar to discover your energy patterns.")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }

    private var noPatternDetectedContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(DesignSystem.Colors.emerald)

            Text("No Impact Detected")
                .font(.subheadline.weight(.medium))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text("Your meeting schedule doesn't appear to significantly impact your health metrics. Keep it up!")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }

    private var patternsContent: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(viewModel.patterns) { pattern in
                EnergyPatternCard(pattern: pattern)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.bottom, DesignSystem.Spacing.md)
    }
}

// MARK: - Energy Pattern Card

struct EnergyPatternCard: View {
    let pattern: EnergyPatternInsight

    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: Pattern name and significance badge
            HStack(alignment: .top) {
                // Pattern icon and name
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(pattern.iconColor.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: pattern.sfSymbol)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(pattern.iconColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(pattern.pattern)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        Text(pattern.metricDisplayName)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }

                Spacer()

                // Significance badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(pattern.significanceColor)
                        .frame(width: 6, height: 6)
                    Text(pattern.significanceLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(pattern.significanceColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(pattern.significanceColor.opacity(0.1))
                )
            }

            // Impact display
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(pattern.impact)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(pattern.isNegativeImpact ? DesignSystem.Colors.errorRed : DesignSystem.Colors.emerald)

                Text(pattern.comparison)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            // Sample size indicator
            HStack(spacing: 4) {
                Image(systemName: "calendar.badge.clock")
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                Text("Based on \(pattern.sampleSize) days")
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)

                if let description = pattern.patternDescription, !description.isEmpty {
                    Spacer()
                    Button(action: { showDetail.toggle() }) {
                        Image(systemName: showDetail ? "chevron.up" : "info.circle")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                }
            }

            // Expandable detail
            if showDetail, let description = pattern.patternDescription {
                Text(description)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(pattern.iconColor.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .stroke(pattern.iconColor.opacity(0.1), lineWidth: 0.5)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: showDetail)
    }
}

// MARK: - ViewModel

@MainActor
class EnergyPatternsViewModel: ObservableObject {
    @Published var patterns: [EnergyPatternInsight] = []
    @Published var isLoading = false
    @Published var hasEnoughData = true
    @Published var analysisWindow = ""
    @Published var errorMessage: String?

    var isLoaded: Bool {
        !isLoading && (patterns.isEmpty == false || !hasEnoughData)
    }

    private let apiService = APIService()

    func fetchPatterns() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            print("🔋 EnergyPatternsViewModel: Fetching energy patterns...")
            let response = try await apiService.fetchEnergyPatterns()
            patterns = response.patterns
            hasEnoughData = response.hasEnoughData
            analysisWindow = response.analysisWindow
            print("✅ EnergyPatternsViewModel: Got response - patterns count: \(patterns.count), hasEnoughData: \(hasEnoughData)")
            for pattern in patterns.prefix(3) {
                print("   - \(pattern.pattern): \(pattern.impact) on \(pattern.metric)")
            }
        } catch {
            print("❌ EnergyPatternsViewModel: Failed to fetch patterns: \(error)")
            errorMessage = error.localizedDescription
            // Keep hasEnoughData true so we don't show "more data needed" on error
        }

        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        EnergyPatternsSection()
            .padding()
    }
    .background(DesignSystem.Colors.background)
}
