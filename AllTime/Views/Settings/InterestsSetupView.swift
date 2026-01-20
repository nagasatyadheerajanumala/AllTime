import SwiftUI

struct InterestsSetupView: View {
    @StateObject private var viewModel = InterestsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingSaveSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Activity Interests
                    interestSection(
                        title: "Activities",
                        subtitle: "What physical activities do you enjoy?",
                        icon: "figure.run",
                        color: DesignSystem.Colors.emerald,
                        options: viewModel.activityOptions,
                        selected: viewModel.selectedActivities,
                        onToggle: viewModel.toggleActivity
                    )

                    // Lifestyle Interests
                    interestSection(
                        title: "Lifestyle",
                        subtitle: "What do you enjoy in your free time?",
                        icon: "book.fill",
                        color: DesignSystem.Colors.violet,
                        options: viewModel.lifestyleOptions,
                        selected: viewModel.selectedLifestyle,
                        onToggle: viewModel.toggleLifestyle
                    )

                    // Social Interests
                    interestSection(
                        title: "Social",
                        subtitle: "How do you like to spend time with others?",
                        icon: "person.3.fill",
                        color: DesignSystem.Colors.amber,
                        options: viewModel.socialOptions,
                        selected: viewModel.selectedSocial,
                        onToggle: viewModel.toggleSocial
                    )

                    // Preferences Section
                    preferencesSection

                    // Error Message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    // Save Button
                    saveButton

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Your Interests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
            .alert("Saved!", isPresented: $showingSaveSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your interests have been saved. You'll now see personalized suggestions!")
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "heart.fill")
                    .font(.system(size: 36))
                    .foregroundColor(DesignSystem.Colors.primary)
            }

            Text("Tell us what you love")
                .font(.title2.weight(.bold))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text("Select your interests to get personalized weekend and vacation suggestions")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Interest Section
    private func interestSection(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        options: [InterestOption],
        selected: Set<String>,
        onToggle: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                Spacer()
                if !selected.isEmpty {
                    Text("\(selected.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(color))
                }
            }

            // Options Grid
            FlowLayout(spacing: 8) {
                ForEach(options) { option in
                    InterestChip(
                        option: option,
                        isSelected: selected.contains(option.id),
                        color: color,
                        onTap: { onToggle(option.id) }
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // MARK: - Preferences Section
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekend Preferences")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.primaryText)

            // Pace Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Preferred Pace")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                Picker("Pace", selection: $viewModel.weekendPace) {
                    Text("Relaxed").tag("relaxed")
                    Text("Balanced").tag("balanced")
                    Text("Active").tag("active")
                }
                .pickerStyle(.segmented)
            }

            // Distance Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Travel Distance")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                Picker("Distance", selection: $viewModel.outingDistance) {
                    Text("Nearby").tag("nearby")
                    Text("Moderate").tag("moderate")
                    Text("Far").tag("willing_to_travel")
                }
                .pickerStyle(.segmented)
            }

            // Budget Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Budget")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                Picker("Budget", selection: $viewModel.budgetPreference) {
                    Text("Budget").tag("budget")
                    Text("Moderate").tag("moderate")
                    Text("Premium").tag("premium")
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // MARK: - Save Button
    private var saveButton: some View {
        Button(action: {
            Task {
                let success = await viewModel.saveInterests()
                if success {
                    showingSaveSuccess = true
                }
            }
        }) {
            HStack {
                if viewModel.isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save Interests")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(viewModel.hasAnySelection ? DesignSystem.Colors.primary : Color.gray)
            )
        }
        .disabled(!viewModel.hasAnySelection || viewModel.isSaving)
    }
}

// MARK: - Interest Chip
struct InterestChip: View {
    let option: InterestOption
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: 14))
                Text(option.name)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : DesignSystem.Colors.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? color : DesignSystem.Colors.cardBackground)
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : color.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Flow Layout (for wrapping chips)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, frame) in result.frames.enumerated() {
            let position = CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY)
            subviews[index].place(at: position, proposal: ProposedViewSize(frame.size))
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            var maxWidth_: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
                maxWidth_ = max(maxWidth_, currentX)
            }

            size = CGSize(width: maxWidth_, height: currentY + lineHeight)
        }
    }
}

// MARK: - Preview
#Preview {
    InterestsSetupView()
}
