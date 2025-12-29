import SwiftUI

// MARK: - Task Suggestion Card

/// Card displaying an AI-suggested task with accept/dismiss actions.
/// Users can tap + to add the task, or swipe to dismiss.
struct TaskSuggestionCard: View {
    let suggestion: TaskSuggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isDismissing = false
    @State private var isAccepting = false

    private let dismissThreshold: CGFloat = -100

    var body: some View {
        ZStack {
            // Dismiss background (shown when swiping left)
            HStack {
                Spacer()
                VStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("Dismiss")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(.trailing, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.red.opacity(0.8))
            .cornerRadius(16)
            .opacity(offset < -20 ? 1 : 0)

            // Main card content
            mainCardContent
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Only allow left swipe (negative translation)
                            if value.translation.width < 0 {
                                offset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.3)) {
                                if offset < dismissThreshold {
                                    // Trigger dismiss
                                    offset = -500
                                    isDismissing = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        onDismiss()
                                    }
                                } else {
                                    // Snap back
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .opacity(isDismissing || isAccepting ? 0 : 1)
        .scaleEffect(isAccepting ? 0.9 : 1)
        .animation(.easeOut(duration: 0.2), value: isAccepting)
    }

    // MARK: - Main Card Content

    private var mainCardContent: some View {
        HStack(spacing: 14) {
            // Category icon
            categoryIcon

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(suggestion.suggestedTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(2)

                // Description or reason
                if let description = suggestion.suggestedDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(2)
                } else {
                    Text(suggestion.suggestionTypeLabel)
                        .font(.caption)
                        .foregroundColor(suggestion.categoryColor.opacity(0.8))
                }

                // Metadata row
                metadataRow
            }

            Spacer()

            // Accept button
            acceptButton
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(suggestion.categoryColor.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Category Icon

    private var categoryIcon: some View {
        ZStack {
            Circle()
                .fill(suggestion.categoryColor.opacity(0.15))
                .frame(width: 44, height: 44)
            Image(systemName: suggestion.categoryIcon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(suggestion.categoryColor)
        }
    }

    // MARK: - Metadata Row

    private var metadataRow: some View {
        HStack(spacing: 12) {
            // Time slot
            if let timeSlot = suggestion.suggestedTimeSlot {
                Label(timeSlot.capitalized, systemImage: suggestion.timeSlotIcon)
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }

            // Duration
            if let duration = suggestion.formattedDuration {
                Label(duration, systemImage: "timer")
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }

            // Confidence indicator
            if suggestion.confidencePercentage > 70 {
                HStack(spacing: 2) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text("\(suggestion.confidencePercentage)%")
                        .font(.caption2.weight(.medium))
                }
                .foregroundColor(Color(hex: "F59E0B"))
            }
        }
    }

    // MARK: - Accept Button

    private var acceptButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                isAccepting = true
            }
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                onAccept()
            }
        }) {
            ZStack {
                Circle()
                    .fill(suggestion.categoryColor)
                    .frame(width: 40, height: 40)
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Task Suggestions Section

/// Section showing all task suggestions with header
struct TaskSuggestionsSection: View {
    let suggestions: [TaskSuggestion]
    let onAccept: (TaskSuggestion) -> Void
    let onDismiss: (TaskSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(Color(hex: "F59E0B"))
                Text("Suggested Tasks")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Spacer()
                Text("\(suggestions.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color(hex: "F59E0B"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(hex: "F59E0B").opacity(0.15))
                    )
            }

            // Suggestion cards
            ForEach(suggestions) { suggestion in
                TaskSuggestionCard(
                    suggestion: suggestion,
                    onAccept: { onAccept(suggestion) },
                    onDismiss: { onDismiss(suggestion) }
                )
            }

            // Hint text
            if !suggestions.isEmpty {
                Text("Tap + to add to your tasks, or swipe left to dismiss")
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            TaskSuggestionsSection(
                suggestions: [
                    TaskSuggestion(
                        id: 1,
                        userId: 1,
                        suggestedTitle: "Go to the gym",
                        suggestedDescription: "You typically work out on Mondays",
                        suggestedCategory: "fitness",
                        suggestedTags: nil,
                        suggestedTimeSlot: "morning",
                        suggestedDurationMinutes: 60,
                        suggestedPriority: "MEDIUM",
                        suggestedDate: "2024-01-15",
                        suggestionType: "recurring_pattern",
                        suggestionReason: "Based on your routine",
                        confidenceScore: 0.85,
                        status: .pending,
                        shownAt: nil,
                        shownCount: 0,
                        createdTaskId: nil
                    ),
                    TaskSuggestion(
                        id: 2,
                        userId: 1,
                        suggestedTitle: "Buy groceries",
                        suggestedDescription: nil,
                        suggestedCategory: "errands",
                        suggestedTags: nil,
                        suggestedTimeSlot: "afternoon",
                        suggestedDurationMinutes: 45,
                        suggestedPriority: "LOW",
                        suggestedDate: "2024-01-15",
                        suggestionType: "calendar_gap",
                        suggestionReason: "Free time detected",
                        confidenceScore: 0.72,
                        status: .pending,
                        shownAt: nil,
                        shownCount: 0,
                        createdTaskId: nil
                    )
                ],
                onAccept: { _ in print("Accepted") },
                onDismiss: { _ in print("Dismissed") }
            )
        }
        .padding()
    }
    .background(DesignSystem.Colors.background)
}
