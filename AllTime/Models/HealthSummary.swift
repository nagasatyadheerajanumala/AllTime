import Foundation

// MARK: - Health Summary Response (GET /api/v1/health/summary)

struct HealthSummaryResponse: Codable {
    let summary: HealthSummary
    let createdAt: Date
    let expiresAt: Date
    
    enum CodingKeys: String, CodingKey {
        case summary
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
}

struct HealthSummary: Codable {
    let overview: String
    let keyMetrics: KeyMetrics
    let trends: [TrendItem]
    let suggestions: [HealthSuggestionItem]
    
    enum CodingKeys: String, CodingKey {
        case overview
        case keyMetrics = "key_metrics"
        case trends
        case suggestions
    }
}

struct KeyMetrics: Codable {
    let averageSteps: Double?
    let averageSleepHours: Double?
    let averageActiveMinutes: Double?
    let averageRestingHeartRate: Double?
    let averageHRV: Double?
    let averageActiveEnergy: Double?
    
    enum CodingKeys: String, CodingKey {
        case averageSteps = "average_steps"
        case averageSleepHours = "average_sleep_hours"
        case averageActiveMinutes = "average_active_minutes"
        case averageRestingHeartRate = "average_resting_heart_rate"
        case averageHRV = "average_hrv"
        case averageActiveEnergy = "average_active_energy"
    }
}

struct TrendItem: Codable, Identifiable {
    let id: String
    let metric: String
    let direction: String // "improving" | "declining" | "stable"
    let changePercentage: Double?
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case metric
        case direction
        case changePercentage = "change_percentage"
        case description
    }
}

// MARK: - Health Suggestion Item

struct HealthSuggestionItem: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let category: SuggestionCategory
    let priority: SuggestionPriority
    let actionable: Bool
    let estimatedImpact: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case category
        case priority
        case actionable
        case estimatedImpact = "estimated_impact"
    }
}

enum SuggestionCategory: String, Codable {
    case sleep = "sleep"
    case activity = "activity"
    case heart = "heart"
    case nutrition = "nutrition"
    case recovery = "recovery"
    case stress = "stress"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .sleep: return "Sleep"
        case .activity: return "Activity"
        case .heart: return "Heart Health"
        case .nutrition: return "Nutrition"
        case .recovery: return "Recovery"
        case .stress: return "Stress"
        case .general: return "General"
        }
    }
    
    var icon: String {
        switch self {
        case .sleep: return "bed.double.fill"
        case .activity: return "figure.run"
        case .heart: return "heart.fill"
        case .nutrition: return "fork.knife"
        case .recovery: return "leaf.fill"
        case .stress: return "brain.head.profile"
        case .general: return "sparkles"
        }
    }
}

enum SuggestionPriority: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "blue"
        case .medium: return "orange"
        case .high: return "red"
        case .urgent: return "purple"
        }
    }
}

// MARK: - Generate Suggestions Request (POST /api/v1/health/suggestions)
// UPDATED: start_date and end_date are now optional (removed from API)
// The service automatically analyzes past 14 days + next 14 days

struct GenerateSuggestionsRequest: Codable {
    // Optional for backward compatibility, but backend no longer uses these
    let startDate: String?
    let endDate: String?
    let timezone: String?
    
    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
        case timezone
    }
    
    // Convenience initializer for new API format (no dates)
    init(timezone: String? = nil) {
        self.startDate = nil
        self.endDate = nil
        self.timezone = timezone
    }
}

// MARK: - Generate Suggestions Response (POST /api/v1/health/suggestions)
// UPDATED: Now includes Advanced AI Summary fields

struct GenerateSuggestionsResponse: Codable {
    // Legacy fields (still supported for backward compatibility)
    let summary: HealthSummary?
    let createdAt: Date?
    let expiresAt: Date?
    
    // NEW: Advanced AI Summary fields
    let advancedSummary: AdvancedSummary?
    let patterns: [String]?
    let eventSpecificAdvice: [EventAdvice]?
    let healthSuggestions: [HealthSuggestion]?
    
    enum CodingKeys: String, CodingKey {
        case summary // Can be either HealthSummary or AdvancedSummary
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case patterns
        case eventSpecificAdvice = "event_specific_advice"
        case healthSuggestions = "health_suggestions"
    }
    
    // Custom decoder to handle both old and new response formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // The "summary" field can be either:
        // 1. Old format: HealthSummary object (with overview, keyMetrics, trends, suggestions)
        // 2. New format: AdvancedSummary object (with this_week and next_week)
        
        // Try to decode "summary" field - check which format it is
        if container.contains(.summary) {
            // Try new format first (AdvancedSummary with this_week and next_week)
            if let advanced = try? container.decode(AdvancedSummary.self, forKey: .summary) {
                self.advancedSummary = advanced
                self.summary = nil
            } else {
                // Try old format (HealthSummary)
                self.advancedSummary = nil
                self.summary = try? container.decode(HealthSummary.self, forKey: .summary)
            }
        } else {
            // No summary field
            self.advancedSummary = nil
            self.summary = nil
        }
        
        // Decode optional fields
        self.createdAt = try? container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.expiresAt = try? container.decodeIfPresent(Date.self, forKey: .expiresAt)
        self.patterns = try? container.decodeIfPresent([String].self, forKey: .patterns)
        self.eventSpecificAdvice = try? container.decodeIfPresent([EventAdvice].self, forKey: .eventSpecificAdvice)
        self.healthSuggestions = try? container.decodeIfPresent([HealthSuggestion].self, forKey: .healthSuggestions)
    }
}

// MARK: - Advanced Summary (NEW)

struct AdvancedSummary: Codable {
    let thisWeek: String
    let nextWeek: String
    
    enum CodingKeys: String, CodingKey {
        case thisWeek = "this_week"
        case nextWeek = "next_week"
    }
}

// MARK: - Event Advice (NEW)

struct EventAdvice: Codable, Identifiable {
    let eventTitle: String
    let date: String
    let issue: String
    let suggestion: String
    
    var id: String {
        "\(eventTitle)-\(date)"
    }
    
    enum CodingKeys: String, CodingKey {
        case eventTitle = "event_title"
        case date, issue, suggestion
    }
}

// MARK: - Health Suggestion (NEW - simplified format)

struct HealthSuggestion: Codable, Identifiable {
    let metric: String
    let description: String
    
    var id: String {
        metric
    }
}

// MARK: - User Health Goals (GET /api/v1/health/goals)
// Note: No explicit CodingKeys - uses automatic snake_case conversion from CacheService/APIService

struct UserHealthGoals: Codable {
    let sleepHours: Double?
    let activeEnergyBurned: Double?
    let hrv: Double?
    let restingHeartRate: Double?
    let activeMinutes: Int?
    let steps: Int?
    let updatedAt: Date?
}

// MARK: - Save Goals Request (POST /api/v1/health/goals)
// Note: No explicit CodingKeys - uses automatic snake_case conversion from APIService

struct SaveGoalsRequest: Codable {
    let sleepHours: Double?
    let activeEnergyBurned: Double?
    let hrv: Double?
    let restingHeartRate: Double?
    let activeMinutes: Int?
    let steps: Int?
}

// MARK: - Save Goals Response (POST /api/v1/health/goals)

struct SaveGoalsResponse: Codable {
    let goals: UserHealthGoals
    let message: String?
}

