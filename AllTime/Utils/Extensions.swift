import Foundation
import SwiftUI

// MARK: - Date Extensions
extension Date {
    func startOfDay() -> Date {
        Calendar.current.startOfDay(for: self)
    }
    
    func endOfDay() -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay())?.addingTimeInterval(-1) ?? self
    }
    
    func isSameDay(as date: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: date)
    }
    
    func isToday() -> Bool {
        Calendar.current.isDateInToday(self)
    }
    
    func isTomorrow() -> Bool {
        Calendar.current.isDateInTomorrow(self)
    }
    
    func isYesterday() -> Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    func formatted(style: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        return formatter.string(from: self)
    }
    
    func timeString() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

// MARK: - Color Extensions
extension Color {
    static let primaryBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let secondaryBlue = Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.1)
    
    static let calendarBackground = Color(.systemBackground)
    static let calendarSecondary = Color(.secondarySystemBackground)
    static let calendarTertiary = Color(.tertiarySystemBackground)
}

// MARK: - View Extensions
extension View {
    func cardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    func sectionHeader() -> some View {
        self
            .font(.headline)
            .foregroundColor(.primary)
            .padding(.horizontal)
            .padding(.top, 16)
    }
    
    func loadingOverlay() -> some View {
        self.overlay {
            if true { // This would be a binding in real usage
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
    }
}

// MARK: - String Extensions
extension String {
    func truncate(to length: Int) -> String {
        if self.count <= length {
            return self
        }
        return String(self.prefix(length)) + "..."
    }
    
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }
}

// MARK: - Array Extensions
extension Array where Element == Event {
    func eventsForDate(_ date: Date) -> [Event] {
        let calendar = Calendar.current
        return self.filter { event in
            guard let eventDate = event.startDate else { return false }
            return calendar.isDate(eventDate, inSameDayAs: date)
        }
    }
    
    func eventsForToday() -> [Event] {
        eventsForDate(Date())
    }
    
    func nextEvent() -> Event? {
        let now = Date()
        return self
            .filter { event in
                guard let startDate = event.startDate else { return false }
                return startDate > now
            }
            .sorted { event1, event2 in
                guard let start1 = event1.startDate, let start2 = event2.startDate else { return false }
                return start1 < start2
            }
            .first
    }
}

