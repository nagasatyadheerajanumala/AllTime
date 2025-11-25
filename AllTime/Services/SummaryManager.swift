import Foundation
import Combine

@MainActor
class SummaryManager: ObservableObject {
    @Published var todaySummary: DailySummary?
    @Published var preferences: SummaryPreferences?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadPreferences()
    }
    
    // MARK: - Today's Summary
    
    func fetchTodaySummary() {
        print("📊 SummaryManager: Fetching today's summary...")
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let summary = try await apiService.fetchDailySummary(for: Date())
                todaySummary = summary
                isLoading = false
                print("📊 SummaryManager: Today's summary loaded successfully")
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                print("📊 SummaryManager: Failed to fetch today's summary: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchSummary(for date: Date) {
        print("📊 SummaryManager: Fetching summary for \(date)...")
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let summary = try await apiService.fetchDailySummary(for: date)
                todaySummary = summary
                isLoading = false
                print("📊 SummaryManager: Summary for \(date) loaded successfully")
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                print("📊 SummaryManager: Failed to fetch summary for \(date): \(error.localizedDescription)")
            }
        }
    }
    
    func forceGenerateSummary() {
        print("📊 SummaryManager: Force generating summary...")
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let summary = try await apiService.forceGenerateSummary()
                todaySummary = summary
                isLoading = false
                print("📊 SummaryManager: Summary generated successfully")
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                print("📊 SummaryManager: Failed to generate summary: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Preferences
    
    private func loadPreferences() {
        // Load from UserDefaults or set defaults
        if let data = UserDefaults.standard.data(forKey: "summary_preferences"),
           let prefs = try? JSONDecoder().decode(SummaryPreferences.self, from: data) {
            preferences = prefs
        } else {
            // Set default preferences
            preferences = SummaryPreferences(
                timezone: TimeZone.current.identifier,
                sendHour: 9,
                channel: "push",
                includePrivate: false
            )
        }
    }
    
    func fetchPreferences() {
        print("📊 SummaryManager: Fetching summary preferences...")
        
        Task {
            do {
                let prefs = try await apiService.fetchSummaryPreferences()
                preferences = prefs
                // Save to UserDefaults
                if let data = try? JSONEncoder().encode(prefs) {
                    UserDefaults.standard.set(data, forKey: "summary_preferences")
                }
                print("📊 SummaryManager: Preferences loaded successfully")
            } catch {
                print("📊 SummaryManager: Failed to fetch preferences: \(error.localizedDescription)")
            }
        }
    }
    
    func updatePreferences(_ prefs: SummaryPreferences) {
        print("📊 SummaryManager: Updating summary preferences...")
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await apiService.updateSummaryPreferences(prefs)
                preferences = prefs
                // Save to UserDefaults
                if let data = try? JSONEncoder().encode(prefs) {
                    UserDefaults.standard.set(data, forKey: "summary_preferences")
                }
                isLoading = false
                print("📊 SummaryManager: Preferences updated successfully")
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                print("📊 SummaryManager: Failed to update preferences: \(error.localizedDescription)")
            }
        }
    }
}

