import Foundation
import HealthKit

/// Predicts energy levels based on HealthKit data
/// Energy scale: 1 (Very Low) to 5 (Excellent)
class EnergyPredictor {
    static let shared = EnergyPredictor()

    private let healthMetricsService = HealthMetricsService.shared

    private init() {}

    // MARK: - Energy Prediction

    /// Predict current energy level based on HealthKit data
    /// Returns a value 1-5 and confidence level
    func predictEnergy() async -> EnergyPredictionResult {
        do {
            let today = Date()
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

            // Fetch today's and yesterday's metrics
            let todayMetrics = try await healthMetricsService.fetchDailyMetrics(for: today)
            let yesterdayMetrics = try await healthMetricsService.fetchDailyMetrics(for: yesterday)

            return calculateEnergy(today: todayMetrics, yesterday: yesterdayMetrics)
        } catch {
            print("EnergyPredictor: Failed to fetch health data - \(error)")
            return EnergyPredictionResult(
                predictedEnergy: 3,
                confidence: .low,
                factors: [],
                explanation: "Unable to access health data"
            )
        }
    }

    // MARK: - Calculation Logic

    private func calculateEnergy(today: DailyHealthMetrics, yesterday: DailyHealthMetrics) -> EnergyPredictionResult {
        var scores: [Double] = []
        var factors: [EnergyFactor] = []
        var weightSum: Double = 0

        // 1. SLEEP (Most important - weight: 3)
        if let sleepMinutes = yesterday.sleepMinutes {
            let sleepHours = Double(sleepMinutes) / 60.0
            let sleepScore = calculateSleepScore(hours: sleepHours)
            scores.append(sleepScore * 3)
            weightSum += 3

            let sleepStatus: String
            if sleepHours >= 7.5 {
                sleepStatus = "Great sleep (\(String(format: "%.1f", sleepHours))h)"
            } else if sleepHours >= 6 {
                sleepStatus = "Moderate sleep (\(String(format: "%.1f", sleepHours))h)"
            } else {
                sleepStatus = "Low sleep (\(String(format: "%.1f", sleepHours))h)"
            }

            factors.append(EnergyFactor(
                name: "Sleep",
                icon: "bed.double.fill",
                value: sleepStatus,
                impact: sleepScore > 3.5 ? .positive : sleepScore < 2.5 ? .negative : .neutral
            ))
        }

        // 2. HEART RATE VARIABILITY (Recovery indicator - weight: 2)
        if let hrv = today.hrv ?? yesterday.hrv {
            let hrvScore = calculateHRVScore(hrv: hrv)
            scores.append(hrvScore * 2)
            weightSum += 2

            let hrvStatus = hrv > 50 ? "Good recovery" : hrv > 30 ? "Moderate" : "Low recovery"
            factors.append(EnergyFactor(
                name: "Recovery",
                icon: "heart.fill",
                value: hrvStatus,
                impact: hrvScore > 3.5 ? .positive : hrvScore < 2.5 ? .negative : .neutral
            ))
        }

        // 3. RESTING HEART RATE (Stress/recovery - weight: 1.5)
        if let rhr = today.restingHeartRate ?? yesterday.restingHeartRate {
            let rhrScore = calculateRHRScore(rhr: rhr)
            scores.append(rhrScore * 1.5)
            weightSum += 1.5

            let rhrStatus = rhr < 60 ? "Low (good)" : rhr < 75 ? "Normal" : "Elevated"
            factors.append(EnergyFactor(
                name: "Heart Rate",
                icon: "waveform.path.ecg",
                value: "\(Int(rhr)) bpm - \(rhrStatus)",
                impact: rhrScore > 3.5 ? .positive : rhrScore < 2.5 ? .negative : .neutral
            ))
        }

        // 4. ACTIVITY LEVEL (weight: 1)
        if let steps = today.steps {
            let activityScore = calculateActivityScore(steps: steps)
            scores.append(activityScore * 1)
            weightSum += 1

            let activityStatus = steps > 8000 ? "Active" : steps > 4000 ? "Moderate" : "Low activity"
            factors.append(EnergyFactor(
                name: "Activity",
                icon: "figure.walk",
                value: "\(steps.formatted()) steps - \(activityStatus)",
                impact: activityScore > 3.5 ? .positive : activityScore < 2.5 ? .negative : .neutral
            ))
        }

        // Calculate weighted average
        var predictedEnergy: Int
        var confidence: PredictionConfidence
        var explanation: String

        if weightSum > 0 {
            let weightedAverage = scores.reduce(0, +) / weightSum
            predictedEnergy = Int(round(weightedAverage))
            predictedEnergy = max(1, min(5, predictedEnergy)) // Clamp to 1-5

            // Determine confidence based on available data
            if weightSum >= 6 {
                confidence = .high
                explanation = "Based on sleep, recovery, and activity data"
            } else if weightSum >= 3 {
                confidence = .medium
                explanation = "Based on available health data"
            } else {
                confidence = .low
                explanation = "Limited health data available"
            }
        } else {
            // No health data - use time-of-day heuristic
            predictedEnergy = getTimeBasedEnergy()
            confidence = .low
            explanation = "Based on typical energy patterns for this time of day"
            factors.append(EnergyFactor(
                name: "Time of Day",
                icon: "clock.fill",
                value: getTimeOfDayDescription(),
                impact: .neutral
            ))
        }

        return EnergyPredictionResult(
            predictedEnergy: predictedEnergy,
            confidence: confidence,
            factors: factors,
            explanation: explanation
        )
    }

    // MARK: - Individual Score Calculations

    private func calculateSleepScore(hours: Double) -> Double {
        // Optimal sleep: 7-9 hours
        if hours >= 7.5 && hours <= 9 {
            return 5.0
        } else if hours >= 7 {
            return 4.0
        } else if hours >= 6 {
            return 3.0
        } else if hours >= 5 {
            return 2.0
        } else {
            return 1.0
        }
    }

    private func calculateHRVScore(hrv: Double) -> Double {
        // Higher HRV = better recovery
        // Normal range varies by age, using general guidelines
        if hrv >= 60 {
            return 5.0
        } else if hrv >= 45 {
            return 4.0
        } else if hrv >= 30 {
            return 3.0
        } else if hrv >= 20 {
            return 2.0
        } else {
            return 1.0
        }
    }

    private func calculateRHRScore(rhr: Double) -> Double {
        // Lower RHR = better fitness/recovery
        if rhr < 55 {
            return 5.0
        } else if rhr < 65 {
            return 4.0
        } else if rhr < 75 {
            return 3.0
        } else if rhr < 85 {
            return 2.0
        } else {
            return 1.0
        }
    }

    private func calculateActivityScore(steps: Int) -> Double {
        // Moderate activity is good for energy
        // Too much or too little can affect energy
        if steps >= 6000 && steps <= 12000 {
            return 4.0 // Sweet spot
        } else if steps >= 4000 {
            return 3.5
        } else if steps >= 2000 {
            return 3.0
        } else if steps < 2000 {
            return 2.5 // Sedentary
        } else {
            return 3.0 // Very active might mean tired
        }
    }

    private func getTimeBasedEnergy() -> Int {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 6...9:
            return 3 // Morning - moderate, still waking up
        case 10...12:
            return 4 // Late morning - typically good energy
        case 13...14:
            return 3 // Post-lunch dip
        case 15...17:
            return 4 // Afternoon recovery
        case 18...21:
            return 3 // Evening - moderate
        default:
            return 2 // Late night/early morning - low
        }
    }

    private func getTimeOfDayDescription() -> String {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 6...9:
            return "Morning - Energy building up"
        case 10...12:
            return "Late morning - Peak energy time"
        case 13...14:
            return "Post-lunch - Natural dip"
        case 15...17:
            return "Afternoon - Second wind"
        case 18...21:
            return "Evening - Winding down"
        default:
            return "Night - Rest time"
        }
    }
}

// MARK: - Models

struct EnergyPredictionResult {
    let predictedEnergy: Int // 1-5
    let confidence: PredictionConfidence
    let factors: [EnergyFactor]
    let explanation: String

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

enum PredictionConfidence {
    case high, medium, low

    var description: String {
        switch self {
        case .high: return "High confidence"
        case .medium: return "Moderate confidence"
        case .low: return "Low confidence"
        }
    }

    var icon: String {
        switch self {
        case .high: return "checkmark.seal.fill"
        case .medium: return "checkmark.seal"
        case .low: return "questionmark.circle"
        }
    }
}

struct EnergyFactor {
    let name: String
    let icon: String
    let value: String
    let impact: EnergyImpact
}

enum EnergyImpact {
    case positive, neutral, negative

    var color: String {
        switch self {
        case .positive: return "green"
        case .neutral: return "gray"
        case .negative: return "orange"
        }
    }
}
