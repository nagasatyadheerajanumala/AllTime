import Foundation

extension Double {
    /// Convert kilometers to miles
    var kmToMiles: Double {
        self * 0.621371
    }
    
    /// Convert miles to kilometers
    var milesToKm: Double {
        self * 1.60934
    }
}

/// Distance conversion helper
struct DistanceConverter {
    static func kmToMiles(_ km: Double) -> Double {
        km * 0.621371
    }
    
    static func milesToKm(_ miles: Double) -> Double {
        miles * 1.60934
    }
    
    static func formatDistance(km: Double, showMiles: Bool = true) -> String {
        if showMiles {
            let miles = kmToMiles(km)
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.1f km", km)
        }
    }
}

/// Walking speed conversion (average: 3 mph or 5 km/h)
struct WalkingTime {
    /// Calculate estimated minutes for distance in miles at average speed (3 mph)
    static func estimatedMinutes(miles: Double) -> Int {
        Int(miles * 20) // 3 mph = 20 min/mile
    }
    
    /// Calculate distance in miles for duration in minutes at average speed (3 mph)
    static func estimatedMiles(minutes: Int) -> Double {
        Double(minutes) / 20.0
    }
}

