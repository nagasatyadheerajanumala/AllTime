import SwiftUI

/// A beautiful color picker for event colors
struct EventColorPicker: View {
    @Binding var selectedColor: String
    var onColorSelected: ((String) -> Void)?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(EventColorPalette.colors, id: \.hex) { color in
                    ColorCircle(
                        hex: color.hex,
                        isSelected: selectedColor == color.hex,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedColor = color.hex
                                // Haptic feedback
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                onColorSelected?(color.hex)
                            }
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

/// Single color circle in the picker
struct ColorCircle: View {
    let hex: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 40, height: 40)
                    .shadow(color: Color(hex: hex).opacity(0.4), radius: isSelected ? 4 : 0, x: 0, y: 2)

                if isSelected {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 2)
                        .frame(width: 40, height: 40)

                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .scaleEffect(isSelected ? 1.1 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Compact inline color picker (for forms)
struct InlineColorPicker: View {
    @Binding var selectedColor: String
    @State private var showingFullPicker = false

    var body: some View {
        HStack {
            Text("Event Color")
                .foregroundColor(.primary)

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showingFullPicker.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: selectedColor))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: Color(hex: selectedColor).opacity(0.3), radius: 2, x: 0, y: 1)

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(showingFullPicker ? 180 : 0))
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)

        if showingFullPicker {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(EventColorPalette.colors, id: \.hex) { color in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedColor = color.hex
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                            }
                        }) {
                            Circle()
                                .fill(Color(hex: color.hex))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            selectedColor == color.hex ? Color.white : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                                .shadow(
                                    color: selectedColor == color.hex
                                        ? Color(hex: color.hex).opacity(0.4)
                                        : Color.clear,
                                    radius: 4,
                                    x: 0,
                                    y: 2
                                )
                                .scaleEffect(selectedColor == color.hex ? 1.15 : 1.0)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

/// Color indicator badge (for event lists)
struct EventColorBadge: View {
    let color: String
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(Color(hex: color))
            .frame(width: size, height: size)
    }
}

/// Color indicator bar (for event cards)
struct EventColorBar: View {
    let color: String
    var width: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: width / 2)
            .fill(Color(hex: color))
            .frame(width: width)
    }
}

#Preview("Color Picker") {
    VStack(spacing: 20) {
        EventColorPicker(selectedColor: .constant("#3B82F6"))

        Divider()

        InlineColorPicker(selectedColor: .constant("#10B981"))
    }
    .padding()
    .background(Color(.systemBackground))
}

#Preview("Color Badges") {
    HStack(spacing: 20) {
        ForEach(EventColorPalette.colors.prefix(6), id: \.hex) { color in
            VStack {
                EventColorBadge(color: color.hex, size: 12)
                Text(color.name)
                    .font(.caption2)
            }
        }
    }
    .padding()
}
