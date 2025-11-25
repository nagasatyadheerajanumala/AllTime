import Foundation
import HealthKit

/// CANONICAL SOURCE OF TRUTH for all HealthKit types
/// ALL components MUST use HealthKitTypes.all - NO duplicates, NO local copies
struct HealthKitTypes {
    /// The ONLY set of HealthKit types used throughout the app
    /// These are the EXACT instances used for both requestAuthorization and authorizationStatus
    static let all: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        
        // Quantity types
        types.insert(HKObjectType.quantityType(forIdentifier: .stepCount)!)
        types.insert(HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!)
        types.insert(HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!)
        types.insert(HKObjectType.quantityType(forIdentifier: .appleStandTime)!)
        types.insert(HKObjectType.quantityType(forIdentifier: .restingHeartRate)!)
        types.insert(HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!)
        
        // Category type
        types.insert(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!)
        
        // Workout type (MUST use HKObjectType.workoutType() - no forIdentifier)
        types.insert(HKObjectType.workoutType())
        
        // Verify we have exactly 8 types
        assert(types.count == 8, "CRITICAL: Must have exactly 8 HealthKit types, got \(types.count)")
        
        return types
    }()
    
    /// Get type name for logging (workout type has no identifier)
    static func typeName(_ type: HKObjectType) -> String {
        if type is HKWorkoutType {
            return "HKWorkoutType"
        }
        return type.identifier
    }
    
    /// Get all type identifiers as strings (for logging)
    static var typeIdentifiers: [String] {
        return all.map { typeName($0) }.sorted()
    }
    
    /// Debug: Print memory addresses of all types to verify same instances
    static func debugPrintInstanceAddresses() {
        print("\n🔍 HealthKitTypes Instance Addresses (verify same instances):")
        for type in all.sorted(by: { typeName($0) < typeName($1) }) {
            let address = Unmanaged.passUnretained(type).toOpaque()
            print("   \(typeName(type)): \(address)")
        }
        print("=================================\n")
    }
}
