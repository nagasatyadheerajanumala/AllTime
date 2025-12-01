import Foundation
import Combine

@MainActor
class HealthGoalsViewModel: ObservableObject {
    @Published var goals: UserHealthGoals?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var saveSuccess = false
    
    // Published property to trigger UI updates when changes are detected
    @Published private var changeDetectionTrigger = UUID()
    
    // Editable goal values
    @Published var sleepHours: Double = 8.0 {
        didSet { changeDetectionTrigger = UUID() }
    }
    @Published var activeEnergyBurned: Double = 500.0 {
        didSet { changeDetectionTrigger = UUID() }
    }
    @Published var hrv: Double = 50.0 {
        didSet { changeDetectionTrigger = UUID() }
    }
    @Published var restingHeartRate: Double = 60.0 {
        didSet { changeDetectionTrigger = UUID() }
    }
    @Published var activeMinutes: Int = 30 {
        didSet { changeDetectionTrigger = UUID() }
    }
    @Published var steps: Int = 10000 {
        didSet { changeDetectionTrigger = UUID() }
    }
    
    private let apiService = APIService()
    private let cacheKey = "health_goals"
    
    init() {
        print("🎯 HealthGoalsViewModel: Initializing...")
    }
    
    // MARK: - Load Goals
    
    func loadGoals() async {
        // Don't reload if we already have goals and user might be editing
        // Only load if we don't have goals at all
        guard goals == nil else {
            print("🎯 HealthGoalsViewModel: Goals already loaded, skipping reload to preserve user input")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Try cache first
        if let cached = await loadCachedGoals() {
            print("✅ HealthGoalsViewModel: Loaded cached goals")
            goals = cached
            updateEditableValues(from: cached)
            isLoading = false
            
            // Refresh in background
            Task {
                await refreshGoals()
            }
            return
        }
        
        await refreshGoals()
    }
    
    func refreshGoals() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetched = try await apiService.getHealthGoals()
            print("✅ HealthGoalsViewModel: Fetched goals from API")
            goals = fetched
            updateEditableValues(from: fetched)
            
            // Cache the goals
            await cacheGoals(fetched)
            isLoading = false
        } catch {
            print("❌ HealthGoalsViewModel: Failed to fetch goals: \(error.localizedDescription)")
            
            // If backend fails, try to load from local cache as fallback
            if let cached = await loadCachedGoals() {
                print("✅ HealthGoalsViewModel: Using cached goals as fallback")
                goals = cached
                updateEditableValues(from: cached)
                // Don't show error if we have cached data
            } else {
                // Only show error if we have no cached data
                let errorMsg = error.localizedDescription
                if errorMsg.contains("user_health_goals") || errorMsg.contains("does not exist") {
                    errorMessage = "Health goals feature is being set up. Your goals will be saved locally for now."
                } else {
                    errorMessage = "Unable to load goals from server. Please try again later."
                }
            }
            isLoading = false
        }
    }
    
    // MARK: - Save Goals
    
    func saveGoals() async {
        isSaving = true
        errorMessage = nil
        saveSuccess = false
        
        print("💾 HealthGoalsViewModel: Saving goals...")
        print("   - Sleep Hours: \(sleepHours)")
        print("   - Steps: \(steps)")
        print("   - Active Minutes: \(activeMinutes)")
        print("   - Active Energy: \(activeEnergyBurned)")
        print("   - Resting HR: \(restingHeartRate)")
        print("   - HRV: \(hrv)")
        
        // Create goals object from current values
        let goalsToSave = UserHealthGoals(
            sleepHours: sleepHours > 0 ? sleepHours : nil,
            activeEnergyBurned: activeEnergyBurned > 0 ? activeEnergyBurned : nil,
            hrv: hrv > 0 ? hrv : nil,
            restingHeartRate: restingHeartRate > 0 ? restingHeartRate : nil,
            activeMinutes: activeMinutes > 0 ? activeMinutes : nil,
            steps: steps > 0 ? steps : nil,
            updatedAt: Date()
        )
        
        // Always save locally first (for offline support)
        await cacheGoals(goalsToSave)
        print("💾 HealthGoalsViewModel: Goals saved to local cache")
        // Don't update goals here - wait for server response to avoid hasChanges returning false
        // goals = goalsToSave  // Commented out - will set after successful save
        
        // Create request with proper nil handling (don't send 0 values)
        let request = SaveGoalsRequest(
            sleepHours: (sleepHours > 0 && sleepHours >= 4) ? sleepHours : nil, // Minimum valid sleep is 4 hours
            activeEnergyBurned: (activeEnergyBurned > 0 && activeEnergyBurned >= 100) ? activeEnergyBurned : nil, // Minimum valid energy is 100 kcal
            hrv: (hrv > 0 && hrv >= 20) ? hrv : nil, // Minimum valid HRV is 20ms
            restingHeartRate: (restingHeartRate > 0 && restingHeartRate >= 40) ? restingHeartRate : nil, // Minimum valid RHR is 40 bpm
            activeMinutes: (activeMinutes > 0 && activeMinutes >= 10) ? activeMinutes : nil, // Minimum valid active minutes is 10
            steps: (steps > 0 && steps >= 1000) ? steps : nil // Minimum valid steps is 1000
        )
        
        print("💾 HealthGoalsViewModel: Request being sent:")
        print("   - sleepHours: \(request.sleepHours?.description ?? "nil")")
        print("   - activeEnergyBurned: \(request.activeEnergyBurned?.description ?? "nil")")
        print("   - activeMinutes: \(request.activeMinutes?.description ?? "nil")")
        print("   - steps: \(request.steps?.description ?? "nil")")
        print("   - restingHeartRate: \(request.restingHeartRate?.description ?? "nil")")
        print("   - hrv: \(request.hrv?.description ?? "nil")")
        
        do {
            let response = try await apiService.saveHealthGoals(request)
            print("✅ HealthGoalsViewModel: Successfully saved goals to backend")
            print("✅ HealthGoalsViewModel: Response received:")
            print("   - sleepHours: \(response.goals.sleepHours?.description ?? "nil")")
            print("   - activeEnergyBurned: \(response.goals.activeEnergyBurned?.description ?? "nil")")
            print("   - activeMinutes: \(response.goals.activeMinutes?.description ?? "nil")")
            print("   - steps: \(response.goals.steps?.description ?? "nil")")
            print("   - restingHeartRate: \(response.goals.restingHeartRate?.description ?? "nil")")
            print("   - hrv: \(response.goals.hrv?.description ?? "nil")")
            
            // Update goals with server response (this will make hasChanges return false)
            goals = response.goals
            
            // Update cache with server response (this ensures persistence)
            await cacheGoals(response.goals)
            print("💾 HealthGoalsViewModel: Goals cached after successful save")
            
            // Force update editable values after successful save to match server response
            forceUpdateEditableValues(from: response.goals)
            print("💾 HealthGoalsViewModel: Editable values updated from server response")
            
            // Now update goals to match editable values so hasChanges will be false
            // This ensures the button state is correct after save
            
            saveSuccess = true
            isSaving = false
            
            // Notify all views to regenerate suggestions based on new goals
            print("📢 HealthGoalsViewModel: Posting HealthGoalsUpdated notification")
            NotificationCenter.default.post(name: NSNotification.Name("HealthGoalsUpdated"), object: nil)
        } catch {
            print("❌ HealthGoalsViewModel: Failed to save goals to backend: \(error)")
            
            let errorMsg = error.localizedDescription
            
            // Check if it's a database table missing error
            if errorMsg.contains("user_health_goals") || errorMsg.contains("does not exist") {
                // Backend table doesn't exist yet - but we saved locally, so show success
                print("⚠️ HealthGoalsViewModel: Backend table missing, but goals saved locally")
                // Update goals to match what we saved locally
                goals = goalsToSave
                // Force update editable values to reflect saved local goals
                forceUpdateEditableValues(from: goalsToSave)
                print("💾 HealthGoalsViewModel: Setting saveSuccess = true (local save)")
                saveSuccess = true
                isSaving = false
                
                // Still notify views to use local goals and regenerate suggestions
                print("📢 HealthGoalsViewModel: Posting HealthGoalsUpdated notification (local save)")
                NotificationCenter.default.post(name: NSNotification.Name("HealthGoalsUpdated"), object: nil)
                
                // Show info message (not error) that it's saved locally
                errorMessage = "Goals saved locally. Backend setup in progress."
            } else {
                // Other error - but goals are still saved locally
                // Update goals to match what we saved locally
                goals = goalsToSave
                // Force update editable values to reflect saved local goals
                forceUpdateEditableValues(from: goalsToSave)
                errorMessage = "Saved locally. Server sync failed: \(errorMsg)"
                print("💾 HealthGoalsViewModel: Setting saveSuccess = true (local save, server error)")
                saveSuccess = true // Still consider it a success since we saved locally
                isSaving = false
                
                // Notify views to use local goals and regenerate suggestions
                print("📢 HealthGoalsViewModel: Posting HealthGoalsUpdated notification (local save)")
                NotificationCenter.default.post(name: NSNotification.Name("HealthGoalsUpdated"), object: nil)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var hasLoadedInitialValues = false
    
    private func updateEditableValues(from goals: UserHealthGoals) {
        // Only update on initial load, not when refreshing (to preserve user input)
        guard !hasLoadedInitialValues else { return }
        
        if let sleep = goals.sleepHours {
            sleepHours = sleep
        }
        if let energy = goals.activeEnergyBurned {
            activeEnergyBurned = energy
        }
        if let hrvValue = goals.hrv {
            hrv = hrvValue
        }
        if let rhr = goals.restingHeartRate {
            restingHeartRate = rhr
        }
        if let minutes = goals.activeMinutes {
            activeMinutes = minutes
        }
        if let stepsValue = goals.steps {
            steps = stepsValue
        }
        
        hasLoadedInitialValues = true
    }
    
    /// Force update editable values (used after successful save)
    private func forceUpdateEditableValues(from goals: UserHealthGoals) {
        print("💾 HealthGoalsViewModel: forceUpdateEditableValues called")
        print("   - Before: sleepHours=\(sleepHours), activeMinutes=\(activeMinutes), steps=\(steps)")
        
        if let sleep = goals.sleepHours {
            sleepHours = sleep
        }
        if let energy = goals.activeEnergyBurned {
            activeEnergyBurned = energy
        }
        if let hrvValue = goals.hrv {
            hrv = hrvValue
        }
        if let rhr = goals.restingHeartRate {
            restingHeartRate = rhr
        }
        if let minutes = goals.activeMinutes {
            activeMinutes = minutes
        }
        if let stepsValue = goals.steps {
            steps = stepsValue
        }
        
        print("   - After: sleepHours=\(sleepHours), activeMinutes=\(activeMinutes), steps=\(steps)")
        
        // Reset flag so next load will update
        hasLoadedInitialValues = false
    }
    
    // MARK: - Cache Management
    
    private func loadCachedGoals() async -> UserHealthGoals? {
        return await CacheService.shared.loadJSON(UserHealthGoals.self, filename: cacheKey)
    }
    
    private func cacheGoals(_ goals: UserHealthGoals) async {
        await CacheService.shared.saveJSON(goals, filename: cacheKey)
    }
    
    // MARK: - Validation
    
    var hasChanges: Bool {
        // Access changeDetectionTrigger to ensure this computed property is re-evaluated when values change
        _ = changeDetectionTrigger
        
        guard let current = goals else { 
            // If no goals loaded yet, always allow save if user has entered any values
            return true
        }
        
        // Compare current editable values with saved goals
        // Use proper nil handling and floating point comparison
        let currentSleep = current.sleepHours ?? 0
        let currentEnergy = current.activeEnergyBurned ?? 0
        let currentHrv = current.hrv ?? 0
        let currentRhr = current.restingHeartRate ?? 0
        let currentMinutes = current.activeMinutes ?? 0
        let currentSteps = current.steps ?? 0
        
        // Compare with tolerance for floating point values
        let sleepChanged = abs(sleepHours - currentSleep) > 0.01
        let energyChanged = abs(activeEnergyBurned - currentEnergy) > 0.01
        let hrvChanged = abs(hrv - currentHrv) > 0.01
        let rhrChanged = abs(restingHeartRate - currentRhr) > 0.01
        let minutesChanged = activeMinutes != currentMinutes
        let stepsChanged = steps != currentSteps
        
        let changed = sleepChanged || energyChanged || hrvChanged || rhrChanged || minutesChanged || stepsChanged
        
        if changed {
            print("🎯 HealthGoalsViewModel: hasChanges = true")
            print("   Sleep: \(sleepHours) vs \(currentSleep)")
            print("   Active Minutes: \(activeMinutes) vs \(currentMinutes)")
            print("   Steps: \(steps) vs \(currentSteps)")
            print("   Active Energy: \(activeEnergyBurned) vs \(currentEnergy)")
            print("   Resting HR: \(restingHeartRate) vs \(currentRhr)")
            print("   HRV: \(hrv) vs \(currentHrv)")
        } else {
            print("🎯 HealthGoalsViewModel: hasChanges = false (no changes detected)")
        }
        
        return changed
    }
}

