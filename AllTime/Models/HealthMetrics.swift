import Foundation

// MARK: - Daily Health Metrics (for POST /api/v1/health/daily)
struct DailyHealthMetrics: Codable, Equatable {
    let date: String
    
    // Basic Metrics
    let steps: Int?
    let activeMinutes: Int?
    let standMinutes: Int?
    let workoutsCount: Int?
    
    // Heart Health
    let restingHeartRate: Double?
    let activeHeartRate: Double?
    let maxHeartRate: Double?
    let minHeartRate: Double?
    let walkingHeartRateAvg: Double?
    let hrv: Double?
    let bloodPressureSystolic: Int?
    let bloodPressureDiastolic: Int?
    let respiratoryRate: Double?
    let bloodOxygenSaturation: Double?
    
    // Activity & Energy
    let activeEnergyBurned: Double?
    let basalEnergyBurned: Double?
    let restingEnergyBurned: Double?
    
    // Distance
    let walkingDistanceMeters: Double?
    let runningDistanceMeters: Double?
    let cyclingDistanceMeters: Double?
    let swimmingDistanceMeters: Double?
    let flightsClimbed: Int?
    
    // Sleep
    let sleepMinutes: Int?
    let sleepQualityScore: Double?
    
    // Nutrition
    let caloriesConsumed: Double?
    let proteinGrams: Double?
    let carbsGrams: Double?
    let fatGrams: Double?
    let fiberGrams: Double?
    let waterIntakeLiters: Double?
    let caffeineMg: Double?
    
    // Body Measurements
    let bodyWeight: Double?
    let bodyFatPercentage: Double?
    let leanBodyMass: Double?
    let bmi: Double?
    
    // Health Metrics
    let bloodGlucose: Double?
    
    // Fitness
    let vo2Max: Double?
    
    // Mindfulness
    let mindfulMinutes: Int?
    
    // Menstrual Cycle
    let menstrualFlow: String?
    let isMenstrualPeriod: Bool?
    
    enum CodingKeys: String, CodingKey {
        case date
        case steps
        case activeMinutes = "active_minutes"
        case standMinutes = "stand_minutes"
        case workoutsCount = "workouts_count"
        
        // Heart Health
        case restingHeartRate = "resting_heart_rate"
        case activeHeartRate = "active_heart_rate"
        case maxHeartRate = "max_heart_rate"
        case minHeartRate = "min_heart_rate"
        case walkingHeartRateAvg = "walking_heart_rate_avg"
        case hrv
        case bloodPressureSystolic = "blood_pressure_systolic"
        case bloodPressureDiastolic = "blood_pressure_diastolic"
        case respiratoryRate = "respiratory_rate"
        case bloodOxygenSaturation = "blood_oxygen_saturation"
        
        // Activity & Energy
        case activeEnergyBurned = "active_energy_burned"
        case basalEnergyBurned = "basal_energy_burned"
        case restingEnergyBurned = "resting_energy_burned"
        
        // Distance
        case walkingDistanceMeters = "walking_distance_meters"
        case runningDistanceMeters = "running_distance_meters"
        case cyclingDistanceMeters = "cycling_distance_meters"
        case swimmingDistanceMeters = "swimming_distance_meters"
        case flightsClimbed = "flights_climbed"
        
        // Sleep
        case sleepMinutes = "sleep_minutes"
        case sleepQualityScore = "sleep_quality_score"
        
        // Nutrition
        case caloriesConsumed = "calories_consumed"
        case proteinGrams = "protein_grams"
        case carbsGrams = "carbs_grams"
        case fatGrams = "fat_grams"
        case fiberGrams = "fiber_grams"
        case waterIntakeLiters = "water_intake_liters"
        case caffeineMg = "caffeine_mg"
        
        // Body Measurements
        case bodyWeight = "body_weight"
        case bodyFatPercentage = "body_fat_percentage"
        case leanBodyMass = "lean_body_mass"
        case bmi
        
        // Health Metrics
        case bloodGlucose = "blood_glucose"
        
        // Fitness
        case vo2Max = "vo2_max"
        
        // Mindfulness
        case mindfulMinutes = "mindful_minutes"
        
        // Menstrual Cycle
        case menstrualFlow = "menstrual_flow"
        case isMenstrualPeriod = "is_menstrual_period"
    }
}

// MARK: - Submit Health Metrics Response
struct SubmitHealthMetricsResponse: Codable {
    let status: String
    let recordsUpserted: Int
    
    enum CodingKeys: String, CodingKey {
        case status
        case recordsUpserted = "recordsUpserted"
    }
}

// MARK: - Health Insights Response
struct HealthInsightsResponse: Codable {
    let startDate: String
    let endDate: String
    let days: Int?
    let perDayMetrics: [PerDayMetrics]
    let summaryStats: SummaryStats
    let insights: [InsightItem]
    let aiNarrative: AINarrative
    let trendAnalysis: [TrendAnalysis]?
    let healthBreakdown: HealthBreakdown?
    
    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
        case days
        case perDayMetrics = "per_day_metrics"
        case summaryStats = "summary_stats"
        case insights
        case aiNarrative = "ai_narrative"
        case trendAnalysis = "trend_analysis"
        case healthBreakdown = "health_breakdown"
    }
}

// MARK: - Per Day Metrics
struct PerDayMetrics: Codable, Identifiable {
    let date: String
    // Basic metrics
    let steps: Int?
    let activeMinutes: Int?
    let sleepMinutes: Int?
    let workoutsCount: Int?
    let eventLoadMinutes: Int?
    let meetingsCount: Int?
    let contextBreakdown: [String: Int]
    
    // Heart Health
    let restingHeartRate: Double?
    let activeHeartRate: Double?
    let maxHeartRate: Double?
    let minHeartRate: Double?
    let walkingHeartRateAvg: Double?
    let hrv: Double?
    let bloodPressureSystolic: Int?
    let bloodPressureDiastolic: Int?
    let respiratoryRate: Double?
    let oxygenSaturation: Double?
    
    // Activity & Distance
    let walkingDistance: Double?
    let runningDistance: Double?
    let cyclingDistance: Double?
    let swimmingDistance: Double?
    let flightsClimbed: Int?
    let activeEnergyBurned: Double?
    let basalEnergyBurned: Double?
    let restingEnergyBurned: Double?
    
    // Nutrition
    let caloriesConsumed: Double?
    let protein: Double?
    let carbohydrates: Double?
    let fat: Double?
    let fiber: Double?
    let sugar: Double?
    let water: Double?
    let caffeine: Double?
    
    // Body Measurements
    let bodyWeight: Double?
    let bodyMassIndex: Double?
    let bodyFatPercentage: Double?
    let leanBodyMass: Double?
    
    // Fitness
    let vo2Max: Double?
    let mindfulnessMinutes: Int?
    
    // Menstrual Cycle
    let menstrualFlow: String?
    
    enum CodingKeys: String, CodingKey {
        case date
        case steps
        case activeMinutes = "active_minutes"
        case sleepMinutes = "sleep_minutes"
        case workoutsCount = "workouts_count"
        case eventLoadMinutes = "event_load_minutes"
        case meetingsCount = "meetings_count"
        case contextBreakdown = "context_breakdown"
        
        // Heart Health
        case restingHeartRate = "resting_heart_rate"
        case activeHeartRate = "active_heart_rate"
        case maxHeartRate = "max_heart_rate"
        case minHeartRate = "min_heart_rate"
        case walkingHeartRateAvg = "walking_heart_rate_avg"
        case hrv
        case bloodPressureSystolic = "blood_pressure_systolic"
        case bloodPressureDiastolic = "blood_pressure_diastolic"
        case respiratoryRate = "respiratory_rate"
        case oxygenSaturation = "oxygen_saturation"
        
        // Activity & Distance
        case walkingDistance = "walking_distance"
        case runningDistance = "running_distance"
        case cyclingDistance = "cycling_distance"
        case swimmingDistance = "swimming_distance"
        case flightsClimbed = "flights_climbed"
        case activeEnergyBurned = "active_energy_burned"
        case basalEnergyBurned = "basal_energy_burned"
        case restingEnergyBurned = "resting_energy_burned"
        
        // Nutrition
        case caloriesConsumed = "calories_consumed"
        case protein
        case carbohydrates
        case fat
        case fiber
        case sugar
        case water
        case caffeine
        
        // Body Measurements
        case bodyWeight = "body_weight"
        case bodyMassIndex = "body_mass_index"
        case bodyFatPercentage = "body_fat_percentage"
        case leanBodyMass = "lean_body_mass"
        
        // Fitness
        case vo2Max = "vo2_max"
        case mindfulnessMinutes = "mindfulness_minutes"
        
        // Menstrual Cycle
        case menstrualFlow = "menstrual_flow"
    }
    
    var id: String { date }
}

// MARK: - Summary Stats
struct SummaryStats: Codable {
    let avgSteps: Double?
    let avgSleepMinutes: Double?
    let avgActiveMinutes: Double?
    let totalWorkouts: Int?
    let busiestMeetingDay: String?
    let mostActiveDay: String?
    let bestSleepDay: String?
    
    enum CodingKeys: String, CodingKey {
        case avgSteps = "avg_steps"
        case avgSleepMinutes = "avg_sleep_minutes"
        case avgActiveMinutes = "avg_active_minutes"
        case totalWorkouts = "total_workouts"
        case busiestMeetingDay = "busiest_meeting_day"
        case mostActiveDay = "most_active_day"
        case bestSleepDay = "best_sleep_day"
    }
}

// MARK: - Insight Item
struct InsightItem: Codable, Identifiable {
    let type: String // "movement" | "sleep" | "stress" | "balance"
    let title: String
    let details: String
    let severity: String // "LOW" | "MEDIUM" | "HIGH"
    
    var id: String { "\(type)-\(title)" }
}

// MARK: - AI Narrative
struct AINarrative: Codable {
    let weeklyOverview: String
    let keyTakeaways: [String]
    let suggestions: [String]
    
    enum CodingKeys: String, CodingKey {
        case weeklyOverview = "weekly_overview"
        case keyTakeaways = "key_takeaways"
        case suggestions
    }
}

// MARK: - Trend Analysis
struct TrendAnalysis: Codable, Identifiable {
    let metric: String
    let currentAvg: Double
    let previousAvg: Double
    let changePercentage: Double
    let trend: String // "improving" | "declining" | "stable"
    let significance: String // "high" | "medium" | "low"
    
    enum CodingKeys: String, CodingKey {
        case metric
        case currentAvg = "current_avg"
        case previousAvg = "previous_avg"
        case changePercentage = "change_percentage"
        case trend
        case significance
    }
    
    var id: String { metric }
}

// MARK: - Health Breakdown
struct HealthBreakdown: Codable {
    let heartHealth: HeartHealth?
    let activity: ActivityBreakdown?
    let sleep: SleepBreakdown?
    let nutrition: NutritionBreakdown?
    let bodyMeasurements: BodyMeasurementsBreakdown?
    let fitness: FitnessBreakdown?
    let mindfulness: MindfulnessBreakdown?
    
    enum CodingKeys: String, CodingKey {
        case heartHealth = "heart_health"
        case activity
        case sleep
        case nutrition
        case bodyMeasurements = "body_measurements"
        case fitness
        case mindfulness
    }
}

// MARK: - Heart Health
struct HeartHealth: Codable {
    let restingHeartRateAvg: Double?
    let activeHeartRateAvg: Double?
    let maxHeartRateAvg: Double?
    let minHeartRateAvg: Double?
    let walkingHeartRateAvg: Double?
    let hrvAvg: Double?
    let bloodPressureSystolicAvg: Double?
    let bloodPressureDiastolicAvg: Double?
    let respiratoryRateAvg: Double?
    let oxygenSaturationAvg: Double?
    
    enum CodingKeys: String, CodingKey {
        case restingHeartRateAvg = "resting_heart_rate_avg"
        case activeHeartRateAvg = "active_heart_rate_avg"
        case maxHeartRateAvg = "max_heart_rate_avg"
        case minHeartRateAvg = "min_heart_rate_avg"
        case walkingHeartRateAvg = "walking_heart_rate_avg"
        case hrvAvg = "hrv_avg"
        case bloodPressureSystolicAvg = "blood_pressure_systolic_avg"
        case bloodPressureDiastolicAvg = "blood_pressure_diastolic_avg"
        case respiratoryRateAvg = "respiratory_rate_avg"
        case oxygenSaturationAvg = "oxygen_saturation_avg"
    }
}

// MARK: - Activity Breakdown
struct ActivityBreakdown: Codable {
    let stepsAvg: Double?
    let activeMinutesAvg: Double?
    let walkingDistanceAvg: Double?
    let runningDistanceAvg: Double?
    let cyclingDistanceAvg: Double?
    let swimmingDistanceAvg: Double?
    let flightsClimbedAvg: Double?
    let activeEnergyBurnedAvg: Double?
    let basalEnergyBurnedAvg: Double?
    let restingEnergyBurnedAvg: Double?
    
    enum CodingKeys: String, CodingKey {
        case stepsAvg = "steps_avg"
        case activeMinutesAvg = "active_minutes_avg"
        case walkingDistanceAvg = "walking_distance_avg"
        case runningDistanceAvg = "running_distance_avg"
        case cyclingDistanceAvg = "cycling_distance_avg"
        case swimmingDistanceAvg = "swimming_distance_avg"
        case flightsClimbedAvg = "flights_climbed_avg"
        case activeEnergyBurnedAvg = "active_energy_burned_avg"
        case basalEnergyBurnedAvg = "basal_energy_burned_avg"
        case restingEnergyBurnedAvg = "resting_energy_burned_avg"
    }
}

// MARK: - Sleep Breakdown
struct SleepBreakdown: Codable {
    let sleepMinutesAvg: Double?
    let sleepQualityScoreAvg: Double?
    
    enum CodingKeys: String, CodingKey {
        case sleepMinutesAvg = "sleep_minutes_avg"
        case sleepQualityScoreAvg = "sleep_quality_score_avg"
    }
}

// MARK: - Nutrition Breakdown
struct NutritionBreakdown: Codable {
    let caloriesConsumedAvg: Double?
    let proteinAvg: Double?
    let carbohydratesAvg: Double?
    let fatAvg: Double?
    let fiberAvg: Double?
    let sugarAvg: Double?
    let waterAvg: Double?
    let caffeineAvg: Double?
    
    enum CodingKeys: String, CodingKey {
        case caloriesConsumedAvg = "calories_consumed_avg"
        case proteinAvg = "protein_avg"
        case carbohydratesAvg = "carbohydrates_avg"
        case fatAvg = "fat_avg"
        case fiberAvg = "fiber_avg"
        case sugarAvg = "sugar_avg"
        case waterAvg = "water_avg"
        case caffeineAvg = "caffeine_avg"
    }
}

// MARK: - Body Measurements Breakdown
struct BodyMeasurementsBreakdown: Codable {
    let bodyWeightAvg: Double?
    let bodyMassIndexAvg: Double?
    let bodyFatPercentageAvg: Double?
    let leanBodyMassAvg: Double?
    
    enum CodingKeys: String, CodingKey {
        case bodyWeightAvg = "body_weight_avg"
        case bodyMassIndexAvg = "body_mass_index_avg"
        case bodyFatPercentageAvg = "body_fat_percentage_avg"
        case leanBodyMassAvg = "lean_body_mass_avg"
    }
}

// MARK: - Fitness Breakdown
struct FitnessBreakdown: Codable {
    let workoutsCountTotal: Int?
    let vo2MaxAvg: Double?
    let activeEnergyBurnedAvg: Double?
    
    enum CodingKeys: String, CodingKey {
        case workoutsCountTotal = "workouts_count_total"
        case vo2MaxAvg = "vo2_max_avg"
        case activeEnergyBurnedAvg = "active_energy_burned_avg"
    }
}

// MARK: - Mindfulness Breakdown
struct MindfulnessBreakdown: Codable {
    let mindfulnessMinutesAvg: Double?
    
    enum CodingKeys: String, CodingKey {
        case mindfulnessMinutesAvg = "mindfulness_minutes_avg"
    }
}

