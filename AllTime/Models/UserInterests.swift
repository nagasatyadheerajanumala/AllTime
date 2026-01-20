import Foundation

// MARK: - User Interests Model

/// Response type alias for API compatibility
typealias UserInterestsResponse = UserInterests

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
        // Outdoor Activities
        InterestOption(id: "hiking", name: "Hiking", icon: "figure.hiking", description: "Trail walks and nature exploration"),
        InterestOption(id: "running", name: "Running", icon: "figure.run", description: "Jogging and running"),
        InterestOption(id: "cycling", name: "Cycling", icon: "bicycle", description: "Biking and cycling"),
        InterestOption(id: "swimming", name: "Swimming", icon: "figure.pool.swim", description: "Pool or open water swimming"),
        InterestOption(id: "beach", name: "Beach", icon: "beach.umbrella.fill", description: "Beach activities"),
        InterestOption(id: "camping", name: "Camping", icon: "tent.fill", description: "Outdoor camping adventures"),
        InterestOption(id: "kayaking", name: "Kayaking", icon: "sailboat.fill", description: "Kayaking and water sports"),
        InterestOption(id: "rock_climbing", name: "Rock Climbing", icon: "figure.climbing", description: "Indoor or outdoor climbing"),
        // Fitness
        InterestOption(id: "gym", name: "Gym/Fitness", icon: "dumbbell.fill", description: "Workout and strength training"),
        InterestOption(id: "yoga", name: "Yoga", icon: "figure.yoga", description: "Yoga and meditation"),
        InterestOption(id: "pilates", name: "Pilates", icon: "figure.pilates", description: "Pilates and core training"),
        InterestOption(id: "crossfit", name: "CrossFit", icon: "figure.highintensity.intervaltraining", description: "High-intensity training"),
        InterestOption(id: "dance", name: "Dance", icon: "figure.dance", description: "Dance classes and social dancing"),
        InterestOption(id: "martial_arts", name: "Martial Arts", icon: "figure.martial.arts", description: "Boxing, MMA, karate"),
        // Sports
        InterestOption(id: "golf", name: "Golf", icon: "figure.golf", description: "Golfing"),
        InterestOption(id: "tennis", name: "Tennis", icon: "tennisball.fill", description: "Tennis and racquet sports"),
        InterestOption(id: "basketball", name: "Basketball", icon: "basketball.fill", description: "Basketball"),
        InterestOption(id: "soccer", name: "Soccer", icon: "soccerball", description: "Soccer/Football"),
        InterestOption(id: "volleyball", name: "Volleyball", icon: "volleyball.fill", description: "Beach or indoor volleyball"),
        InterestOption(id: "skiing", name: "Skiing/Snowboarding", icon: "figure.skiing.downhill", description: "Winter sports"),
        InterestOption(id: "surfing", name: "Surfing", icon: "figure.surfing", description: "Surfing and paddleboarding")
    ]

    static let lifestyle: [InterestOption] = [
        // Creative
        InterestOption(id: "reading", name: "Reading", icon: "book.fill", description: "Books and reading"),
        InterestOption(id: "writing", name: "Writing", icon: "pencil.line", description: "Journaling, blogging, creative writing"),
        InterestOption(id: "photography", name: "Photography", icon: "camera.fill", description: "Taking photos"),
        InterestOption(id: "art", name: "Arts & Crafts", icon: "paintpalette.fill", description: "Drawing, painting, crafts"),
        InterestOption(id: "music", name: "Music", icon: "music.note", description: "Playing or listening to music"),
        InterestOption(id: "diy", name: "DIY Projects", icon: "hammer.fill", description: "Home improvement and crafts"),
        // Food & Drink
        InterestOption(id: "cooking", name: "Cooking", icon: "fork.knife", description: "Cooking and trying recipes"),
        InterestOption(id: "baking", name: "Baking", icon: "birthday.cake.fill", description: "Baking breads and desserts"),
        InterestOption(id: "wine_tasting", name: "Wine Tasting", icon: "wineglass.fill", description: "Wine and spirits exploration"),
        InterestOption(id: "coffee", name: "Coffee Culture", icon: "cup.and.saucer.fill", description: "Coffee shops and brewing"),
        // Entertainment
        InterestOption(id: "gaming", name: "Gaming", icon: "gamecontroller.fill", description: "Video games"),
        InterestOption(id: "movies", name: "Movies/TV", icon: "tv.fill", description: "Watching films and shows"),
        InterestOption(id: "podcasts", name: "Podcasts", icon: "headphones", description: "Listening to podcasts"),
        InterestOption(id: "board_games", name: "Board Games", icon: "dice.fill", description: "Board games and puzzles"),
        // Wellness
        InterestOption(id: "meditation", name: "Meditation", icon: "brain.head.profile", description: "Mindfulness and meditation"),
        InterestOption(id: "spa", name: "Spa & Wellness", icon: "sparkles", description: "Spa days and self-care"),
        InterestOption(id: "gardening", name: "Gardening", icon: "leaf.fill", description: "Plants and gardening"),
        // Learning
        InterestOption(id: "languages", name: "Languages", icon: "globe", description: "Learning new languages"),
        InterestOption(id: "tech", name: "Technology", icon: "laptopcomputer", description: "Tech and gadgets"),
        InterestOption(id: "finance", name: "Investing", icon: "chart.line.uptrend.xyaxis", description: "Finance and investing")
    ]

    static let social: [InterestOption] = [
        // People
        InterestOption(id: "family_time", name: "Family Time", icon: "figure.2.and.child.holdinghands", description: "Spending time with family"),
        InterestOption(id: "friends", name: "Friends Hangout", icon: "person.3.fill", description: "Hanging out with friends"),
        InterestOption(id: "date_nights", name: "Date Nights", icon: "heart.fill", description: "Romantic outings"),
        InterestOption(id: "networking", name: "Networking", icon: "person.2.badge.gearshape.fill", description: "Professional networking"),
        InterestOption(id: "pet_time", name: "Pet Activities", icon: "pawprint.fill", description: "Dog parks, pet playdates"),
        // Food & Nightlife
        InterestOption(id: "dining_out", name: "Dining Out", icon: "fork.knife.circle.fill", description: "Restaurants and food experiences"),
        InterestOption(id: "brunch", name: "Brunch", icon: "sun.haze.fill", description: "Weekend brunch spots"),
        InterestOption(id: "bars", name: "Bars & Nightlife", icon: "moon.stars.fill", description: "Bars, clubs, nightlife"),
        InterestOption(id: "food_tours", name: "Food Tours", icon: "map.fill", description: "Culinary exploration"),
        // Entertainment
        InterestOption(id: "movies_theater", name: "Movies Theater", icon: "film.fill", description: "Going to the cinema"),
        InterestOption(id: "concerts", name: "Concerts/Live Music", icon: "music.mic", description: "Live music events"),
        InterestOption(id: "theater", name: "Theater/Shows", icon: "theatermasks.fill", description: "Broadway, plays, comedy shows"),
        InterestOption(id: "sports_events", name: "Sports Events", icon: "sportscourt.fill", description: "Watching live sports"),
        InterestOption(id: "festivals", name: "Festivals", icon: "party.popper.fill", description: "Music and cultural festivals"),
        // Culture
        InterestOption(id: "museums", name: "Museums & Culture", icon: "building.columns.fill", description: "Museums and cultural venues"),
        InterestOption(id: "art_galleries", name: "Art Galleries", icon: "photo.artframe", description: "Art exhibitions"),
        InterestOption(id: "classes", name: "Group Classes", icon: "person.3.sequence.fill", description: "Cooking, art, fitness classes"),
        // Other
        InterestOption(id: "volunteering", name: "Volunteering", icon: "hands.sparkles.fill", description: "Community service"),
        InterestOption(id: "shopping", name: "Shopping", icon: "bag.fill", description: "Shopping and retail"),
        InterestOption(id: "travel", name: "Travel", icon: "airplane", description: "Weekend trips and travel")
    ]

    static let paceOptions = ["relaxed", "balanced", "active"]
    static let distanceOptions = ["nearby", "moderate", "willing_to_travel"]
    static let budgetOptions = ["budget", "moderate", "premium"]
}
