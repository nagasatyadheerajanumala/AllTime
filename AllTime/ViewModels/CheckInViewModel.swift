import Foundation
import SwiftUI
import Combine

/// ViewModel for check-in functionality
@MainActor
class CheckInViewModel: ObservableObject {
    // MARK: - Published State

    @Published var checkInStatus: CheckInStatusResponse?
    @Published var patternsSummary: PatternsSummary?
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var error: String?
    @Published var showSuccess = false
    @Published var successMessage: String?

    // Check-in form state
    @Published var selectedTimeOfDay: TimeOfDay = .current
    @Published var energyLevel: Int = 3
    @Published var stressLevel: Int = 3
    @Published var focusLevel: Int = 3
    @Published var selectedMood: MoodOption = .okay
    @Published var sleepHours: Double = 7.0
    @Published var sleepQuality: Int = 3
    @Published var productivityRating: Int = 3
    @Published var notes: String = ""

    // Energy prediction from HealthKit
    @Published var energyPrediction: EnergyPredictionResult?
    @Published var isPredictingEnergy = false
    @Published var userOverrodeEnergy = false

    // Suggestions based on energy and mood
    @Published var suggestions: MoodSuggestionsResponse?
    @Published var isLoadingSuggestions = false

    private let checkInService = CheckInService.shared
    private let energyPredictor = EnergyPredictor.shared

    // MARK: - Computed Properties

    var isCheckInDoneForCurrentPeriod: Bool {
        guard let status = checkInStatus else { return false }
        switch TimeOfDay.current {
        case .morning:
            return status.morningCheckInDone
        case .afternoon:
            return status.afternoonCheckInDone
        case .evening:
            return status.eveningCheckInDone
        }
    }

    var dataQualityDescription: String {
        guard let score = checkInStatus?.dataQualityScore else { return "Getting started" }
        if score < 30 {
            return "Building your profile..."
        } else if score < 60 {
            return "Learning your patterns"
        } else if score < 80 {
            return "Good data quality"
        } else {
            return "Excellent insights available"
        }
    }

    var streakDescription: String {
        guard let streak = checkInStatus?.streakDays, streak > 0 else {
            return "Start your streak!"
        }
        if streak == 1 {
            return "1 day streak"
        }
        return "\(streak) day streak"
    }

    // MARK: - Loading

    func loadStatus() async {
        isLoading = true
        error = nil

        print("🔄 CheckInViewModel: Loading check-in status...")

        do {
            checkInStatus = try await checkInService.getCheckInStatus()
            print("✅ CheckInViewModel: Status loaded - morning:\(checkInStatus?.morningCheckInDone ?? false), afternoon:\(checkInStatus?.afternoonCheckInDone ?? false), evening:\(checkInStatus?.eveningCheckInDone ?? false)")
        } catch {
            self.error = error.localizedDescription
            print("❌ CheckInViewModel: Failed to load status - \(error)")
        }

        isLoading = false

        // Also load energy prediction from HealthKit
        await loadEnergyPrediction()
    }

    func loadEnergyPrediction() async {
        guard !userOverrodeEnergy else { return } // Don't override user's choice

        isPredictingEnergy = true

        let prediction = await energyPredictor.predictEnergy()
        energyPrediction = prediction

        // Auto-set energy level if we have reasonable confidence
        if prediction.confidence != .low {
            energyLevel = prediction.predictedEnergy
        }

        isPredictingEnergy = false
    }

    func userDidOverrideEnergy(_ newLevel: Int) {
        userOverrodeEnergy = true
        energyLevel = newLevel
    }

    // MARK: - Suggestions

    func loadSuggestions() async {
        isLoadingSuggestions = true

        do {
            suggestions = try await checkInService.getSuggestions(
                energyLevel: energyLevel,
                mood: selectedMood.rawValue,
                timeOfDay: selectedTimeOfDay.rawValue
            )
        } catch {
            print("Failed to load suggestions: \(error)")
        }

        isLoadingSuggestions = false
    }

    func loadPatternsSummary() async {
        do {
            patternsSummary = try await checkInService.getPatternsSummary()
        } catch {
            print("Failed to load patterns summary: \(error)")
        }
    }

    // MARK: - Submit Check-In

    func submitCheckIn() async {
        isSubmitting = true
        error = nil

        let request = MoodCheckInRequest(
            timeOfDay: selectedTimeOfDay.rawValue,
            energyLevel: energyLevel,
            stressLevel: stressLevel,
            focusLevel: focusLevel,
            mood: selectedMood.rawValue,
            productivityRating: selectedTimeOfDay == .evening ? productivityRating : nil,
            sleepQuality: selectedTimeOfDay == .morning ? sleepQuality : nil,
            sleepHours: selectedTimeOfDay == .morning ? sleepHours : nil,
            notes: notes.isEmpty ? nil : notes,
            source: "manual"
        )

        do {
            let response = try await checkInService.submitMoodCheckIn(request)
            if response.success {
                showSuccess = true
                successMessage = response.message ?? "Check-in recorded!"
                // Refresh status
                await loadStatus()
                // Load personalized suggestions based on check-in
                await loadSuggestions()
                resetForm()
            } else {
                error = response.message ?? "Failed to submit check-in"
            }
        } catch {
            self.error = error.localizedDescription
        }

        isSubmitting = false
    }

    func submitQuickCheckIn() async {
        isSubmitting = true
        error = nil

        do {
            let response = try await checkInService.quickCheckIn(
                energyLevel: energyLevel,
                mood: selectedMood.rawValue
            )
            if response.success {
                showSuccess = true
                successMessage = "Quick check-in recorded!"
                await loadStatus()
                // Load personalized suggestions based on check-in
                await loadSuggestions()
            } else {
                error = response.message ?? "Failed to submit"
            }
        } catch {
            self.error = error.localizedDescription
        }

        isSubmitting = false
    }

    // MARK: - Helpers

    func resetForm() {
        selectedTimeOfDay = .current
        energyLevel = 3
        stressLevel = 3
        focusLevel = 3
        selectedMood = .okay
        sleepHours = 7.0
        sleepQuality = 3
        productivityRating = 3
        notes = ""
    }

    func dismissSuccess() {
        showSuccess = false
        successMessage = nil
    }
}
