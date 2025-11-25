import SwiftUI
import Foundation

// MARK: - Event Type Detection
extension Event {
    /// Detects event type from title keywords
    var eventType: EventType {
        let titleLower = title.lowercased()
        
        // Meeting keywords
        if titleLower.contains("meeting") || 
           titleLower.contains("standup") || 
           titleLower.contains("sync") ||
           titleLower.contains("call") ||
           titleLower.contains("conference") ||
           titleLower.contains("zoom") ||
           titleLower.contains("teams") ||
           titleLower.contains("google meet") {
            return .meeting
        }
        
        // Reminder keywords
        if titleLower.contains("reminder") ||
           titleLower.contains("remind") ||
           titleLower.contains("todo") ||
           titleLower.contains("task") ||
           titleLower.contains("follow up") ||
           titleLower.contains("follow-up") {
            return .reminder
        }
        
        // Holiday keywords
        if titleLower.contains("holiday") ||
           titleLower.contains("vacation") ||
           titleLower.contains("break") ||
           titleLower.contains("christmas") ||
           titleLower.contains("thanksgiving") ||
           titleLower.contains("new year") ||
           titleLower.contains("easter") ||
           titleLower.contains("independence day") ||
           titleLower.contains("memorial day") ||
           titleLower.contains("labor day") {
            return .holiday
        }
        
        // Fitness keywords
        if titleLower.contains("workout") ||
           titleLower.contains("gym") ||
           titleLower.contains("exercise") ||
           titleLower.contains("run") ||
           titleLower.contains("yoga") ||
           titleLower.contains("fitness") ||
           titleLower.contains("training") ||
           titleLower.contains("cycling") ||
           titleLower.contains("swim") {
            return .fitness
        }
        
        // Personal keywords
        if titleLower.contains("birthday") ||
           titleLower.contains("anniversary") ||
           titleLower.contains("dinner") ||
           titleLower.contains("lunch") ||
           titleLower.contains("breakfast") ||
           titleLower.contains("date") ||
           titleLower.contains("family") ||
           titleLower.contains("personal") {
            return .personal
        }
        
        // Work keywords
        if titleLower.contains("deadline") ||
           titleLower.contains("review") ||
           titleLower.contains("presentation") ||
           titleLower.contains("interview") ||
           titleLower.contains("project") ||
           titleLower.contains("workshop") ||
           titleLower.contains("seminar") {
            return .work
        }
        
        // Default
        return .general
    }
}

enum EventType: String, CaseIterable {
    case meeting = "Meeting"
    case reminder = "Reminder"
    case holiday = "Holiday"
    case fitness = "Fitness"
    case personal = "Personal"
    case work = "Work"
    case general = "General"
    
    var icon: String {
        switch self {
        case .meeting:
            return "video.fill"
        case .reminder:
            return "bell.fill"
        case .holiday:
            return "gift.fill"
        case .fitness:
            return "figure.run"
        case .personal:
            return "heart.fill"
        case .work:
            return "briefcase.fill"
        case .general:
            return "calendar"
        }
    }
    
    var color: Color {
        switch self {
        case .meeting:
            return Color(hex: "4285F4") // Google Blue
        case .reminder:
            return Color(hex: "FF9500") // Orange
        case .holiday:
            return Color(hex: "FF6B6B") // Red
        case .fitness:
            return Color(hex: "34C759") // Green
        case .personal:
            return Color(hex: "FF69B4") // Pink
        case .work:
            return Color(hex: "5856D6") // Purple
        case .general:
            return Color(hex: "8E8E93") // Gray
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .meeting:
            return LinearGradient(
                colors: [Color(hex: "4285F4"), Color(hex: "1A73E8")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .reminder:
            return LinearGradient(
                colors: [Color(hex: "FF9500"), Color(hex: "FF6B00")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .holiday:
            return LinearGradient(
                colors: [Color(hex: "FF6B6B"), Color(hex: "FF4757")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .fitness:
            return LinearGradient(
                colors: [Color(hex: "34C759"), Color(hex: "30D158")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .personal:
            return LinearGradient(
                colors: [Color(hex: "FF69B4"), Color(hex: "FF1493")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .work:
            return LinearGradient(
                colors: [Color(hex: "5856D6"), Color(hex: "5E5CE6")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .general:
            return LinearGradient(
                colors: [Color(hex: "8E8E93"), Color(hex: "636366")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

