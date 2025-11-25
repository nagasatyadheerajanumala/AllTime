import Foundation

// MARK: - Life Wheel Response
struct LifeWheelResponse: Codable {
    let startDate: String
    let endDate: String
    let distribution: [String: ContextDistribution]
    let totalEvents: Int?
    
    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
        case distribution
        case totalEvents = "total_events"
    }
}

// MARK: - Context Distribution
struct ContextDistribution: Codable {
    let minutes: Int
    let count: Int
}

