import Foundation

// MARK: - Event Location (Structured)

struct EventLocation: Codable {
    let name: String?
    let address: String?
    let coordinates: LocationCoordinates?
    
    // No explicit CodingKeys needed - backend sends camelCase for location object
    // If backend sends snake_case, we'll add CodingKeys here
}

struct LocationCoordinates: Codable {
    let latitude: Double?
    let longitude: Double?
    
    // No explicit CodingKeys needed - backend sends camelCase
}

// MARK: - Event Attendee (Structured)

struct EventAttendee: Codable, Identifiable {
    let email: String?
    let name: String?
    let responseStatus: String?  // "accepted", "declined", "tentative", "needsAction"
    
    // Use email as ID if available
    var id: String {
        email ?? name ?? UUID().uuidString
    }
    
    // Public initializer for creating EventAttendee instances manually
    init(email: String?, name: String?, responseStatus: String?) {
        self.email = email
        self.name = name
        self.responseStatus = responseStatus
    }
    
    // Comprehensive CodingKeys to handle all possible field names
    enum CodingKeys: String, CodingKey {
        case email
        case name
        case displayName  // camelCase variant
        case display_name  // snake_case variant
        case responseStatus  // camelCase variant
        case response_status  // snake_case variant
    }
    
    // Robust decoder that handles all possible backend formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Email is usually consistent
        email = try container.decodeIfPresent(String.self, forKey: .email)
        
        // Handle name field variations: name, displayName, display_name
        // Try in order of preference: name -> displayName -> display_name
        if let name = try container.decodeIfPresent(String.self, forKey: .name), !name.isEmpty {
            self.name = name
        } else if let displayName = try container.decodeIfPresent(String.self, forKey: .displayName), !displayName.isEmpty {
            self.name = displayName
        } else if let displayName = try container.decodeIfPresent(String.self, forKey: .display_name), !displayName.isEmpty {
            self.name = displayName
        } else {
            name = nil
        }
        
        // Handle responseStatus field variations: responseStatus, response_status
        if let status = try container.decodeIfPresent(String.self, forKey: .responseStatus), !status.isEmpty {
            responseStatus = status
        } else if let status = try container.decodeIfPresent(String.self, forKey: .response_status), !status.isEmpty {
            responseStatus = status
        } else {
            responseStatus = nil
        }
    }
    
    // Encoder for completeness
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(responseStatus, forKey: .responseStatus)
    }
}

// MARK: - Event Recurrence (Structured)

struct EventRecurrence: Codable {
    let isRecurring: Bool
    let frequency: String?  // "daily", "weekly", "monthly", "yearly"
    let interval: Int?  // How often (e.g., every 2 weeks = interval: 2)
    let recurrenceRule: String?  // Full recurrence rule string (e.g., RRULE)
    let recurrenceId: String?  // ID for recurring event instances
    
    enum CodingKeys: String, CodingKey {
        case isRecurring = "is_recurring"
        case frequency, interval
        case recurrenceRule = "recurrence_rule"
        case recurrenceId = "recurrence_id"
    }
    
    // Custom decoder to handle null values and missing fields gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // isRecurring should always be present, default to false if missing
        isRecurring = try container.decodeIfPresent(Bool.self, forKey: .isRecurring) ?? false
        
        // All other fields are optional
        frequency = try container.decodeIfPresent(String.self, forKey: .frequency)
        interval = try container.decodeIfPresent(Int.self, forKey: .interval)
        recurrenceRule = try container.decodeIfPresent(String.self, forKey: .recurrenceRule)
        recurrenceId = try container.decodeIfPresent(String.self, forKey: .recurrenceId)
    }
}

