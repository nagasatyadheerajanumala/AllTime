import Foundation
import HealthKit
import Combine

/// Service for querying and aggregating HealthKit data
class HealthMetricsService: ObservableObject {
    static let shared = HealthMetricsService()
    
    @Published var isAuthorized: Bool = false
    
    // CRITICAL FIX: Use shared HealthKitManager's healthStore to avoid multiple instances
    // Multiple HKHealthStore instances can cause authorization state mismatches
    private var healthStore: HKHealthStore {
        return HealthKitManager.shared.healthStore
    }
    
    // CRITICAL: Use CANONICAL source - HealthKitTypes.all
    // This ensures EXACT same instances as HealthKitManager
    private var readTypes: Set<HKObjectType> {
        return HealthKitTypes.all
    }
    
    // Cache for daily aggregates (date string -> metrics) - thread-safe
    private var dailyCache: [String: DailyHealthMetrics] = [:]
    private let cacheQueue = DispatchQueue(label: "com.alltime.health.cache")
    
    private init() {
        Task { @MainActor in
            await checkAuthorizationStatus()
        }
    }
    
    // MARK: - Authorization
    
    /// Ensures we've prompted the user if needed. Apple does not expose read-level
    /// permissions, so the result simply reflects whether HealthKit is available and
    /// we've already shown the permission sheet at least once.
    @MainActor
    func checkAuthorizationStatus() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthMetricsService: HealthKit is NOT available on this device")
            isAuthorized = false
            return
        }
        
        let testType = HKQuantityType.quantityType(forIdentifier: .stepCount)
        guard testType != nil else {
            print("❌ HealthMetricsService: Cannot create HealthKit types - entitlements may be missing!")
            print("❌ HealthMetricsService: Make sure HealthKit capability is enabled in Xcode")
            isAuthorized = false
            return
        }
        
        print("✅ HealthMetricsService: HealthKit is available and types can be created")
        
        let ready = await HealthKitManager.shared.ensureHealthKitReady()
        isAuthorized = ready
    }
    
    // MARK: - Query Daily Metrics
    
    /// Fetch daily health metrics for a specific date
    func fetchDailyMetrics(for date: Date) async throws -> DailyHealthMetrics {
        let dateString = Self.dateFormatter.string(from: date)
        
        // Check cache first (thread-safe)
        if let cached = getCachedMetrics(for: dateString) {
            return cached
        }
        
        // Query HealthKit off main thread
        let metrics = try await Task.detached { [healthStore] in
            try await Self.queryDailyMetrics(healthStore: healthStore, date: date)
        }.value
        
        // Cache result (thread-safe)
        cacheMetrics(metrics, for: dateString)
        
        return metrics
    }
    
    /// Fetch daily metrics for a date range
    func fetchDailyMetrics(for startDate: Date, endDate: Date) async throws -> [DailyHealthMetrics] {
        var metrics: [DailyHealthMetrics] = []
        var currentDate = startDate
        let calendar = Calendar.current
        
        while currentDate <= endDate {
            let dailyMetrics = try await fetchDailyMetrics(for: currentDate)
            metrics.append(dailyMetrics)
            
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }
        
        return metrics
    }
    
    // MARK: - Private Query Methods
    
    private static func queryDailyMetrics(healthStore: HKHealthStore, date: Date) async throws -> DailyHealthMetrics {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            throw HealthKitError.invalidDate
        }
        
        let dateString = dateFormatter.string(from: date)
        
        // Query all metrics in parallel (authorization errors are swallowed per metric)
        async let stepsTask = safeQuery("steps", defaultValue: nil as Int?) { try await querySteps(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let activeEnergyTask = safeQuery("activeEnergy", defaultValue: nil as Double?) { try await queryActiveEnergy(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let activeMinutesTask = safeQuery("activeMinutes", defaultValue: nil as Int?) { try await queryActiveMinutes(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let standMinutesTask = safeQuery("standMinutes", defaultValue: nil as Int?) { try await queryStandMinutes(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let basalEnergyTask = safeQuery("basalEnergy", defaultValue: nil as Double?) { try await queryBasalEnergy(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let restingHRTask = safeQuery("restingHeartRate", defaultValue: nil as Double?) { try await queryRestingHeartRate(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let heartRateTask = safeQuery("heartRate", defaultValue: nil as (avg: Double?, max: Double?, min: Double?, walkingAvg: Double?)?) { try await queryHeartRate(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let hrvTask = safeQuery("hrv", defaultValue: nil as Double?) { try await queryHRV(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let bloodPressureTask = safeQuery("bloodPressure", defaultValue: nil as (systolic: Int?, diastolic: Int?)?) { try await queryBloodPressure(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let respiratoryRateTask = safeQuery("respiratoryRate", defaultValue: nil as Double?) { try await queryRespiratoryRate(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let oxygenSaturationTask = safeQuery("oxygenSaturation", defaultValue: nil as Double?) { try await queryOxygenSaturation(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let walkingDistanceTask = safeQuery("walkingDistance", defaultValue: nil as Double?) { try await queryWalkingDistance(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let runningDistanceTask = safeQuery("runningDistance", defaultValue: nil as Double?) { try await queryRunningDistance(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let cyclingDistanceTask = safeQuery("cyclingDistance", defaultValue: nil as Double?) { try await queryCyclingDistance(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let swimmingDistanceTask = safeQuery("swimmingDistance", defaultValue: nil as Double?) { try await querySwimmingDistance(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let flightsClimbedTask = safeQuery("flightsClimbed", defaultValue: nil as Int?) { try await queryFlightsClimbed(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let sleepTask = safeQuery("sleep", defaultValue: nil as (minutes: Int?, qualityScore: Double?)?) { try await querySleep(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let bodyWeightTask = safeQuery("bodyWeight", defaultValue: nil as Double?) { try await queryBodyWeight(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let bodyFatTask = safeQuery("bodyFat", defaultValue: nil as Double?) { try await queryBodyFat(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let leanBodyMassTask = safeQuery("leanBodyMass", defaultValue: nil as Double?) { try await queryLeanBodyMass(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let bloodGlucoseTask = safeQuery("bloodGlucose", defaultValue: nil as Double?) { try await queryBloodGlucose(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let vo2MaxTask = safeQuery("vo2Max", defaultValue: nil as Double?) { try await queryVO2Max(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let mindfulMinutesTask = safeQuery("mindfulMinutes", defaultValue: nil as Int?) { try await queryMindfulMinutes(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        async let workoutsTask = safeQuery("workouts", defaultValue: nil as Int?) { try await queryWorkouts(healthStore: healthStore, start: startOfDay, end: endOfDay) }
        
        let stepsValue = await stepsTask
        let activeEnergyValue = await activeEnergyTask
        let activeMinutesValue = await activeMinutesTask
        let standMinutesValue = await standMinutesTask
        let basalEnergyValue = await basalEnergyTask
        let restingHRValue = await restingHRTask
        let heartRateValue = (await heartRateTask) ?? nil
        let hrvValue = await hrvTask
        let bloodPressureValue = (await bloodPressureTask) ?? nil
        let respiratoryRateValue = await respiratoryRateTask
        let oxygenSaturationValue = await oxygenSaturationTask
        let walkingDistanceValue = await walkingDistanceTask
        let runningDistanceValue = await runningDistanceTask
        let cyclingDistanceValue = await cyclingDistanceTask
        let swimmingDistanceValue = await swimmingDistanceTask
        let flightsClimbedValue = await flightsClimbedTask
        let sleepValue = (await sleepTask) ?? nil
        let bodyWeightValue = await bodyWeightTask
        let bodyFatValue = await bodyFatTask
        let leanBodyMassValue = await leanBodyMassTask
        let bloodGlucoseValue = await bloodGlucoseTask
        let vo2MaxValue = await vo2MaxTask
        let mindfulMinutesValue = await mindfulMinutesTask
        let workoutsValue = await workoutsTask
        
        // Calculate BMI if we have weight
        let bmi: Double? = {
            guard let weight = bodyWeightValue else { return nil }
            // BMI calculation requires height, which we don't have in daily metrics
            // This would need to be stored separately or calculated from user profile
            return nil
        }()
        
        return DailyHealthMetrics(
            date: dateString,
            steps: stepsValue,
            activeMinutes: activeMinutesValue,
            standMinutes: standMinutesValue,
            workoutsCount: workoutsValue,
            restingHeartRate: restingHRValue,
            activeHeartRate: heartRateValue?.avg,
            maxHeartRate: heartRateValue?.max,
            minHeartRate: heartRateValue?.min,
            walkingHeartRateAvg: heartRateValue?.walkingAvg,
            hrv: hrvValue,
            bloodPressureSystolic: bloodPressureValue?.systolic,
            bloodPressureDiastolic: bloodPressureValue?.diastolic,
            respiratoryRate: respiratoryRateValue,
            bloodOxygenSaturation: oxygenSaturationValue,
            activeEnergyBurned: activeEnergyValue,
            basalEnergyBurned: basalEnergyValue,
            restingEnergyBurned: nil, // Not directly available in HealthKit
            walkingDistanceMeters: walkingDistanceValue,
            runningDistanceMeters: runningDistanceValue,
            cyclingDistanceMeters: cyclingDistanceValue,
            swimmingDistanceMeters: swimmingDistanceValue,
            flightsClimbed: flightsClimbedValue,
            sleepMinutes: sleepValue?.minutes,
            sleepQualityScore: sleepValue?.qualityScore,
            caloriesConsumed: nil, // Nutrition data not in HealthKit by default
            proteinGrams: nil,
            carbsGrams: nil,
            fatGrams: nil,
            fiberGrams: nil,
            waterIntakeLiters: nil, // Water intake not in HealthKit by default
            caffeineMg: nil,
            bodyWeight: bodyWeightValue,
            bodyFatPercentage: bodyFatValue,
            leanBodyMass: leanBodyMassValue,
            bmi: bmi,
            bloodGlucose: bloodGlucoseValue,
            vo2Max: vo2MaxValue,
            mindfulMinutes: mindfulMinutesValue,
            menstrualFlow: nil, // Menstrual cycle tracking not implemented
            isMenstrualPeriod: nil
        )
    }
    
    // MARK: - Individual Query Methods
    
    private static func querySteps(healthStore: HKHealthStore, start: Date, end: Date) async throws -> Int? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let sum = result?.sumQuantity() {
                    let steps = Int(sum.doubleValue(for: HKUnit.count()))
                    continuation.resume(returning: steps > 0 ? steps : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private static func queryActiveEnergy(healthStore: HKHealthStore, start: Date, end: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return nil }
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let sum = result?.sumQuantity() {
                    let kcal = sum.doubleValue(for: HKUnit.kilocalorie())
                    continuation.resume(returning: kcal > 0 ? kcal : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private static func queryActiveMinutes(healthStore: HKHealthStore, start: Date, end: Date) async throws -> Int? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else { return nil }
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let sum = result?.sumQuantity() {
                    let minutes = Int(sum.doubleValue(for: HKUnit.minute()))
                    continuation.resume(returning: minutes > 0 ? minutes : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private static func queryStandMinutes(healthStore: HKHealthStore, start: Date, end: Date) async throws -> Int? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .appleStandTime) else { return nil }
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let sum = result?.sumQuantity() {
                    let minutes = Int(sum.doubleValue(for: HKUnit.minute()))
                    continuation.resume(returning: minutes > 0 ? minutes : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private static func queryRestingHeartRate(healthStore: HKHealthStore, start: Date, end: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .mostRecent) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let mostRecent = result?.mostRecentQuantity() {
                    let bpm = mostRecent.doubleValue(for: HKUnit(from: "count/min"))
                    continuation.resume(returning: bpm > 0 ? bpm : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private static func queryHRV(healthStore: HKHealthStore, start: Date, end: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let average = result?.averageQuantity() {
                    let ms = average.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    continuation.resume(returning: ms > 0 ? ms : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private static func querySleep(healthStore: HKHealthStore, start: Date, end: Date) async throws -> (minutes: Int?, qualityScore: Double?) {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return (nil, nil)
        }

        // FIXED: For sleep, we need to query for sleep that ENDED on this date
        // Sleep spans midnight (e.g., 11 PM to 7 AM), so using .strictStartDate would miss overnight sleep
        // Using .strictEndDate ensures we capture sleep that ended during this day (i.e., "last night's sleep")
        let calendar = Calendar.current
        let sleepQueryStart = calendar.date(byAdding: .hour, value: -12, to: start) ?? start // Look back 12 hours for sleep start
        let predicate = HKQuery.predicateForSamples(withStart: sleepQueryStart, end: end, options: .strictEndDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: (nil, nil))
                    return
                }
                
                // Calculate total sleep minutes
                var totalMinutes: Double = 0
                for sample in samples {
                    // Check for all sleep types
                    if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                        totalMinutes += sample.endDate.timeIntervalSince(sample.startDate) / 60.0
                    }
                }
                
                // Simple quality score based on sleep duration (7-9 hours = 100, less/more = lower)
                let hours = totalMinutes / 60.0
                let qualityScore: Double
                if hours >= 7 && hours <= 9 {
                    qualityScore = 100.0
                } else if hours >= 6 && hours < 7 {
                    qualityScore = 80.0 - (7 - hours) * 20
                } else if hours > 9 && hours <= 10 {
                    qualityScore = 100.0 - (hours - 9) * 10
                } else {
                    qualityScore = max(0, 100.0 - abs(hours - 8) * 15)
                }
                
                let minutes = totalMinutes > 0 ? Int(totalMinutes) : nil
                continuation.resume(returning: (minutes, qualityScore > 0 ? qualityScore : nil))
            }
            healthStore.execute(query)
        }
    }
    
    private static func queryWorkouts(healthStore: HKHealthStore, start: Date, end: Date) async throws -> Int? {
        let workoutType = HKObjectType.workoutType() // Using canonical type
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let workouts = samples {
                    let count = workouts.count
                    continuation.resume(returning: count > 0 ? count : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Additional Query Methods
    
    private static func safeQuery<T>(_ metricName: String, defaultValue: T, block: @escaping () async throws -> T) async -> T {
        do {
            return try await block()
        } catch let error as HKError where error.code == .errorAuthorizationNotDetermined || error.code == .errorAuthorizationDenied {
            print("⚠️ HealthMetricsService: Authorization missing for \(metricName) (\(error.errorCode))")
            return defaultValue
        } catch {
            print("❌ HealthMetricsService: Query \(metricName) failed: \(error.localizedDescription)")
            return defaultValue
        }
    }
    
    private static func queryBasalEnergy(healthStore: HKHealthStore, start: Date, end: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let sum = result?.sumQuantity() {
                    let kcal = sum.doubleValue(for: HKUnit.kilocalorie())
                    continuation.resume(returning: kcal > 0 ? kcal : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private static func queryHeartRate(healthStore: HKHealthStore, start: Date, end: Date) async throws -> (avg: Double?, max: Double?, min: Double?, walkingAvg: Double?)? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: [.discreteAverage, .discreteMax, .discreteMin]) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let avg = result?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
                    let max = result?.maximumQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
                    let min = result?.minimumQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
                    // Walking HR would need separate query with workout type filter
                    continuation.resume(returning: (avg: avg, max: max, min: min, walkingAvg: nil))
                }
            }
            healthStore.execute(query)
        }
    }
    
    private static func queryBloodPressure(healthStore: HKHealthStore, start: Date, end: Date) async throws -> (systolic: Int?, diastolic: Int?)? {
        guard let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        async let systolic = withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int?, Error>) in
            let query = HKStatisticsQuery(quantityType: systolicType, quantitySamplePredicate: predicate, options: .mostRecent) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let mostRecent = result?.mostRecentQuantity() {
                    let value = Int(mostRecent.doubleValue(for: HKUnit.millimeterOfMercury()))
                    continuation.resume(returning: value > 0 ? value : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
        
        async let diastolic = withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int?, Error>) in
            let query = HKStatisticsQuery(quantityType: diastolicType, quantitySamplePredicate: predicate, options: .mostRecent) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let mostRecent = result?.mostRecentQuantity() {
                    let value = Int(mostRecent.doubleValue(for: HKUnit.millimeterOfMercury()))
                    continuation.resume(returning: value > 0 ? value : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
        
        let (sys, dia) = try await (systolic, diastolic)
        return (systolic: sys, diastolic: dia)
    }
    
    private static func queryRespiratoryRate(healthStore: HKHealthStore, start: Date, end: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let average = result?.averageQuantity() {
                    let value = average.doubleValue(for: HKUnit(from: "count/min"))
                    continuation.resume(returning: value > 0 ? value : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private static func queryOxygenSaturation(healthStore: HKHealthStore, start: Date, end: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let average = result?.averageQuantity() {
                    let value = average.doubleValue(for: HKUnit.percent())
                    continuation.resume(returning: value > 0 ? value : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private static func queryWalkingDistance(healthStore: HKHealthStore, start: Date, end: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let sum = result?.sumQuantity() {
                    let meters = sum.doubleValue(for: HKUnit.meter())
                    continuation.resume(returning: meters > 0 ? meters : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private static func queryRunningDistance(healthStore: HKHealthStore, start: Date, end: Date) async throws -> Double? {
        // Running distance is typically part of workouts, not a separate metric
        // We'll extract it from workout samples
        let workoutType = HKObjectType.workoutType() // Using canonical type
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let workouts = samples as? [HKWorkout] {
                    var totalDistance: Double = 0
                    for workout in workouts {
                        if workout.workoutActivityType == .running,
                           let distance = workout.totalDistance {
                            totalDistance += distance.doubleValue(for: HKUnit.meter())
                        }
                    }
                    continuation.resume(returning: totalDistance > 0 ? totalDistance : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private static func queryCyclingDistance(healthStore: HKHealthStore, start: Date, end: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .distanceCycling) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let sum = result?.sumQuantity() {
                    let meters = sum.doubleValue(for: HKUnit.meter())
                    continuation.resume(returning: meters > 0 ? meters : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private static func querySwimmingDistance(healthStore: HKHealthStore, start: Date, end: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .distanceSwimming) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let sum = result?.sumQuantity() {
                    let meters = sum.doubleValue(for: HKUnit.meter())
                    continuation.resume(returning: meters > 0 ? meters : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private static func queryFlightsClimbed(healthStore: HKHealthStore, start: Date, end: Date) async throws -> Int? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let sum = result?.sumQuantity() {
                    let flights = Int(sum.doubleValue(for: HKUnit.count()))
                    continuation.resume(returning: flights > 0 ? flights : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private static func queryBodyWeight(healthStore: HKHealthStore, start: Date, end: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .mostRecent) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let mostRecent = result?.mostRecentQuantity() {
                    let kg = mostRecent.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                    continuation.resume(returning: kg > 0 ? kg : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private static func queryBodyFat(healthStore: HKHealthStore, start: Date, end: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .mostRecent) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let mostRecent = result?.mostRecentQuantity() {
                    let percent = mostRecent.doubleValue(for: HKUnit.percent())
                    continuation.resume(returning: percent > 0 ? percent : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private static func queryLeanBodyMass(healthStore: HKHealthStore, start: Date, end: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .leanBodyMass) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .mostRecent) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let mostRecent = result?.mostRecentQuantity() {
                    let kg = mostRecent.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                    continuation.resume(returning: kg > 0 ? kg : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private static func queryBloodGlucose(healthStore: HKHealthStore, start: Date, end: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let average = result?.averageQuantity() {
                    let value = average.doubleValue(for: HKUnit(from: "mg/dL"))
                    continuation.resume(returning: value > 0 ? value : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private static func queryVO2Max(healthStore: HKHealthStore, start: Date, end: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .vo2Max) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .mostRecent) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let mostRecent = result?.mostRecentQuantity() {
                    let value = mostRecent.doubleValue(for: HKUnit(from: "ml/kg*min"))
                    continuation.resume(returning: value > 0 ? value : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private static func queryMindfulMinutes(healthStore: HKHealthStore, start: Date, end: Date) async throws -> Int? {
        guard let type = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let sessions = samples {
                    var totalMinutes: Double = 0
                    for session in sessions {
                        totalMinutes += session.endDate.timeIntervalSince(session.startDate) / 60.0
                    }
                    let minutes = Int(totalMinutes)
                    continuation.resume(returning: minutes > 0 ? minutes : nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Cache Management (Thread-Safe)
    
    private func getCachedMetrics(for dateString: String) -> DailyHealthMetrics? {
        return cacheQueue.sync {
            return dailyCache[dateString]
        }
    }
    
    private func cacheMetrics(_ metrics: DailyHealthMetrics, for dateString: String) {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            self.dailyCache[dateString] = metrics
            // Keep cache size reasonable (last 30 days)
            if self.dailyCache.count > 30 {
                let sortedKeys = self.dailyCache.keys.sorted()
                let keysToRemove = sortedKeys.prefix(self.dailyCache.count - 30)
                for key in keysToRemove {
                    self.dailyCache.removeValue(forKey: key)
                }
            }
        }
    }
    
    func clearCache() {
        cacheQueue.async { [weak self] in
            self?.dailyCache.removeAll()
            print("🗑️ HealthMetricsService: Cache cleared")
        }
    }

    /// Force refresh metrics for today - clears cache and re-queries HealthKit
    func forceRefreshToday() async throws -> DailyHealthMetrics {
        print("🔄 HealthMetricsService: Force refreshing today's metrics...")
        clearCache()

        let today = Date()
        let metrics = try await fetchDailyMetrics(for: today)

        print("📊 HealthMetricsService: Today's metrics refreshed:")
        print("   - Steps: \(metrics.steps ?? 0)")
        print("   - Sleep: \(metrics.sleepMinutes ?? 0) minutes")
        print("   - Active minutes: \(metrics.activeMinutes ?? 0)")
        print("   - Resting HR: \(metrics.restingHeartRate ?? 0)")

        return metrics
    }

    /// Debug method to compare HealthKit data with what we're showing
    func debugPrintTodayMetrics() async {
        print("🔍 ===== DEBUG: HealthKit Data for Today =====")
        do {
            clearCache() // Clear cache to get fresh data
            let metrics = try await fetchDailyMetrics(for: Date())
            print("📊 Steps: \(metrics.steps ?? 0)")
            print("😴 Sleep: \(metrics.sleepMinutes ?? 0) minutes (\(Double(metrics.sleepMinutes ?? 0) / 60.0) hours)")
            print("🏃 Active minutes: \(metrics.activeMinutes ?? 0)")
            print("💓 Resting HR: \(metrics.restingHeartRate ?? 0) bpm")
            print("❤️ Avg HR: \(metrics.activeHeartRate ?? 0) bpm")
            print("🔥 Active energy: \(metrics.activeEnergyBurned ?? 0) kcal")
            print("🚶 Walking distance: \(metrics.walkingDistanceMeters ?? 0) meters")
            print("🔍 ===== END DEBUG =====")
        } catch {
            print("❌ Debug failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Date Formatter
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}

// MARK: - HealthKit Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case invalidDate
    case queryFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        case .invalidDate:
            return "Invalid date provided"
        case .queryFailed(let message):
            return "HealthKit query failed: \(message)"
        }
    }
}

