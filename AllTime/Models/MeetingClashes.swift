import Foundation

// MARK: - Meeting Clash Detection Response (GET /api/v1/calendar/clashes)

struct ClashResponse: Codable {
    let clashesByDate: [String: [ClashInfo]]
    let totalClashes: Int
    
    enum CodingKeys: String, CodingKey {
        case clashesByDate = "clashes_by_date"
        case totalClashes = "total_clashes"
    }
}

struct ClashInfo: Codable, Identifiable {
    let eventA: EventInfo
    let eventB: EventInfo
    let overlapMinutes: Int
    let severity: String
    
    // Computed property for Identifiable
    var id: String {
        "\(eventA.id)-\(eventB.id)-\(overlapMinutes)"
    }
    
    enum CodingKeys: String, CodingKey {
        case eventA = "event_a"
        case eventB = "event_b"
        case overlapMinutes = "overlap_minutes"
        case severity
    }
    
    // Computed properties for UI
    var severityColor: Color {
        switch severity.lowercased() {
        case "red":
            return .red
        case "orange":
            return .orange
        default:
            return .gray
        }
    }
    
    var severityIcon: String {
        switch severity.lowercased() {
        case "red":
            return "exclamationmark.triangle.fill"
        case "orange":
            return "exclamationmark.circle.fill"
        default:
            return "info.circle.fill"
        }
    }
}

struct EventInfo: Codable {
    let id: Int64
    let title: String
    let source: String
    let startTime: String
    let endTime: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, source
        case startTime = "start_time"
        case endTime = "end_time"
    }
    
    // Computed properties for date parsing
    var startDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: startTime)
    }
    
    var endDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: endTime)
    }
    
    var formattedTime: String {
        guard let start = startDate, let end = endDate else {
            return "Unknown time"
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.timeZone = TimeZone.current
        
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

// Import SwiftUI for Color
import SwiftUI

