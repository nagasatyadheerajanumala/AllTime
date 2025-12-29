import Foundation
import SwiftUI
import Combine

/// ViewModel for end-of-day review functionality
@MainActor
class DayReviewViewModel: ObservableObject {
    // MARK: - Published State

    @Published var dayReview: DayReviewResponse?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?
    @Published var showSuccess = false
    @Published var successMessage: String?

    // Reflection form state
    @Published var selectedRating: DayRating = .okay
    @Published var reflectionNotes: String = ""

    // Date for review (defaults to today)
    @Published var reviewDate: Date = Date()

    private let dayReviewService = DayReviewService.shared

    // MARK: - Computed Properties

    var completionRatio: Double {
        guard let review = dayReview, review.totalPlanned > 0 else { return 0 }
        return Double(review.totalCompleted) / Double(review.totalPlanned)
    }

    var completedActivities: [ActivityStatus] {
        dayReview?.activities.filter { $0.isCompleted } ?? []
    }

    var missedActivities: [ActivityStatus] {
        dayReview?.activities.filter { !$0.isCompleted } ?? []
    }

    var hasExistingReflection: Bool {
        dayReview?.existingRating != nil
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: reviewDate)
    }

    // MARK: - Loading

    func loadDayReview() async {
        isLoading = true
        error = nil

        print("🔄 DayReviewViewModel: Loading day review for \(reviewDate)...")

        do {
            dayReview = try await dayReviewService.getDayReview(date: reviewDate)

            // Pre-fill form if existing reflection
            if let existingRating = dayReview?.existingRating,
               let rating = DayRating(rawValue: existingRating) {
                selectedRating = rating
            }
            if let existingNotes = dayReview?.existingNotes {
                reflectionNotes = existingNotes
            }

            print("✅ DayReviewViewModel: Loaded review - \(dayReview?.totalCompleted ?? 0)/\(dayReview?.totalPlanned ?? 0) completed")
        } catch {
            self.error = error.localizedDescription
            print("❌ DayReviewViewModel: Failed to load - \(error)")
        }

        isLoading = false
    }

    // MARK: - Save Reflection

    func saveReflection() async {
        isSaving = true
        error = nil

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let request = ReflectionRequest(
            date: formatter.string(from: reviewDate),
            rating: selectedRating.rawValue,
            notes: reflectionNotes.isEmpty ? nil : reflectionNotes,
            plannedCount: dayReview?.totalPlanned,
            completedCount: dayReview?.totalCompleted,
            steps: dayReview?.steps,
            sleepHours: dayReview?.sleepHours,
            activeMinutes: dayReview?.activeMinutes
        )

        do {
            let response = try await dayReviewService.saveReflection(request: request)
            if response.success {
                showSuccess = true
                successMessage = response.message ?? "Reflection saved!"
                // Reload to show updated state
                await loadDayReview()
            } else {
                error = response.message ?? "Failed to save reflection"
            }
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }

    // MARK: - Helpers

    func dismissSuccess() {
        showSuccess = false
        successMessage = nil
    }

    func setDate(_ date: Date) {
        reviewDate = date
        Task {
            await loadDayReview()
        }
    }
}

// MARK: - Day Rating Enum

enum DayRating: String, CaseIterable {
    case great = "great"
    case okay = "okay"
    case rough = "rough"

    var emoji: String {
        switch self {
        case .great: return "😊"
        case .okay: return "😐"
        case .rough: return "😔"
        }
    }

    var label: String {
        switch self {
        case .great: return "Great"
        case .okay: return "Okay"
        case .rough: return "Rough"
        }
    }

    var color: Color {
        switch self {
        case .great: return .green
        case .okay: return .orange
        case .rough: return .red
        }
    }
}
