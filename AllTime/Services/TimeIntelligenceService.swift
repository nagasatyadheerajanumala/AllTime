import Foundation
import Combine

/// Service for fetching Time Intelligence data from the backend.
/// This is the decision engine that powers the app's core intelligence.
class TimeIntelligenceService: ObservableObject {
    static let shared = TimeIntelligenceService()

    @Published var todayIntelligence: TimeIntelligenceResponse?
    @Published var isLoading = false
    @Published var lastError: String?

    private init() {}

    /// Fetch today's time intelligence - the primary decision surface data.
    @MainActor
    func fetchTodayIntelligence() async {
        isLoading = true
        lastError = nil

        do {
            todayIntelligence = try await APIService.shared.fetchTimeIntelligence()
            print("✅ TimeIntelligenceService: Fetched intelligence - \(todayIntelligence?.capacityOverloadPercent ?? 0)% overload")
        } catch {
            lastError = error.localizedDescription
            print("❌ TimeIntelligenceService: Failed to fetch intelligence - \(error)")
        }

        isLoading = false
    }

    /// Fetch just the directive (fast endpoint for widget/notification).
    @MainActor
    func fetchDirective() async -> DirectiveResponse? {
        do {
            return try await APIService.shared.fetchDirective()
        } catch {
            print("❌ TimeIntelligenceService: Failed to fetch directive - \(error)")
            return nil
        }
    }

    /// Record user action on a decline recommendation.
    func recordDeclineAction(recommendationId: Int64, action: String, wasPositive: Bool) async {
        do {
            try await APIService.shared.recordDeclineAction(
                recommendationId: recommendationId,
                action: action,
                wasPositive: wasPositive
            )
            print("✅ TimeIntelligenceService: Recorded decline action - \(action)")
        } catch {
            print("❌ TimeIntelligenceService: Failed to record action - \(error)")
        }
    }

    /// Dismiss a decline recommendation.
    func dismissRecommendation(recommendationId: Int64) async {
        do {
            try await APIService.shared.dismissDeclineRecommendation(recommendationId: recommendationId)
            print("✅ TimeIntelligenceService: Dismissed recommendation")
        } catch {
            print("❌ TimeIntelligenceService: Failed to dismiss - \(error)")
        }
    }
}
