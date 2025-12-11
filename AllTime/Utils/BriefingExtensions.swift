import Foundation
import SwiftUI

// MARK: - Date Formatting Extensions for Briefing
extension String {
    /// Converts ISO8601 time string to readable format (e.g., "9:00 AM")
    func toReadableTime() -> String {
        // Handle various time formats
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "HH:mm:ss"
                f.timeZone = TimeZone.current
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "HH:mm"
                f.timeZone = TimeZone.current
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                f.timeZone = TimeZone.current
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                f.timeZone = TimeZone.current
                return f
            }()
        ]

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "h:mm a"
        outputFormatter.timeZone = TimeZone.current

        for formatter in formatters {
            if let date = formatter.date(from: self) {
                return outputFormatter.string(from: date)
            }
        }

        // Return original if parsing fails
        return self
    }

    /// Converts ISO8601 date string to readable format (e.g., "Monday, Dec 9")
    func toReadableDate() -> String {
        let inputFormatter = ISO8601DateFormatter()
        inputFormatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "EEEE, MMM d"
        outputFormatter.timeZone = TimeZone.current

        if let date = inputFormatter.date(from: self) {
            return outputFormatter.string(from: date)
        }

        // Try simple date format
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        simpleFormatter.timeZone = TimeZone.current

        if let date = simpleFormatter.date(from: self) {
            return outputFormatter.string(from: date)
        }

        return self
    }

    /// Converts ISO8601 datetime to relative time (e.g., "2 hours ago")
    func toRelativeTime() -> String {
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                f.timeZone = TimeZone.current
                return f
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: self) {
                let relativeFormatter = RelativeDateTimeFormatter()
                relativeFormatter.unitsStyle = .abbreviated
                return relativeFormatter.localizedString(for: date, relativeTo: Date())
            }
        }

        return self
    }
}

// MARK: - Time Range Formatting
struct TimeRangeFormatter {
    /// Formats a time range (e.g., "9:00 AM - 11:00 AM" or "9:00-11:00 AM")
    static func format(start: String, end: String, compact: Bool = false) -> String {
        let startTime = start.toReadableTime()
        let endTime = end.toReadableTime()

        if compact {
            // Remove duplicate AM/PM if same
            let startComponents = startTime.components(separatedBy: " ")
            let endComponents = endTime.components(separatedBy: " ")

            if startComponents.count == 2 && endComponents.count == 2 &&
               startComponents[1] == endComponents[1] {
                return "\(startComponents[0])-\(endTime)"
            }
        }

        return "\(startTime) - \(endTime)"
    }

    /// Formats duration in minutes to readable string
    static func formatDuration(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else if minutes % 60 == 0 {
            let hours = minutes / 60
            return hours == 1 ? "1 hour" : "\(hours) hours"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }
}

// MARK: - Briefing Card Styling
struct BriefingCardStyle: ViewModifier {
    var elevated: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(elevated ? DesignSystem.Colors.cardBackgroundElevated : DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .stroke(DesignSystem.Colors.tertiaryText.opacity(0.1), lineWidth: 1)
            )
    }
}

extension View {
    func briefingCard(elevated: Bool = false) -> some View {
        modifier(BriefingCardStyle(elevated: elevated))
    }
}

// MARK: - Skeleton Loading View
struct SkeletonView: View {
    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.cardBackgroundElevated,
                        DesignSystem.Colors.cardBackground,
                        DesignSystem.Colors.cardBackgroundElevated
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .opacity(isAnimating ? 0.6 : 1.0)
            .animation(
                Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

// MARK: - Briefing Loading View
struct BriefingLoadingView: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Quick stats skeleton
            HStack(spacing: DesignSystem.Spacing.md) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(spacing: 8) {
                        SkeletonView()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        SkeletonView()
                            .frame(width: 60, height: 12)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .briefingCard()

            // Summary card skeleton
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                SkeletonView()
                    .frame(height: 24)
                SkeletonView()
                    .frame(height: 16)
                SkeletonView()
                    .frame(width: 200, height: 16)
            }
            .briefingCard()

            // Suggestions skeleton
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: DesignSystem.Spacing.md) {
                        SkeletonView()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 6) {
                            SkeletonView()
                                .frame(height: 16)
                            SkeletonView()
                                .frame(width: 150, height: 12)
                        }
                    }
                    .briefingCard()
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
}

// MARK: - Briefing Error View
struct BriefingErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.warning)

            Text("Unable to Load Briefing")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text(message)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(DesignSystem.Colors.primary)
                .cornerRadius(DesignSystem.CornerRadius.md)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .briefingCard()
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
}

// MARK: - Empty Briefing View
struct EmptyBriefingView: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.tertiaryText)

            Text("No Briefing Available")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text("Your daily briefing will appear here once generated. Check back soon!")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .briefingCard()
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
}
