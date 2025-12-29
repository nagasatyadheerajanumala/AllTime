import Foundation
import SwiftUI
import Combine
import CoreLocation

@MainActor
class PlanMyDayViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedDate = Date()
    @Published var dayType: DayTypeInfo?
    @Published var suggestions: [ActivitySuggestion] = []
    @Published var taskSuggestions: [TaskSuggestion] = []
    @Published var itinerary: ItineraryResponse?

    // AI Weekend Plan
    @Published var weekendPlan: WeekendPlanResponse?
    @Published var isGeneratingWeekendPlan = false

    @Published var isLoadingSuggestions = false
    @Published var isLoadingTaskSuggestions = false
    @Published var isGeneratingItinerary = false
    @Published var errorMessage: String?
    @Published var needsInterestsSetup = false

    // User interests (loaded from server or local)
    @Published var userInterests: UserInterests?

    // Itinerary preferences
    @Published var pace: String = "balanced"
    @Published var includeMeals: Bool = true

    // Services
    private let apiService = APIService.shared
    private let aiPlannerService = AIDayPlannerService.shared
    private let locationManager = LocationManager.shared

    // MARK: - Computed Properties
    var isRestDay: Bool {
        dayType?.isRestDay ?? false
    }

    var dayTypeLabel: String {
        dayType?.dayTypeLabel ?? "Today"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedDate)
    }

    // MARK: - Load Suggestions
    func loadSuggestions() async {
        guard let userId = UserDefaults.standard.value(forKey: "userId") as? Int64 else { return }
        guard let token = KeychainManager.shared.getAccessToken() else {
            print("No access token available for loading suggestions")
            return
        }

        isLoadingSuggestions = true
        errorMessage = nil

        do {
            // Format date
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateString = formatter.string(from: selectedDate)

            guard let url = URL(string: "\(Constants.API.baseURL)/api/v1/planning/suggestions?date=\(dateString)") else {
                throw URLError(.badURL)
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(String(userId), forHTTPHeaderField: "X-User-ID")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let suggestionsResponse = try JSONDecoder().decode(DaySuggestionsResponse.self, from: data)

            self.dayType = DayTypeInfo(
                date: suggestionsResponse.date,
                dayType: suggestionsResponse.dayType,
                dayTypeLabel: suggestionsResponse.dayTypeLabel,
                isWeekend: suggestionsResponse.dayType == "weekend",
                isHoliday: suggestionsResponse.dayType == "holiday",
                isRestDay: suggestionsResponse.isRestDay,
                holidayName: nil
            )

            self.suggestions = suggestionsResponse.suggestions ?? []
            self.needsInterestsSetup = suggestionsResponse.needsSetup ?? false

            print("Loaded \(suggestions.count) suggestions for \(dateString)")

        } catch {
            errorMessage = "Failed to load suggestions: \(error.localizedDescription)"
            print("Load suggestions error: \(error)")
        }

        isLoadingSuggestions = false
    }

    // MARK: - Generate Itinerary
    func generateItinerary() async {
        guard let userId = UserDefaults.standard.value(forKey: "userId") as? Int64 else { return }
        guard let token = KeychainManager.shared.getAccessToken() else {
            errorMessage = "Please sign in first"
            return
        }

        isGeneratingItinerary = true
        errorMessage = nil

        do {
            guard let url = URL(string: "\(Constants.API.baseURL)/api/v1/planning/itinerary") else {
                throw URLError(.badURL)
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(String(userId), forHTTPHeaderField: "X-User-ID")

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateString = formatter.string(from: selectedDate)

            let itineraryRequest = ItineraryRequest(
                startDate: dateString,
                endDate: dateString,
                preferences: ItineraryPreferences(
                    pace: pace,
                    includeMeals: includeMeals,
                    budget: "moderate"
                )
            )

            request.httpBody = try JSONEncoder().encode(itineraryRequest)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("Generate itinerary failed: \(responseStr)")
                }
                throw URLError(.badServerResponse)
            }

            self.itinerary = try JSONDecoder().decode(ItineraryResponse.self, from: data)
            print("Generated itinerary with \(itinerary?.days.count ?? 0) days")

        } catch {
            errorMessage = "Failed to generate itinerary: \(error.localizedDescription)"
            print("Generate itinerary error: \(error)")
        }

        isGeneratingItinerary = false
    }

    // MARK: - Load Day Type
    func loadDayType() async {
        guard let token = KeychainManager.shared.getAccessToken() else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: selectedDate)

        guard let url = URL(string: "\(Constants.API.baseURL)/api/v1/planning/day-type?date=\(dateString)") else { return }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }

            self.dayType = try JSONDecoder().decode(DayTypeInfo.self, from: data)

        } catch {
            print("Failed to load day type: \(error)")
        }
    }

    // MARK: - Task Suggestions

    /// Load AI-generated task suggestions for the selected date.
    func loadTaskSuggestions() async {
        isLoadingTaskSuggestions = true

        do {
            let suggestions = try await apiService.getTaskSuggestions(date: selectedDate)
            self.taskSuggestions = suggestions.filter { $0.status == .pending || $0.status == .shown }

            // Mark suggestions as shown
            for suggestion in self.taskSuggestions {
                try? await apiService.markSuggestionShown(suggestionId: suggestion.id)
            }

            print("💡 Loaded \(taskSuggestions.count) task suggestions")
        } catch {
            print("Failed to load task suggestions: \(error)")
            // Don't show error to user - task suggestions are optional
        }

        isLoadingTaskSuggestions = false
    }

    /// Accept a task suggestion - creates a real task.
    func acceptTaskSuggestion(_ suggestion: TaskSuggestion) async {
        do {
            let response = try await apiService.acceptTaskSuggestion(
                suggestionId: suggestion.id,
                scheduledDate: selectedDate,
                scheduledTime: nil
            )

            if response.success {
                // Remove from local list
                withAnimation {
                    taskSuggestions.removeAll { $0.id == suggestion.id }
                }

                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                print("✅ Accepted task suggestion: \(suggestion.suggestedTitle)")
            }
        } catch {
            print("Failed to accept task suggestion: \(error)")
            errorMessage = "Failed to add task"
        }
    }

    /// Dismiss a task suggestion - user doesn't want it.
    func dismissTaskSuggestion(_ suggestion: TaskSuggestion) async {
        do {
            try await apiService.dismissTaskSuggestion(suggestionId: suggestion.id)

            // Remove from local list
            withAnimation {
                taskSuggestions.removeAll { $0.id == suggestion.id }
            }

            print("❌ Dismissed task suggestion: \(suggestion.suggestedTitle)")
        } catch {
            print("Failed to dismiss task suggestion: \(error)")
        }
    }

    /// Load all data for the view.
    func loadAllData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadSuggestions() }
            group.addTask { await self.loadTaskSuggestions() }
            group.addTask { await self.loadUserInterests() }
        }
    }

    // MARK: - Load User Interests

    /// Load user interests from the server
    func loadUserInterests() async {
        guard let userId = UserDefaults.standard.value(forKey: "userId") as? Int64 else {
            print("❌ loadUserInterests: No userId found")
            return
        }
        guard let token = KeychainManager.shared.getAccessToken() else {
            print("❌ loadUserInterests: No access token")
            return
        }

        guard let url = URL(string: "\(Constants.API.baseURL)/api/v1/interests") else { return }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(String(userId), forHTTPHeaderField: "X-User-ID")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("📥 loadUserInterests response: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    if let responseStr = String(data: data, encoding: .utf8) {
                        print("❌ loadUserInterests error response: \(responseStr)")
                    }
                    return
                }
            }

            // Debug: print raw response
            if let jsonStr = String(data: data, encoding: .utf8) {
                print("📋 Interests raw response: \(jsonStr)")
            }

            self.userInterests = try JSONDecoder().decode(UserInterests.self, from: data)
            self.needsInterestsSetup = !(userInterests?.setupCompleted ?? false)

            print("💜 Loaded user interests: activities=\(userInterests?.activityInterests.count ?? 0), lifestyle=\(userInterests?.lifestyleInterests.count ?? 0), social=\(userInterests?.socialInterests.count ?? 0), setupCompleted=\(userInterests?.setupCompleted ?? false)")
        } catch {
            print("❌ Failed to load user interests: \(error)")
        }
    }

    // MARK: - Generate AI Weekend Plan

    /// Generate an AI-powered weekend plan using user interests and location
    func generateAIWeekendPlan() async {
        print("🚀 generateAIWeekendPlan called")
        print("   - userInterests: \(userInterests != nil ? "present" : "nil")")
        print("   - setupCompleted: \(userInterests?.setupCompleted ?? false)")
        print("   - hasAnyInterests: \(userInterests?.hasAnyInterests ?? false)")

        // Check if we have interests - be more lenient
        guard let interests = userInterests else {
            print("❌ No userInterests loaded - loading now...")
            await loadUserInterests()

            // Check again after loading
            guard let interests = userInterests else {
                needsInterestsSetup = true
                errorMessage = "Please set up your interests first to get personalized recommendations"
                return
            }

            // Continue with loaded interests
            await generatePlanWithInterests(interests)
            return
        }

        // Check if setup is completed or if they at least have some interests
        if !interests.setupCompleted && !interests.hasAnyInterests {
            needsInterestsSetup = true
            errorMessage = "Please set up your interests first to get personalized recommendations"
            print("❌ No interests set up")
            return
        }

        await generatePlanWithInterests(interests)
    }

    private func generatePlanWithInterests(_ interests: UserInterests) async {
        isGeneratingWeekendPlan = true
        errorMessage = nil
        weekendPlan = nil

        print("🔄 Generating plan with interests:")
        print("   - Activities: \(interests.activityInterests)")
        print("   - Lifestyle: \(interests.lifestyleInterests)")
        print("   - Social: \(interests.socialInterests)")

        // Request location if not available
        if locationManager.location == nil {
            print("📍 Requesting location...")
            locationManager.getCurrentLocation()
            // Wait briefly for location
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }

        print("📍 Location: \(locationManager.locationString ?? "unknown")")

        do {
            let plan = try await aiPlannerService.generateWeekendPlan(
                date: selectedDate,
                interests: interests,
                location: locationManager.location,
                locationName: locationManager.locationString
            )

            self.weekendPlan = plan
            print("✅ Generated AI weekend plan with \(plan.activities.count) activities")

        } catch {
            errorMessage = "Failed to generate plan: \(error.localizedDescription)"
            print("❌ Failed to generate AI weekend plan: \(error)")
        }

        isGeneratingWeekendPlan = false
    }

    // MARK: - Computed Properties for Weekend

    /// Check if the selected date is a weekend
    var isWeekend: Bool {
        Calendar.current.isDateInWeekend(selectedDate)
    }

    /// Check if the selected date is a free day off (weekend or holiday)
    var isFreeDayOff: Bool {
        isWeekend || (dayType?.isHoliday ?? false) || (dayType?.isRestDay ?? false)
    }

    /// Check if location is available
    var hasLocation: Bool {
        locationManager.location != nil
    }

    /// Get location string for display
    var locationString: String? {
        locationManager.locationString
    }

    /// Request location permission
    func requestLocation() {
        locationManager.requestLocationPermission()
    }
}
