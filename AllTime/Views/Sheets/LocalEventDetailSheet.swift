import SwiftUI

/// Sheet for displaying local event details
struct LocalEventDetailSheet: View {
    let event: Event
    @Environment(\.dismiss) private var dismiss

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // Color bar and title
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(event.sourceColorAsColor)
                            .frame(height: 4)

                        Text(event.title)
                            .font(.title.weight(.bold))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }

                    // Date & Time
                    if let startDate = event.startDate {
                        EventDetailRow(icon: "calendar", iconColor: DesignSystem.Colors.primary, title: "Date & Time") {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text(dateFormatter.string(from: startDate))
                                    .font(.body)
                                    .foregroundColor(DesignSystem.Colors.primaryText)

                                if event.allDay {
                                    Text("All day")
                                        .font(.subheadline)
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                } else if let endDate = event.endDate {
                                    Text("\(timeFormatter.string(from: startDate)) - \(timeFormatter.string(from: endDate))")
                                        .font(.subheadline)
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                }
                            }
                        }
                    }

                    // Location
                    if let location = event.locationName, !location.isEmpty {
                        EventDetailRow(icon: "mappin.circle.fill", iconColor: .red, title: "Location") {
                            Text(location)
                                .font(.body)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                        }
                    }

                    // Description
                    if let description = event.description, !description.isEmpty {
                        EventDetailRow(icon: "text.alignleft", iconColor: .purple, title: "Description") {
                            Text(description)
                                .font(.body)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                        }
                    }

                    // Calendar source
                    EventDetailRow(icon: "calendar.badge.clock", iconColor: .gray, title: "Calendar") {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Circle()
                                .fill(event.sourceColorAsColor)
                                .frame(width: DesignSystem.Components.iconSmall, height: DesignSystem.Components.iconSmall)
                            Text(event.source.capitalized)
                                .font(.body)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
    }
}

// MARK: - Event Detail Row
/// Reusable row component for event details
struct EventDetailRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: DesignSystem.Components.avatarMedium + 4, height: DesignSystem.Components.avatarMedium + 4)
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.Components.iconMedium + 2, weight: .medium))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs + 2) {
                Text(title.uppercased())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                    .tracking(0.5)

                content
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}
