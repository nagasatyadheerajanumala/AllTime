import Foundation

// MARK: - Check-In Status Response
struct CheckInStatusResponse: Codable {
    let date: String?
    let morningCheckInDone: Bool
    let afternoonCheckInDone: Bool
    let eveningCheckInDone: Bool
    let pendingEventFeedback: [PendingEventFeedback]?
    let totalCheckIns: Int
    let streakDays: Int
    let dataQualityScore: Int
    let nextSuggestedCheckIn: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case date
        case morningCheckInDone = "morning_check_in_done"
        case afternoonCheckInDone = "afternoon_check_in_done"
        case eveningCheckInDone = "evening_check_in_done"
        case pendingEventFeedback = "pending_event_feedback"
        case totalCheckIns = "total_check_ins"
        case streakDays = "streak_days"
        case dataQualityScore = "data_quality_score"
        case nextSuggestedCheckIn = "next_suggested_check_in"
        case message
    }
}

struct PendingEventFeedback: Codable, Identifiable {
    let eventId: Int
    let eventTitle: String?
    let eventLocation: String?
    let eventTime: String?
    let feedbackType: String?

    var id: Int { eventId }

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case eventTitle = "event_title"
        case eventLocation = "event_location"
        case eventTime = "event_time"
        case feedbackType = "feedback_type"
    }
}

// MARK: - Mood Check-In Request
struct MoodCheckInRequest: Codable {
    let timeOfDay: String
    let energyLevel: Int
    let stressLevel: Int?
    let focusLevel: Int?
    let mood: String?
    let productivityRating: Int?
    let sleepQuality: Int?
    let sleepHours: Double?
    let notes: String?
    let source: String

    enum CodingKeys: String, CodingKey {
        case timeOfDay = "time_of_day"
        case energyLevel = "energy_level"
        case stressLevel = "stress_level"
        case focusLevel = "focus_level"
        case mood
        case productivityRating = "productivity_rating"
        case sleepQuality = "sleep_quality"
        case sleepHours = "sleep_hours"
        case notes
        case source
    }
}

// MARK: - Event Feedback Request
struct EventFeedbackRequest: Codable {
    let eventId: Int
    let travelTimeMinutes: Int?
    let wasLate: Bool?
    let minutesEarlyOrLate: Int?
    let energyBefore: Int?
    let energyAfter: Int?
    let eventRating: Int?
    let stressLevel: Int?
    let notes: String?
    let feedbackType: String

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case travelTimeMinutes = "travel_time_minutes"
        case wasLate = "was_late"
        case minutesEarlyOrLate = "minutes_early_or_late"
        case energyBefore = "energy_before"
        case energyAfter = "energy_after"
        case eventRating = "event_rating"
        case stressLevel = "stress_level"
        case notes
        case feedbackType = "feedback_type"
    }
}

// MARK: - Travel Feedback Request
struct TravelFeedbackRequest: Codable {
    let eventId: Int?
    let fromLocation: String?
    let fromLocationType: String?
    let toLocation: String
    let toLocationType: String?
    let travelMinutes: Int
    let transportMode: String?
    let trafficConditions: String?
    let wasOnTime: Bool?
    let source: String

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case fromLocation = "from_location"
        case fromLocationType = "from_location_type"
        case toLocation = "to_location"
        case toLocationType = "to_location_type"
        case travelMinutes = "travel_minutes"
        case transportMode = "transport_mode"
        case trafficConditions = "traffic_conditions"
        case wasOnTime = "was_on_time"
        case source
    }
}

// MARK: - Check-In Response
struct CheckInResponse: Codable {
    let success: Bool
    let checkInId: Int?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case checkInId = "check_in_id"
        case message
    }
}

// MARK: - Learning/Patterns Response
struct PatternsSummary: Codable {
    let learnedDestinations: Int
    let moodCheckIns: Int
    let eventFeedback: Int
    let canPredictTravel: Bool
    let canPredictEnergy: Bool
    let message: String?

    enum CodingKeys: String, CodingKey {
        case learnedDestinations = "learned_destinations"
        case moodCheckIns = "mood_check_ins"
        case eventFeedback = "event_feedback"
        case canPredictTravel = "can_predict_travel"
        case canPredictEnergy = "can_predict_energy"
        case message
    }
}

struct EnergyPrediction: Codable {
    let timeOfDay: String
    let predictedLevel: Double
    let confidenceLevel: String
    let basedOn: String
    let sleepCorrelation: Double?
    let optimalSleepHours: Double?

    enum CodingKeys: String, CodingKey {
        case timeOfDay = "time_of_day"
        case predictedLevel = "predicted_level"
        case confidenceLevel = "confidence_level"
        case basedOn = "based_on"
        case sleepCorrelation = "sleep_correlation"
        case optimalSleepHours = "optimal_sleep_hours"
    }
}

struct TimeSlotRecommendation: Codable, Identifiable {
    let timeSlot: String
    let period: String
    let averageEnergy: Double
    let recommendation: String

    var id: String { timeSlot }

    enum CodingKeys: String, CodingKey {
        case timeSlot = "time_slot"
        case period
        case averageEnergy = "average_energy"
        case recommendation
    }
}

// MARK: - Mood Options
enum MoodOption: String, CaseIterable, Identifiable {
    case great = "great"
    case good = "good"
    case okay = "okay"
    case tired = "tired"
    case stressed = "stressed"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .great: return "😊"
        case .good: return "🙂"
        case .okay: return "😐"
        case .tired: return "😴"
        case .stressed: return "😰"
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

enum TimeOfDay: String, CaseIterable {
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"

    var displayName: String {
        rawValue.capitalized
    }

    var timeRange: String {
        switch self {
        case .morning: return "5am - 12pm"
        case .afternoon: return "12pm - 5pm"
        case .evening: return "5pm - 10pm"
        }
    }

    static var current: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 5 && hour < 12 {
            return .morning
        } else if hour >= 12 && hour < 17 {
            return .afternoon
        } else {
            return .evening
        }
    }
}
