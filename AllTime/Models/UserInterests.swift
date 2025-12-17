import Foundation

// MARK: - User Interests Model

struct UserInterests: Codable {
    var activityInterests: [String]
    var lifestyleInterests: [String]
    var socialInterests: [String]
    var preferredWeekendPace: String?
    var preferredOutingDistance: String?
    var budgetPreference: String?
    var preferredStartTime: String?
    var maxDailyActivities: Int?
    var setupCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case activityInterests = "activity_interests"
        case lifestyleInterests = "lifestyle_interests"
        case socialInterests = "social_interests"
        case preferredWeekendPace = "preferred_weekend_pace"
        case preferredOutingDistance = "preferred_outing_distance"
        case budgetPreference = "budget_preference"
        case preferredStartTime = "preferred_start_time"
        case maxDailyActivities = "max_daily_activities"
        case setupCompleted = "setup_completed"
    }

    init() {
        self.activityInterests = []
        self.lifestyleInterests = []
        self.socialInterests = []
        self.preferredWeekendPace = "balanced"
        self.preferredOutingDistance = "moderate"
        self.budgetPreference = "moderate"
        self.setupCompleted = false
    }

    var hasAnyInterests: Bool {
        !activityInterests.isEmpty || !lifestyleInterests.isEmpty || !socialInterests.isEmpty
    }
}

// MARK: - Interest Options Response

struct InterestOptionsResponse: Codable {
    let activityOptions: [InterestOption]
    let lifestyleOptions: [InterestOption]
    let socialOptions: [InterestOption]
    let paceOptions: [String]
    let distanceOptions: [String]
    let budgetOptions: [String]

    enum CodingKeys: String, CodingKey {
        case activityOptions = "activity_options"
        case lifestyleOptions = "lifestyle_options"
        case socialOptions = "social_options"
        case paceOptions = "pace_options"
        case distanceOptions = "distance_options"
        case budgetOptions = "budget_options"
    }
}

struct InterestOption: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let description: String?
}

// MARK: - Interest Category

enum InterestCategory: String, CaseIterable {
    case activity = "Activity"
    case lifestyle = "Lifestyle"
    case social = "Social"

    var color: String {
        switch self {
        case .activity: return "10B981"  // Green
        case .lifestyle: return "8B5CF6" // Purple
        case .social: return "F59E0B"    // Orange
        }
    }

    var icon: String {
        switch self {
        case .activity: return "figure.run"
        case .lifestyle: return "book.fill"
        case .social: return "person.3.fill"
        }
    }
}

// MARK: - Predefined Interest Options

struct InterestOptions {
    static let activity: [InterestOption] = [
        InterestOption(id: "hiking", name: "Hiking", icon: "figure.hiking", description: "Trail walks and nature exploration"),
        InterestOption(id: "gym", name: "Gym/Fitness", icon: "dumbbell.fill", description: "Workout and strength training"),
        InterestOption(id: "yoga", name: "Yoga", icon: "figure.yoga", description: "Yoga and meditation"),
        InterestOption(id: "running", name: "Running", icon: "figure.run", description: "Jogging and running"),
        InterestOption(id: "cycling", name: "Cycling", icon: "bicycle", description: "Biking and cycling"),
        InterestOption(id: "swimming", name: "Swimming", icon: "figure.pool.swim", description: "Pool or open water swimming"),
        InterestOption(id: "golf", name: "Golf", icon: "figure.golf", description: "Golfing"),
        InterestOption(id: "tennis", name: "Tennis", icon: "tennisball.fill", description: "Tennis and racquet sports"),
        InterestOption(id: "basketball", name: "Basketball", icon: "basketball.fill", description: "Basketball"),
        InterestOption(id: "beach", name: "Beach", icon: "beach.umbrella.fill", description: "Beach activities")
    ]

    static let lifestyle: [InterestOption] = [
        InterestOption(id: "reading", name: "Reading", icon: "book.fill", description: "Books and reading"),
        InterestOption(id: "cooking", name: "Cooking", icon: "fork.knife", description: "Cooking and trying recipes"),
        InterestOption(id: "gaming", name: "Gaming", icon: "gamecontroller.fill", description: "Video games"),
        InterestOption(id: "photography", name: "Photography", icon: "camera.fill", description: "Taking photos"),
        InterestOption(id: "gardening", name: "Gardening", icon: "leaf.fill", description: "Plants and gardening"),
        InterestOption(id: "music", name: "Music", icon: "music.note", description: "Playing or listening to music"),
        InterestOption(id: "art", name: "Arts & Crafts", icon: "paintpalette.fill", description: "Drawing, painting, crafts"),
        InterestOption(id: "movies", name: "Movies/TV", icon: "tv.fill", description: "Watching films and shows"),
        InterestOption(id: "podcasts", name: "Podcasts", icon: "headphones", description: "Listening to podcasts")
    ]

    static let social: [InterestOption] = [
        InterestOption(id: "family_time", name: "Family Time", icon: "figure.2.and.child.holdinghands", description: "Spending time with family"),
        InterestOption(id: "dining_out", name: "Dining Out", icon: "fork.knife.circle.fill", description: "Restaurants and food experiences"),
        InterestOption(id: "movies_theater", name: "Movies Theater", icon: "film.fill", description: "Going to the cinema"),
        InterestOption(id: "concerts", name: "Concerts/Live Music", icon: "music.mic", description: "Live music events"),
        InterestOption(id: "sports_events", name: "Sports Events", icon: "sportscourt.fill", description: "Watching live sports"),
        InterestOption(id: "friends", name: "Friends Hangout", icon: "person.3.fill", description: "Hanging out with friends"),
        InterestOption(id: "volunteering", name: "Volunteering", icon: "heart.fill", description: "Community service"),
        InterestOption(id: "museums", name: "Museums & Culture", icon: "building.columns.fill", description: "Museums and cultural venues"),
        InterestOption(id: "shopping", name: "Shopping", icon: "bag.fill", description: "Shopping and retail")
    ]

    static let paceOptions = ["relaxed", "balanced", "active"]
    static let distanceOptions = ["nearby", "moderate", "willing_to_travel"]
    static let budgetOptions = ["budget", "moderate", "premium"]
}
