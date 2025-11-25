import Foundation
import Combine

@MainActor
class DailySummaryViewModel: ObservableObject {
    @Published var summary: DailyAISummaryResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedDate = Date()
    
    private let apiService = APIService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Don't load summary in init - let the view trigger loading on appear
        // This prevents blocking the app initialization
    }
    
    func loadSummary(for date: Date) async {
        selectedDate = date
        isLoading = true
        errorMessage = nil
        
        do {
            summary = try await apiService.getDailyAISummary(date: date)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            print("❌ DailySummaryViewModel: Failed to load summary: \(error.localizedDescription)")
        }
    }
    
    func refreshSummary() async {
        await loadSummary(for: selectedDate)
    }
    
    func selectDate(_ date: Date) {
        Task {
            await loadSummary(for: date)
        }
    }
}

