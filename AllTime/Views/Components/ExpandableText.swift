import SwiftUI

// MARK: - Expandable Text Component
// A reusable text component that shows "Show More / Show Less" for long text

struct ExpandableText: View {
    let text: String
    let lineLimit: Int
    let font: Font
    let foregroundColor: Color
    let lineSpacing: CGFloat

    @State private var isExpanded = false
    @State private var isTruncated = false

    init(
        _ text: String,
        lineLimit: Int = 3,
        font: Font = .caption,
        foregroundColor: Color = DesignSystem.Colors.secondaryText,
        lineSpacing: CGFloat = 3
    ) {
        self.text = text
        self.lineLimit = lineLimit
        self.font = font
        self.foregroundColor = foregroundColor
        self.lineSpacing = lineSpacing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(font)
                .foregroundColor(foregroundColor)
                .lineSpacing(lineSpacing)
                .lineLimit(isExpanded ? nil : lineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    // Invisible view to measure if text is truncated
                    GeometryReader { visibleGeo in
                        ZStack {
                            Text(text)
                                .font(font)
                                .lineSpacing(lineSpacing)
                                .fixedSize(horizontal: false, vertical: true)
                                .background(
                                    GeometryReader { fullGeo in
                                        Color.clear.onAppear {
                                            // If full text height > visible height, it's truncated
                                            isTruncated = fullGeo.size.height > visibleGeo.size.height + 10
                                        }
                                    }
                                )
                        }
                        .frame(height: .infinity)
                        .hidden()
                    }
                )

            // Show More/Less button only if text is long enough
            if shouldShowToggle {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Show Less" : "Show More")
                            .font(.caption.weight(.medium))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var shouldShowToggle: Bool {
        // Show toggle if text is longer than threshold (approximately)
        text.count > 120 || isTruncated
    }
}

// MARK: - Non-Truncating Text Modifier
// Apply to any Text view to ensure it never truncates

struct NonTruncatingText: ViewModifier {
    func body(content: Content) -> some View {
        content
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
    }
}

extension View {
    func nonTruncating() -> some View {
        modifier(NonTruncatingText())
    }
}

// MARK: - Expandable Card Container
// Wrapper for cards that ensures they expand to fit content

struct ExpandableCardContainer<Content: View>: View {
    let content: Content
    let backgroundColor: Color
    let borderColor: Color
    let cornerRadius: CGFloat

    init(
        backgroundColor: Color = DesignSystem.Colors.cardBackground,
        borderColor: Color = DesignSystem.Colors.tertiaryText.opacity(0.1),
        cornerRadius: CGFloat = DesignSystem.CornerRadius.md,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            )
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Simple Expandable Text (State-based)
// A simpler version that uses character count threshold

struct SimpleExpandableText: View {
    let text: String
    let threshold: Int
    let collapsedLines: Int
    let font: Font
    let foregroundColor: Color

    @State private var isExpanded = false

    init(
        _ text: String,
        threshold: Int = 150,
        collapsedLines: Int = 3,
        font: Font = .caption,
        foregroundColor: Color = DesignSystem.Colors.secondaryText
    ) {
        self.text = text
        self.threshold = threshold
        self.collapsedLines = collapsedLines
        self.font = font
        self.foregroundColor = foregroundColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(font)
                .foregroundColor(foregroundColor)
                .lineSpacing(3)
                .lineLimit(isExpanded ? nil : collapsedLines)
                .fixedSize(horizontal: false, vertical: true)

            if text.count > threshold {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Show Less" : "Show More")
                            .font(.caption.weight(.medium))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Full Text View (Never Truncates)
// For text that should always show in full

struct FullText: View {
    let text: String
    let font: Font
    let foregroundColor: Color
    let lineSpacing: CGFloat

    init(
        _ text: String,
        font: Font = .caption,
        foregroundColor: Color = DesignSystem.Colors.secondaryText,
        lineSpacing: CGFloat = 3
    ) {
        self.text = text
        self.font = font
        self.foregroundColor = foregroundColor
        self.lineSpacing = lineSpacing
    }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(foregroundColor)
            .lineSpacing(lineSpacing)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
    }
}

// MARK: - Previews

#Preview("Expandable Text - Short") {
    VStack(spacing: 20) {
        ExpandableText("Short text that doesn't need expansion.")

        ExpandableText(
            "This is a much longer text that should definitely show the expand/collapse button because it contains a lot of information that the user might want to read in full. It includes multiple sentences and provides detailed context about something important.",
            lineLimit: 2
        )
    }
    .padding()
    .background(DesignSystem.Colors.background)
}

#Preview("Simple Expandable Text") {
    VStack(spacing: 20) {
        SimpleExpandableText("Short text")

        SimpleExpandableText(
            "This is a much longer text that demonstrates the expandable functionality. When the text exceeds the threshold, users will see a 'Show More' button that they can tap to reveal the full content. This creates a cleaner UI while still allowing users to access all the information.",
            threshold: 100
        )
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
