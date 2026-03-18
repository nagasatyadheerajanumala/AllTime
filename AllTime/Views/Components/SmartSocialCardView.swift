//
//  SmartSocialCardView.swift
//  AllTime
//
//  A contextual, one-tap social opportunity card.
//  Surfaces the best reason to connect with someone right now.
//

import SwiftUI

struct SmartSocialCardView: View {
    let card: SmartSocialCard
    let onAction: () -> Void
    let onDismiss: (() -> Void)?

    @State private var isActing = false
    @State private var didComplete = false

    init(card: SmartSocialCard, onAction: @escaping () -> Void, onDismiss: (() -> Void)? = nil) {
        self.card = card
        self.onAction = onAction
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: profile + headline + dismiss
            HStack(alignment: .top, spacing: 12) {
                // Profile picture with type indicator
                ZStack(alignment: .bottomTrailing) {
                    ProfilePictureView(
                        profilePictureUrl: card.connectionProfilePicture,
                        size: 44
                    )

                    // Type badge
                    Image(systemName: typeIcon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(typeColor))
                        .offset(x: 3, y: 3)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(card.headline)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle = card.subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 4)

                if let onDismiss = onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle().fill(DesignSystem.Colors.calmSurface)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Interest badges (compact)
            if let interests = card.sharedInterests, !interests.isEmpty {
                HStack(spacing: 6) {
                    ForEach(interests.prefix(3), id: \.self) { interest in
                        Text(interest)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.violet)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(DesignSystem.Colors.violet.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    if interests.count > 3 {
                        Text("+\(interests.count - 3)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                }
            }

            // Event details (for event_match cards)
            if card.isEventMatch, let eventTitle = card.eventTitle {
                VStack(alignment: .leading, spacing: 8) {
                    // Event title
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundColor(typeColor)
                        Text(eventTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Date & time
                    if let startTime = card.eventStartTime {
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                            Text(formatEventDateTime(startTime, endTime: card.eventEndTime))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                        }
                    }

                    // Location
                    if let location = card.eventLocation, !location.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                            Text(location)
                                .font(.system(size: 13))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .lineLimit(2)
                        }
                    }

                    // Description
                    if let description = card.eventDescription, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                            .lineLimit(3)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(typeColor.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(typeColor.opacity(0.1), lineWidth: 0.5)
                )
            }

            // Mutual slot context (for free_together cards)
            if card.isFreeTogether, let slotStart = card.mutualSlotStart, let slotEnd = card.mutualSlotEnd {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.emerald)

                    Text("\(slotStart) – \(slotEnd)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    if let dateStr = card.mutualSlotDate {
                        Text("·")
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                        Text(formatDateLabel(dateStr))
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DesignSystem.Colors.emerald.opacity(0.06))
                )
            }

            // Action button — one tap, done
            Button(action: {
                HapticManager.shared.mediumTap()
                onAction()
            }) {
                HStack(spacing: 6) {
                    if isActing {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.7)
                    } else if didComplete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                    } else {
                        Image(systemName: actionIcon)
                            .font(.system(size: 13, weight: .medium))
                    }

                    Text(didComplete ? "Done" : card.actionLabel)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(didComplete ? DesignSystem.Colors.emerald : typeColor)
                )
            }
            .buttonStyle(SmoothButtonStyle())
            .disabled(isActing || didComplete)
        }
        .calmCard(padding: 14)
    }

    // MARK: - Computed Properties

    private var typeColor: Color {
        switch card.type {
        case "event_match": return DesignSystem.Colors.violet
        case "free_together": return DesignSystem.Colors.emerald
        case "reconnect": return DesignSystem.Colors.amber
        default: return DesignSystem.Colors.primary
        }
    }

    private var typeIcon: String {
        switch card.type {
        case "event_match": return "calendar"
        case "free_together": return "clock"
        case "reconnect": return "arrow.triangle.2.circlepath"
        default: return "sparkles"
        }
    }

    private var actionIcon: String {
        switch card.actionType {
        case "invite_to_event": return "envelope.fill"
        case "create_and_invite": return "calendar.badge.plus"
        default: return "paperplane.fill"
        }
    }

    // MARK: - Formatting

    private func formatSmartTime(_ isoString: String) -> String {
        // Parse LocalDateTime format (yyyy-MM-ddTHH:mm:ss or yyyy-MM-ddTHH:mm)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "h:mm a"

        if let date = formatter.date(from: isoString) {
            return displayFormatter.string(from: date)
        }

        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        if let date = formatter.date(from: isoString) {
            return displayFormatter.string(from: date)
        }

        // Fallback: just show the time portion
        if let tIndex = isoString.firstIndex(of: "T") {
            let timeStr = String(isoString[isoString.index(after: tIndex)...])
            let parts = timeStr.prefix(5)
            return String(parts)
        }

        return isoString
    }

    private func formatEventDateTime(_ startTime: String, endTime: String?) -> String {
        let localFormatter = DateFormatter()
        localFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        let dateDisplay = DateFormatter()
        dateDisplay.dateFormat = "EEE, MMM d"

        let timeDisplay = DateFormatter()
        timeDisplay.dateFormat = "h:mm a"

        if let startDate = localFormatter.date(from: startTime) {
            let calendar = Calendar.current
            var dayLabel: String
            if calendar.isDateInToday(startDate) {
                dayLabel = "Today"
            } else if calendar.isDateInTomorrow(startDate) {
                dayLabel = "Tomorrow"
            } else {
                dayLabel = dateDisplay.string(from: startDate)
            }

            var result = dayLabel + " at " + timeDisplay.string(from: startDate)

            if let end = endTime, let endDate = localFormatter.date(from: end) {
                result += " – " + timeDisplay.string(from: endDate)
            }
            return result
        }

        // Fallback to simple time display
        return formatSmartTime(startTime)
    }

    private func formatDateLabel(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: dateStr) else { return dateStr }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"
            return dayFormatter.string(from: date)
        }
    }

    // MARK: - Public Methods for External State Control

    func setActing(_ acting: Bool) -> SmartSocialCardView {
        var view = self
        view._isActing = State(initialValue: acting)
        return view
    }
}
