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
    
    // Cache for verification result to avoid repeated queries
    private var lastVerificationResult: (result: Bool, timestamp: Date)?
    private let verificationCacheTimeout: TimeInterval = 30 // Cache for 30 seconds
    
    /// Check current authorization status
    @MainActor
    func checkAuthorizationStatus() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthMetricsService: HealthKit is NOT available on this device")
            isAuthorized = false
            lastVerificationResult = nil // Clear cache if HealthKit not available
            return
        }
        
        // Verify that we can actually create HealthKit types (entitlements check)
        let testType = HKQuantityType.quantityType(forIdentifier: .stepCount)
        guard testType != nil else {
            print("❌ HealthMetricsService: Cannot create HealthKit types - entitlements may be missing!")
            print("❌ HealthMetricsService: Make sure HealthKit capability is enabled in Xcode")
            isAuthorized = false
            return
        }
        
        print("✅ HealthMetricsService: HealthKit is available and types can be created")
        
        // Check status for CORE types only (same ones we request authorization for)
        var hasAnyAuthorization = false
        var authorizedTypes: [String] = []
        var deniedTypes: [String] = []
        var notDeterminedTypes: [String] = []
        
        // CRITICAL: Use canonical HealthKitTypes.all - EXACT same instances as requestAuthorization
        let coreTypes = HealthKitTypes.all
        
        for type in coreTypes {
            let status = healthStore.authorizationStatus(for: type)
            let typeName = HealthKitTypes.typeName(type)
            
            switch status {
            case .sharingAuthorized:
                hasAnyAuthorization = true
                authorizedTypes.append(typeName)
                print("✅ HealthMetricsService: Core type '\(typeName)' status: sharingAuthorized")
            case .sharingDenied:
                deniedTypes.append(typeName)
                print("❌ HealthMetricsService: Core type '\(typeName)' status: sharingDenied")
            case .notDetermined:
                notDeterminedTypes.append(typeName)
                print("⚠️ HealthMetricsService: Core type '\(typeName)' status: notDetermined")
            @unknown default:
                print("❓ HealthMetricsService: Core type '\(typeName)' status: unknown")
                break
            }
        }
        
        print("💚 HealthMetricsService: Authorization check for \(coreTypes.count) CORE types:")
        print("   - Authorized: \(authorizedTypes.count) - \(authorizedTypes)")
        print("   - Denied: \(deniedTypes.count) - \(deniedTypes)")
        print("   - Not determined: \(notDeterminedTypes.count) - \(notDeterminedTypes)")
        print("   - hasAnyAuthorization: \(hasAnyAuthorization)")
        
        // Determine authorization based on CORE types only
        if hasAnyAuthorization {
            print("✅ HealthMetricsService: HealthKit access granted for \(authorizedTypes.count) core type(s)")
            // Verify with actual query to be sure
            let verified = await verifyAuthorizationByQuery()
            await MainActor.run {
                isAuthorized = verified
                lastVerificationResult = (result: verified, timestamp: Date())
                
                if verified {
                    print("✅ HealthMetricsService: Verified authorization - access granted")
                } else {
                    print("❌ HealthMetricsService: Verification failed - cannot read data")
                }
            }
        } else if deniedTypes.count == coreTypes.count {
            // All CORE types are denied
            print("❌ HealthMetricsService: All CORE HealthKit types denied - no access")
            await MainActor.run {
                isAuthorized = false
                lastVerificationResult = (result: false, timestamp: Date())
            }
        } else {
            // All not determined
            print("⚠️ HealthMetricsService: All core types not determined - need to request authorization")
            await MainActor.run {
                isAuthorized = false
                lastVerificationResult = (result: false, timestamp: Date())
            }
        }
    }
    
    /// Verify authorization by checking CORE types status first, then attempting to query
    /// KEY FIX: Only checks CORE types (same ones we requested authorization for)
    @MainActor
    func verifyAuthorizationByQuery() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthMetricsService: HealthKit not available on this device")
            return false
        }
        
        // Check authorization status for CORE types only
        var hasAnyAuthorized = false
        var allDenied = true
        var allNotDetermined = true
        
        // CRITICAL: Use canonical HealthKitTypes.all - EXACT same instances as requestAuthorization
        let coreTypes = HealthKitTypes.all
        
        for type in coreTypes {
            let status = healthStore.authorizationStatus(for: type)
            switch status {
            case .sharingAuthorized:
                hasAnyAuthorized = true
                allDenied = false
                allNotDetermined = false
            case .sharingDenied:
                allNotDetermined = false
                // Keep allDenied as true if we haven't found any authorized
            case .notDetermined:
                allDenied = false
                // Keep allNotDetermined as true if we haven't found any determined
            @unknown default:
                break
            }
        }
        
        // KEY FIX: Only return true if we have authorization for at least one CORE type
        // Don't rely on query success alone - verify with actual query
        if hasAnyAuthorized {
            print("✅ HealthMetricsService: Found authorized CORE types - verifying with query...")
            return await verifyWithActualQuery()
        }
        
        // If all CORE types are denied, we definitely don't have access
        if allDenied {
            print("❌ HealthMetricsService: All CORE types denied - no access. User must enable in Health app.")
            return false
        }
        
        // If all are not determined, we're not authorized yet
        if allNotDetermined {
            print("⚠️ HealthMetricsService: All CORE types not determined - not authorized yet")
            return false
        }
        
        // Mixed status (some denied, some not determined) - check with query
        print("⚠️ HealthMetricsService: Mixed authorization status for CORE types - verifying with query...")
        return await verifyWithActualQuery()
    }
    
    /// Verify authorization by attempting to read actual data
    /// Only returns true if we can successfully query data (not just "no data available")
    @MainActor
    private func verifyWithActualQuery() async -> Bool {
        // Try to query step count for today as verification
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return false
        }
        
        // First check if step count is in our core types and if it's authorized
        let stepStatus = healthStore.authorizationStatus(for: stepType)
        guard stepStatus == .sharingAuthorized else {
            print("❌ HealthMetricsService: Step count not authorized (status: \(stepStatus.rawValue))")
            return false
        }
        
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return false
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == "com.apple.healthkit" && nsError.code == 4 {
                        // Error code 4 = authorization denied
                        print("❌ HealthMetricsService: Query failed - authorization denied (code 4)")
                        continuation.resume(returning: false)
                    } else if nsError.domain == "com.apple.healthkit" && nsError.code == 11 {
                        // Error code 11 = no data available
                        // This means we HAVE access but there's no data - this is OK for authorization
                        print("✅ HealthMetricsService: Query succeeded - we have access (no data available)")
                        continuation.resume(returning: true)
                    } else {
                        // Other error - treat as failure
                        print("❌ HealthMetricsService: Query error: \(error.localizedDescription)")
                        continuation.resume(returning: false)
                    }
                } else {
                    // Query succeeded - we have access
                    let count = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                    print("✅ HealthMetricsService: Query succeeded - we have access! (steps: \(Int(count)))")
                    continuation.resume(returning: true)
                }
            }
            healthStore.execute(query)
        }
    }
    
    /// Request HealthKit authorization
    /// DEPRECATED: Authorization is requested automatically in HealthKitManager.init() on app launch
    /// This method should NOT be called - it only opens Health app settings
    @MainActor
    func requestAuthorization() async throws {
        print("⚠️ HealthMetricsService.requestAuthorization called - but authorization is requested on app start")
        print("⚠️ Opening Health app settings instead")
        
        // Just open Health app settings - authorization is already requested on app start
        HealthAppHelper.openHealthAppSettings()
        
        // Re-check status after a delay (user may have enabled permissions)
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await checkAuthorizationStatus()
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
        
        // Query all metrics in parallel
        async let steps = querySteps(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let activeEnergy = queryActiveEnergy(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let activeMinutes = queryActiveMinutes(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let standMinutes = queryStandMinutes(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let basalEnergy = queryBasalEnergy(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let restingHR = queryRestingHeartRate(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let heartRate = queryHeartRate(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let hrv = queryHRV(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let bloodPressure = queryBloodPressure(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let respiratoryRate = queryRespiratoryRate(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let oxygenSaturation = queryOxygenSaturation(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let walkingDistance = queryWalkingDistance(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let runningDistance = queryRunningDistance(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let cyclingDistance = queryCyclingDistance(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let swimmingDistance = querySwimmingDistance(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let flightsClimbed = queryFlightsClimbed(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let sleep = querySleep(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let bodyWeight = queryBodyWeight(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let bodyFat = queryBodyFat(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let leanBodyMass = queryLeanBodyMass(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let bloodGlucose = queryBloodGlucose(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let vo2Max = queryVO2Max(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let mindfulMinutes = queryMindfulMinutes(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let workouts = queryWorkouts(healthStore: healthStore, start: startOfDay, end: endOfDay)
        
        let (stepsValue, activeEnergyValue, activeMinutesValue, standMinutesValue, basalEnergyValue,
             restingHRValue, heartRateValue, hrvValue, bloodPressureValue, respiratoryRateValue, oxygenSaturationValue,
             walkingDistanceValue, runningDistanceValue, cyclingDistanceValue, swimmingDistanceValue, flightsClimbedValue,
             sleepValue, bodyWeightValue, bodyFatValue, leanBodyMassValue, bloodGlucoseValue, vo2MaxValue, mindfulMinutesValue, workoutsValue) = try await (
            steps, activeEnergy, activeMinutes, standMinutes, basalEnergy,
            restingHR, heartRate, hrv, bloodPressure, respiratoryRate, oxygenSaturation,
            walkingDistance, runningDistance, cyclingDistance, swimmingDistance, flightsClimbed,
            sleep, bodyWeight, bodyFat, leanBodyMass, bloodGlucose, vo2Max, mindfulMinutes, workouts
        )
        
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
            sleepMinutes: sleepValue.minutes,
            sleepQualityScore: sleepValue.qualityScore,
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
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
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

