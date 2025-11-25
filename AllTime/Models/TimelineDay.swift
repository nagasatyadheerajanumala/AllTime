import Foundation

// MARK: - Timeline Day Response
struct TimelineDayResponse: Codable {
    let date: String
    let timezone: String
    let items: [TimelineItem]
    let totalEvents: Int?
    let totalGaps: Int?
    
    enum CodingKeys: String, CodingKey {
        case date
        case timezone
        case items
        case totalEvents = "total_events"
        case totalGaps = "total_gaps"
    }
}

// MARK: - Timeline Item (Polymorphic)
enum TimelineItem: Codable, Identifiable {
    case event(EventItem)
    case gap(GapItem)
    
    var id: String {
        switch self {
        case .event(let event):
            return "event-\(event.id)"
        case .gap(let gap):
            return "gap-\(gap.startTime)-\(gap.endTime)"
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Decode as a dictionary first to inspect structure
        let dict = try container.decode([String: AnyCodable].self)
        
        // Determine type by checking for characteristic fields
        // Events have: id, title
        // Gaps have: duration_minutes (and no id/title)
        if dict["id"] != nil || dict["title"] != nil {
            // This is an event - decode as EventItem
            let eventData = try JSONSerialization.data(withJSONObject: dict.mapValues { $0.value })
            let eventDecoder = JSONDecoder()
            eventDecoder.keyDecodingStrategy = .convertFromSnakeCase
            let event = try eventDecoder.decode(EventItem.self, from: eventData)
            self = .event(event)
        } else if dict["duration_minutes"] != nil {
            // This is a gap - decode as GapItem
            let gapData = try JSONSerialization.data(withJSONObject: dict.mapValues { $0.value })
            let gapDecoder = JSONDecoder()
            gapDecoder.keyDecodingStrategy = .convertFromSnakeCase
            let gap = try gapDecoder.decode(GapItem.self, from: gapData)
            self = .gap(gap)
        } else {
            // Fallback: try to decode as event (most common case)
            let eventData = try JSONSerialization.data(withJSONObject: dict.mapValues { $0.value })
            let eventDecoder = JSONDecoder()
            eventDecoder.keyDecodingStrategy = .convertFromSnakeCase
            do {
                let event = try eventDecoder.decode(EventItem.self, from: eventData)
                self = .event(event)
            } catch {
                // If event fails, try gap
                let gapDecoder = JSONDecoder()
                gapDecoder.keyDecodingStrategy = .convertFromSnakeCase
                let gap = try gapDecoder.decode(GapItem.self, from: eventData)
                self = .gap(gap)
            }
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .event(let event):
            try container.encode(event)
        case .gap(let gap):
            try container.encode(gap)
        }
    }
}

// MARK: - Event Item
struct EventItem: Codable {
    let id: String
    let title: String
    let startTime: String
    let endTime: String
    let context: String?
    let location: String?
    let provider: String?
    let allDay: Bool?
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case startTime = "start_time"
        case endTime = "end_time"
        case context
        case location
        case provider
        case allDay = "all_day"
        case description
    }
}

// MARK: - Gap Item
struct GapItem: Codable {
    let startTime: String
    let endTime: String
    let durationMinutes: Int
    
    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case durationMinutes = "duration_minutes"
    }
}

