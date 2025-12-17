import Foundation

// MARK: - Daily Forecast

struct DailyForecast: Codable {
    let date: String?
    let generatedAt: String?
    let dayRiskScore: Double
    let dayRiskLevel: String
    let recommendedBufferMinutes: Int
    let energyForecast: EnergyForecast?
    let weatherSummary: String?
    let weatherImpact: String?
    let calendarSummary: String?
    let totalEvents: Int?
    let dayLoadScore: Double
    let recommendations: [Recommendation]?
    let bestFocusTime: String?
    let bestMeetingTime: String?
    let bestBreakTime: String?

    var riskLevelColor: String {
        switch dayRiskLevel {
        case "high": return "red"
        case "medium": return "orange"
        default: return "green"
        }
    }

    var formattedBestFocusTime: String? {
        guard let time = bestFocusTime else { return nil }
        return formatTime(time)
    }

    var formattedBestMeetingTime: String? {
        guard let time = bestMeetingTime else { return nil }
        return formatTime(time)
    }

    var formattedBestBreakTime: String? {
        guard let time = bestBreakTime else { return nil }
        return formatTime(time)
    }

    private func formatTime(_ time: String) -> String {
        // Convert "10:00" to "10:00 AM"
        let parts = time.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]) else { return time }

        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return "\(displayHour):\(parts[1]) \(period)"
    }
}

struct EnergyForecast: Codable {
    let morningEnergy: Int?
    let afternoonEnergy: Int?
    let eveningEnergy: Int?
    let peakEnergyTime: String?
    let expectedDipTime: String?

    var energyTrend: String {
        guard let morning = morningEnergy,
              let afternoon = afternoonEnergy,
              let evening = eveningEnergy else {
            return "unknown"
        }

        if morning >= afternoon && afternoon >= evening {
            return "declining"
        } else if morning <= afternoon && afternoon <= evening {
            return "improving"
        } else if afternoon < morning && afternoon < evening {
            return "midday_dip"
        }
        return "stable"
    }
}

struct Recommendation: Codable, Identifiable {
    let category: String
    let title: String
    let description: String
    let priority: String

    var id: String { "\(category)-\(title)" }

    var priorityColor: String {
        switch priority {
        case "high": return "red"
        case "medium": return "orange"
        default: return "blue"
        }
    }

    var categoryIcon: String {
        switch category {
        case "energy": return "bolt.fill"
        case "travel": return "car.fill"
        case "breaks": return "cup.and.saucer.fill"
        case "workload": return "calendar.badge.exclamationmark"
        case "punctuality": return "clock.fill"
        default: return "lightbulb.fill"
        }
    }
}

// MARK: - Event Prediction

struct EventPrediction: Codable, Identifiable {
    let eventId: Int64?
    let eventTitle: String?
    let eventTime: String?
    let punctuality: PunctualityPrediction?
    let travel: EventTravelPrediction?
    let predictedEnergy: Int
    let riskFactors: [String]?
    let recommendations: [String]?

    var id: Int64 { eventId ?? 0 }

    var formattedEventTime: String? {
        guard let timeStr = eventTime else { return nil }
        // Parse ISO datetime and format nicely
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: timeStr) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "h:mm a"
            return displayFormatter.string(from: date)
        }
        return timeStr
    }

    var energyDescription: String {
        switch predictedEnergy {
        case 1: return "Very Low"
        case 2: return "Low"
        case 3: return "Moderate"
        case 4: return "Good"
        case 5: return "Excellent"
        default: return "Unknown"
        }
    }
}

struct PunctualityPrediction: Codable {
    let onTimeProbability: Double
    let riskLevel: String
    let factors: [String]?
    let suggestedBufferMinutes: Int

    var onTimePercentage: Int {
        Int(onTimeProbability * 100)
    }

    var riskColor: String {
        switch riskLevel {
        case "high": return "red"
        case "medium": return "orange"
        default: return "green"
        }
    }
}

struct EventTravelPrediction: Codable {
    let baseTravelMinutes: Int
    let adjustedTravelMinutes: Int
    let weatherMultiplier: Double
    let recommendedDepartureTime: String?
    let confidence: String

    var formattedDepartureTime: String? {
        guard let timeStr = recommendedDepartureTime else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: timeStr) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "h:mm a"
            return displayFormatter.string(from: date)
        }
        return timeStr
    }

    var hasWeatherImpact: Bool {
        weatherMultiplier > 1.0
    }

    var weatherImpactDescription: String {
        if weatherMultiplier >= 1.4 {
            return "Severe weather impact"
        } else if weatherMultiplier >= 1.2 {
            return "Moderate weather impact"
        } else if weatherMultiplier > 1.0 {
            return "Minor weather impact"
        }
        return "No weather impact"
    }
}

// MARK: - Mood-Based Suggestions

struct MoodSuggestionsResponse: Codable {
    let energyLevel: Int
    let mood: String
    let timeOfDay: String
    let message: String
    let suggestions: [MoodSuggestion]
    let generatedAt: String?
}

struct MoodSuggestion: Codable, Identifiable {
    let title: String
    let description: String
    let category: String
    let priority: String
    let icon: String
    let durationMinutes: Int?

    var id: String { "\(category)-\(title)" }

    var sfSymbolName: String {
        // Map backend icon names to SF Symbols
        switch icon {
        case "figure.walk": return "figure.walk"
        case "leaf.fill": return "leaf.fill"
        case "moon.fill": return "moon.fill"
        case "cup.and.saucer.fill", "cup.and.saucer": return "cup.and.saucer.fill"
        case "bolt.fill": return "bolt.fill"
        case "sparkles": return "sparkles"
        case "wind": return "wind"
        case "sun.max.fill": return "sun.max.fill"
        case "drop.fill": return "drop.fill"
        case "heart.fill": return "heart.fill"
        case "brain": return "brain.head.profile"
        case "fork.knife": return "fork.knife"
        case "arrow.up.heart.fill": return "arrow.up.heart.fill"
        case "sunset.fill": return "sunset.fill"
        case "calendar": return "calendar"
        case "checkmark.circle.fill": return "checkmark.circle.fill"
        case "pause.circle.fill": return "pause.circle.fill"
        case "clock.fill": return "clock.fill"
        default: return "lightbulb.fill"
        }
    }

    var priorityColor: String {
        switch priority {
        case "high": return "orange"
        case "low": return "gray"
        default: return "blue"
        }
    }

    var categoryDisplayName: String {
        switch category {
        case "activity": return "Activity"
        case "nutrition": return "Nutrition"
        case "sleep": return "Sleep"
        case "break": return "Break"
        case "productivity": return "Focus"
        case "wellness": return "Wellness"
        case "social": return "Social"
        case "insight": return "Insight"
        case "calendar": return "Calendar"
        default: return category.capitalized
        }
    }

    var durationText: String? {
        guard let mins = durationMinutes else { return nil }
        if mins < 60 {
            return "\(mins) min"
        } else {
            let hours = mins / 60
            let remainingMins = mins % 60
            if remainingMins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(remainingMins)m"
        }
    }
}
