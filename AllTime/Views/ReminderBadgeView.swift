import SwiftUI

struct ReminderBadgeView: View {
    let eventId: Int64
    @State private var reminderCount: Int = 0
    @State private var isLoading = false
    
    private let apiService = APIService()
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            } else if reminderCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "bell.fill")
                        .font(.caption2)
                    Text("\(reminderCount)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.15))
                .foregroundColor(.orange)
                .cornerRadius(8)
            }
        }
        .onAppear {
            loadReminderCount()
        }
    }
    
    private func loadReminderCount() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                let reminders = try await apiService.getRemindersForEvent(eventId: eventId)
                let pendingCount = reminders.filter { $0.status == .pending }.count
                await MainActor.run {
                    reminderCount = pendingCount
                    isLoading = false
                }
            } catch {
                print("Error loading reminder count: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    HStack {
        ReminderBadgeView(eventId: 123)
            .onAppear {
                // Preview won't load, but shows the UI
            }
    }
    .padding()
}

