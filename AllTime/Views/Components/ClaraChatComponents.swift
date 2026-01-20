import SwiftUI

// MARK: - Clara Chat Message Model
struct ClaraChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isClara: Bool
}

// MARK: - Clara Avatar
/// Reusable Clara avatar with consistent styling
struct ClaraAvatar: View {
    var size: CGFloat = DesignSystem.Components.chatAvatarSize

    var body: some View {
        ZStack {
            Circle()
                .fill(DesignSystem.Colors.claraGradientSimple)
                .frame(width: size, height: size)
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Clara Chat Bubble
struct ClaraChatBubble: View {
    let message: String
    let isClara: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm + 2) {
            if isClara {
                ClaraAvatar()

                Text(message)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .padding(DesignSystem.Components.chatBubblePadding)
                    .background(DesignSystem.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Components.chatBubbleRadius))

                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)

                Text(message)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(.white)
                    .padding(DesignSystem.Components.chatBubblePadding)
                    .background(DesignSystem.Colors.claraGradientSimple)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Components.chatBubbleRadius))
            }
        }
    }
}

// MARK: - Clara Typing Indicator
struct ClaraTypingIndicator: View {
    @State private var animatingDot = 0

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm + 2) {
            ClaraAvatar()

            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(DesignSystem.Colors.claraPurple.opacity(animatingDot == index ? 1 : 0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animatingDot == index ? 1.2 : 1)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Components.chatBubblePadding)
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Components.chatBubbleRadius))
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        animatingDot = (animatingDot + 1) % 3
                    }
                }
            }

            Spacer()
        }
    }
}

// MARK: - Clara Input Field
/// Reusable input field with Clara styling
struct ClaraInputField: View {
    @Binding var text: String
    var placeholder: String = "Type a message..."
    var onSubmit: () -> Void
    var isEnabled: Bool = true
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm + 4) {
            TextField(placeholder, text: $text)
                .font(.system(size: DesignSystem.FontSize.md))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit {
                    if !text.isEmpty && isEnabled {
                        onSubmit()
                    }
                }

            Button(action: {
                if !text.isEmpty && isEnabled {
                    onSubmit()
                }
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: DesignSystem.Components.iconXLarge))
                    .foregroundColor(text.isEmpty ? DesignSystem.Colors.tertiaryText : DesignSystem.Colors.claraPurple)
            }
            .disabled(text.isEmpty || !isEnabled)
        }
        .padding(DesignSystem.Components.inputFieldPadding)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Components.inputFieldRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Components.inputFieldRadius)
                .stroke(isFocused ? DesignSystem.Colors.claraPurple.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Clara Prompt Button
/// Button for predefined Clara prompts
struct ClaraPromptButton: View {
    let icon: String
    let iconColor: Color
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm + 2) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.Components.iconMedium))
                    .foregroundColor(iconColor)

                Text(label)
                    .font(.system(size: DesignSystem.FontSize.md, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Spacer()

                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: DesignSystem.Components.iconXLarge))
                    .foregroundColor(DesignSystem.Colors.claraPurple)
            }
            .padding(DesignSystem.Components.inputFieldPadding)
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Components.inputFieldRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Components.inputFieldRadius)
                    .stroke(DesignSystem.Colors.claraPurple.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Clara Navigation Title
/// Consistent Clara header for sheets
struct ClaraNavigationTitle: View {
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ClaraAvatar(size: DesignSystem.Components.avatarSmall)
            Text("Clara")
                .font(.system(size: DesignSystem.FontSize.lg, weight: .semibold))
        }
    }
}
