import Foundation
import SwiftUI

// MARK: - Energy Pattern Models

/// Response from GET /api/v1/health/energy-patterns
struct EnergyPatternsResponse: Codable {
    let patterns: [EnergyPatternInsight]
    let dataPoints: Int
    let analysisWindow: String
    let hasEnoughData: Bool
    let message: String?
}

/// Individual energy pattern insight
struct EnergyPatternInsight: Codable, Identifiable {
    let pattern: String              // "5+ meetings", "Back-to-back meetings", "Late meetings"
    let metric: String               // "sleep", "steps", "heart_rate", "hrv"
    let impact: String               // "-54 min", "-2,400 steps", "+3 BPM"
    let comparison: String           // "6.2h vs 7.1h on light days"
    let icon: String                 // SF Symbol name: "moon.zzz", "figure.walk", "heart.fill"
    let color: String                // Hex color: "#8B5CF6"
    let significance: String         // "strong", "moderate", "weak"
    let sampleSize: Int              // Number of days analyzed
    let patternDescription: String?  // Detailed description for tooltip

    var id: String { "\(pattern)-\(metric)" }

    // MARK: - Computed Properties

    var iconColor: Color {
        Color(hex: color.replacingOccurrences(of: "#", with: ""))
    }

    var sfSymbol: String {
        // Ensure valid SF Symbol or provide fallback
        switch icon {
        case "moon.zzz", "moon.stars", "heart.fill", "figure.walk", "waveform.path.ecg":
            return icon
        default:
            return metricIcon
        }
    }

    /// Fallback icon based on metric type
    private var metricIcon: String {
        switch metric {
        case "sleep": return "moon.zzz"
        case "steps": return "figure.walk"
        case "heart_rate": return "heart.fill"
        case "hrv": return "waveform.path.ecg"
        default: return "chart.bar.fill"
        }
    }

    /// Human-readable metric name
    var metricDisplayName: String {
        switch metric {
        case "sleep": return "Sleep"
        case "steps": return "Steps"
        case "heart_rate": return "Heart Rate"
        case "hrv": return "Heart Rate Variability"
        default: return metric.capitalized
        }
    }

    /// Significance badge color
    var significanceColor: Color {
        switch significance {
        case "strong": return DesignSystem.Colors.errorRed  // Red - high impact
        case "moderate": return DesignSystem.Colors.amber // Orange - medium
        case "weak": return Color(hex: "6B7280")    // Gray - low
        default: return Color(hex: "6B7280")
        }
    }

    /// Significance badge text
    var significanceLabel: String {
        switch significance {
        case "strong": return "High Impact"
        case "moderate": return "Moderate"
        case "weak": return "Low"
        default: return significance.capitalized
        }
    }

    /// Whether this is a negative impact (sleep loss, fewer steps, higher HR)
    var isNegativeImpact: Bool {
        impact.hasPrefix("-") || (metric == "heart_rate" && impact.hasPrefix("+"))
    }
}
