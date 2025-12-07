import Foundation
import SwiftUI
import Combine

@MainActor
class DailySummaryViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var summary: DailySummary?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedDate: Date = Date()

    // MARK: - Dependencies

    private let apiService = APIService()
    private let cache = DailySummaryCache.shared
    private var loadTask: Task<Void, Never>?

    // MARK: - Public API

    /// Load AI-generated summary for a specific date (with caching)
    /// - Parameter date: Target date (defaults to today)
    /// - Parameter forceRefresh: If true, bypass cache and fetch fresh data
    func loadSummary(for date: Date = Date(), forceRefresh: Bool = false) async {
        // Cancel any existing load
        loadTask?.cancel()

        loadTask = Task {
            await performLoad(for: date, forceRefresh: forceRefresh)
        }

        await loadTask?.value
    }

    /// Refresh summary (force bypass cache)
    func refreshSummary() async {
        await loadSummary(for: selectedDate, forceRefresh: true)
    }

    /// Invalidate cache for today (call after calendar/health sync)
    func invalidateCache() {
        cache.invalidateToday()
    }

    // MARK: - Private Implementation

    private func performLoad(for date: Date, forceRefresh: Bool) async {
        guard !isLoading else {
            print("⚠️ DailySummaryViewModel: Already loading, skipping...")
            return
        }

        isLoading = true
        errorMessage = nil
        selectedDate = date
        defer { isLoading = false }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        print("🤖 DailySummaryViewModel: ===== LOADING AI SUMMARY =====")
        print("🤖 DailySummaryViewModel: Date: \(dateString)")
        print("🤖 DailySummaryViewModel: Force refresh: \(forceRefresh)")

        // Step 1: Check cache first (unless force refresh)
        if !forceRefresh, let cachedSummary = cache.getCachedSummary(for: date) {
            print("💾 DailySummaryViewModel: Using cached summary")
            self.summary = cachedSummary

            // Log cache hit details
            print("✅ DailySummaryViewModel: Loaded from cache")
            print("   - Day summary: \(cachedSummary.daySummary.count) paragraphs")
            print("   - Health summary: \(cachedSummary.healthSummary.count) paragraphs")
            print("   - Focus recommendations: \(cachedSummary.focusRecommendations.count) paragraphs")
            print("   - Alerts: \(cachedSummary.alerts.count) items")
            return
        }

        // Step 2: Cache miss or force refresh - fetch from AI endpoint
        print("🤖 DailySummaryViewModel: Cache miss - fetching from AI endpoint...")
        print("🤖 DailySummaryViewModel: Note: This may take 3-10 seconds (OpenAI processing)")

        do {
            // Call new AI-powered endpoint
            let startTime = Date()
            let summary = try await apiService.generateAIDailySummary(
                date: date,
                timezone: TimeZone.current.identifier
            )
            let duration = Date().timeIntervalSince(startTime)

            // Check if task was cancelled
            if Task.isCancelled {
                print("⚠️ DailySummaryViewModel: Request was cancelled")
                return
            }

            // Cache the result
            cache.cacheSummary(summary, for: date)

            // Update UI
            self.summary = summary

            print("✅ DailySummaryViewModel: Successfully loaded AI summary")
            print("✅ DailySummaryViewModel: Generation took: \(String(format: "%.2f", duration))s")
            print("   - Day summary: \(summary.daySummary.count) paragraphs")
            print("   - Health summary: \(summary.healthSummary.count) paragraphs")
            print("   - Focus recommendations: \(summary.focusRecommendations.count) paragraphs")
            print("   - Alerts: \(summary.alerts.count) items")

            // Log first paragraph preview for verification
            if !summary.daySummary.isEmpty {
                let preview = summary.daySummary[0].prefix(100)
                print("📝 Day summary preview: \(preview)...")
            }

        } catch let nsError as NSError {
            // Check for specific error codes
            if Task.isCancelled {
                print("⚠️ DailySummaryViewModel: Request was cancelled")
                return
            }

            print("❌ DailySummaryViewModel: Error loading AI summary")
            print("❌ DailySummaryViewModel: Code: \(nsError.code)")
            print("❌ DailySummaryViewModel: Description: \(nsError.localizedDescription)")

            if nsError.code == 401 {
                errorMessage = "Authentication failed. Please sign in again."
            } else if nsError.code == 500 {
                errorMessage = "AI summary generation failed. Backend may be unavailable."
            } else {
                errorMessage = nsError.localizedDescription
            }

        } catch {
            print("❌ DailySummaryViewModel: Unexpected error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}
