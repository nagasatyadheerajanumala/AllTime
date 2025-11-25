import Foundation
import Combine

@MainActor
class SummaryViewModel: ObservableObject {
    @Published var todaySummary: DailySummary?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let summaryManager: SummaryManager
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.summaryManager = SummaryManager()
        
        // Subscribe to summary manager updates
        summaryManager.$todaySummary
            .assign(to: &$todaySummary)
        
        summaryManager.$isLoading
            .assign(to: &$isLoading)
        
        summaryManager.$errorMessage
            .assign(to: &$errorMessage)
    }
    
    func fetchTodaySummary() {
        summaryManager.fetchTodaySummary()
    }
    
    func refreshSummary() {
        summaryManager.fetchTodaySummary()
    }
}

