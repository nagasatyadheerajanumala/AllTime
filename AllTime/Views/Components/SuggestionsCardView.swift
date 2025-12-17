import SwiftUI
import Combine

/// Displays personalized suggestions based on energy and mood
struct SuggestionsCardView: View {
    @StateObject private var viewModel = SuggestionsViewModel()
    let energyLevel: Int
    let mood: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)

                Text("Suggestions for You")
                    .font(.headline)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if let response = viewModel.suggestions {
                // Message from the system
                if !response.message.isEmpty {
                    Text(response.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Suggestions list
                VStack(spacing: 10) {
                    ForEach(response.suggestions) { suggestion in
                        SuggestionRow(suggestion: suggestion)
                    }
                }
            } else if let error = viewModel.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if !viewModel.isLoading {
                Text("Loading personalized suggestions...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .task {
            await viewModel.loadSuggestions(energyLevel: energyLevel, mood: mood)
        }
        .onChange(of: energyLevel) { _, newValue in
            Task {
                await viewModel.loadSuggestions(energyLevel: newValue, mood: mood)
            }
        }
        .onChange(of: mood) { _, newValue in
            Task {
                await viewModel.loadSuggestions(energyLevel: energyLevel, mood: newValue)
            }
        }
    }
}

// MARK: - Suggestion Row

struct SuggestionRow: View {
    let suggestion: MoodSuggestion
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main row
            HStack(alignment: .top, spacing: 12) {
                // Icon
                Image(systemName: suggestion.sfSymbolName)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 28)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(suggestion.title)
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)

                        Spacer()

                        // Duration badge
                        if let duration = suggestion.durationText {
                            Text(duration)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemGray5))
                                )
                        }

                        // Priority indicator
                        if suggestion.priority == "high" {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                        }
                    }

                    // Description (expandable)
                    Text(suggestion.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }

            // Category badge
            HStack {
                Text(suggestion.categoryDisplayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray6))
                    )

                Spacer()

                if !isExpanded {
                    Text("Tap for more")
                        .font(.caption2)
                        .foregroundColor(.blue.opacity(0.7))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }

    var iconColor: Color {
        switch suggestion.category {
        case "activity": return .green
        case "nutrition": return .orange
        case "sleep": return .purple
        case "break": return .blue
        case "productivity": return .indigo
        case "wellness": return .pink
        case "social": return .red
        case "insight": return .cyan
        case "calendar": return .blue
        default: return .gray
        }
    }
}

// MARK: - ViewModel

@MainActor
class SuggestionsViewModel: ObservableObject {
    @Published var suggestions: MoodSuggestionsResponse?
    @Published var isLoading = false
    @Published var error: String?

    private let checkInService = CheckInService.shared

    func loadSuggestions(energyLevel: Int, mood: String) async {
        isLoading = true
        error = nil

        do {
            suggestions = try await checkInService.getSuggestions(
                energyLevel: energyLevel,
                mood: mood,
                timeOfDay: nil // Let backend auto-detect
            )
        } catch {
            self.error = "Unable to load suggestions"
            print("Failed to load suggestions: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Compact Suggestion View (for inline display)

struct CompactSuggestionView: View {
    let suggestion: MoodSuggestion

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: suggestion.sfSymbolName)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(suggestion.title)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            if let duration = suggestion.durationText {
                Text(duration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        SuggestionsCardView(energyLevel: 2, mood: "tired")
        SuggestionsCardView(energyLevel: 4, mood: "good")
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
