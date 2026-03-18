//
//  TodayScheduleSection.swift
//  AllTime
//
//  Shows today's events in a clean, grouped list
//

import SwiftUI

struct TodayScheduleSection: View {
    let events: [Event]
    let currentEvent: Event?
    let onEventTap: (Event) -> Void
    var onShareEvent: ((Event) -> Void)? = nil

    @State private var isExpanded: Bool = true

    private var timedEvents: [Event] {
        events.filter { !$0.allDay }
    }

    private var allDayEvents: [Event] {
        events.filter { $0.allDay }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.blue)

                        Text("Schedule")
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }

                    Spacer()

                    if !timedEvents.isEmpty {
                        Text("\(timedEvents.count) events")
                            .font(.caption.weight(.medium))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                if events.isEmpty {
                    // Empty state
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(DesignSystem.Colors.emerald)
                        Text("No events today")
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .fill(DesignSystem.Colors.cardBackground)
                    )
                } else {
                    // All-day events
                    if !allDayEvents.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(allDayEvents.enumerated()), id: \.element.id) { index, event in
                                AllDayEventRow(event: event, onTap: { onEventTap(event) }, onShare: onShareEvent != nil ? { onShareEvent?(event) } : nil)

                                if index < allDayEvents.count - 1 {
                                    Divider()
                                        .padding(.leading, 40)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(DesignSystem.Colors.cardBackground)
                        )
                    }

                    // Timed events
                    if !timedEvents.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(timedEvents.enumerated()), id: \.element.id) { index, event in
                                ScheduleEventRow(
                                    event: event,
                                    isCurrent: event.id == currentEvent?.id,
                                    isPast: isPast(event),
                                    onTap: { onEventTap(event) },
                                    onShare: onShareEvent != nil ? { onShareEvent?(event) } : nil
                                )

                                if index < timedEvents.count - 1 {
                                    Divider()
                                        .padding(.leading, 68)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(DesignSystem.Colors.cardBackground)
                        )
                    }
                }
            }
        }
    }

    private func isPast(_ event: Event) -> Bool {
        guard let endDate = event.endDate ?? event.startDate else { return false }
        return endDate < Date()
    }
}

// MARK: - Schedule Event Row

private struct ScheduleEventRow: View {
    let event: Event
    let isCurrent: Bool
    let isPast: Bool
    let onTap: () -> Void
    var onShare: (() -> Void)? = nil

    private var timeString: String {
        guard let start = event.startDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: start)
    }

    private var endTimeString: String {
        guard let end = event.endDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: end)
    }

    private var durationString: String {
        guard let start = event.startDate, let end = event.endDate else { return "" }
        let minutes = Int(end.timeIntervalSince(start) / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let remaining = minutes % 60
            if remaining == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(remaining)m"
        }
        return "\(minutes)m"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Time column
                VStack(alignment: .trailing, spacing: 2) {
                    Text(timeString)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(isCurrent ? DesignSystem.Colors.emerald : (isPast ? DesignSystem.Colors.tertiaryText : DesignSystem.Colors.primaryText))
                    Text(durationString)
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
                .frame(width: 52, alignment: .trailing)

                // Color bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(event.sourceColorAsColor.opacity(isPast ? 0.3 : 1.0))
                    .frame(width: 3, height: 36)

                // Event info
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(isPast ? DesignSystem.Colors.tertiaryText : DesignSystem.Colors.primaryText)
                        .lineLimit(1)
                        .strikethrough(isPast)

                    if let locationName = event.locationName, !locationName.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin")
                                .font(.system(size: 9))
                            Text(locationName)
                                .font(.caption2)
                        }
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .lineLimit(1)
                    }
                }

                Spacer()

                // Current indicator
                if isCurrent {
                    Text("NOW")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.emerald)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.emerald.opacity(0.15))
                        )
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if let onShare = onShare {
                Button {
                    onShare()
                } label: {
                    Label("Share Event", systemImage: "paperplane")
                }
            }
        }
    }
}

// MARK: - All Day Event Row

private struct AllDayEventRow: View {
    let event: Event
    let onTap: () -> Void
    var onShare: (() -> Void)? = nil

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 13))
                    .foregroundColor(DesignSystem.Colors.amber)
                    .frame(width: 24)

                RoundedRectangle(cornerRadius: 2)
                    .fill(event.sourceColorAsColor)
                    .frame(width: 3, height: 24)

                Text(event.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(1)

                Spacer()

                Text("All day")
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if let onShare = onShare {
                Button {
                    onShare()
                } label: {
                    Label("Share Event", systemImage: "paperplane")
                }
            }
        }
    }
}
