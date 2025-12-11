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
        // Always try to load from cache on initial load
        // This ensures saved goals are properly restored
        isLoading = true
        errorMessage = nil

        // Try cache first
        if let cached = await loadCachedGoals() {
            print("✅ HealthGoalsViewModel: Loaded cached goals")
            print("   - Sleep: \(cached.sleepHours?.description ?? "nil")")
            print("   - Steps: \(cached.steps?.description ?? "nil")")
            print("   - Active Minutes: \(cached.activeMinutes?.description ?? "nil")")
            print("   - Active Energy: \(cached.activeEnergyBurned?.description ?? "nil")")
            print("   - Resting HR: \(cached.restingHeartRate?.description ?? "nil")")
            print("   - HRV: \(cached.hrv?.description ?? "nil")")
            print("   - Updated At: \(cached.updatedAt?.description ?? "nil")")
            goals = cached
            updateEditableValues(from: cached)
            isLoading = false

            // Refresh in background (but don't override user's cached values)
            Task {
                await refreshGoalsInBackground()
            }
            return
        }

        print("⚠️ HealthGoalsViewModel: No cached goals found, fetching from server")
        await refreshGoals()
    }

    /// Refresh goals from API but only update if server data is newer
    private func refreshGoalsInBackground() async {
        do {
            let fetched = try await apiService.getHealthGoals()
            print("✅ HealthGoalsViewModel: Fetched goals from API in background")
            print("   Server data: sleep=\(fetched.sleepHours?.description ?? "nil"), steps=\(fetched.steps?.description ?? "nil"), activeMin=\(fetched.activeMinutes?.description ?? "nil"), updatedAt=\(fetched.updatedAt?.description ?? "nil")")

            // Only update cache if server data is newer or we don't have local cache
            let cachedGoals = await loadCachedGoals()

            if let cached = cachedGoals, let cachedUpdated = cached.updatedAt, let fetchedUpdated = fetched.updatedAt {
                // Compare timestamps - only update if server is newer
                print("✅ HealthGoalsViewModel: Comparing timestamps - cached=\(cachedUpdated), server=\(fetchedUpdated)")
                if fetchedUpdated > cachedUpdated {
                    print("✅ HealthGoalsViewModel: Server data is newer, updating cache and editable values")
                    goals = fetched
                    await cacheGoals(fetched)
                    await MainActor.run {
                        updateEditableValues(from: fetched)
                    }
                } else {
                    print("✅ HealthGoalsViewModel: Local cache is newer or same, keeping local data")
                    // Keep using cached data
                }
            } else if cachedGoals == nil {
                // No local cache, use server data
                print("✅ HealthGoalsViewModel: No local cache, using server data")
                goals = fetched
                await cacheGoals(fetched)
                await MainActor.run {
                    updateEditableValues(from: fetched)
                }
            } else {
                // Cache exists but no timestamps - preserve local cache (user's explicit saves)
                print("✅ HealthGoalsViewModel: Timestamps missing (cached=\(cachedGoals?.updatedAt?.description ?? "nil"), server=\(fetched.updatedAt?.description ?? "nil")), preserving local cache")
            }
        } catch {
            // Silently fail - we already have cached data
            print("⚠️ HealthGoalsViewModel: Background refresh failed: \(error.localizedDescription)")
        }
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

    /// Tracks if we're in the middle of user editing (to prevent background refresh from overwriting)
    private var isUserEditing = false

    private func updateEditableValues(from goals: UserHealthGoals) {
        // Always update editable values from loaded goals
        print("💾 HealthGoalsViewModel: Updating editable values from goals")

        if let sleep = goals.sleepHours {
            sleepHours = sleep
            print("   - Set sleepHours to \(sleep)")
        }
        if let energy = goals.activeEnergyBurned {
            activeEnergyBurned = energy
            print("   - Set activeEnergyBurned to \(energy)")
        }
        if let hrvValue = goals.hrv {
            hrv = hrvValue
            print("   - Set hrv to \(hrvValue)")
        }
        if let rhr = goals.restingHeartRate {
            restingHeartRate = rhr
            print("   - Set restingHeartRate to \(rhr)")
        }
        if let minutes = goals.activeMinutes {
            activeMinutes = minutes
            print("   - Set activeMinutes to \(minutes)")
        }
        if let stepsValue = goals.steps {
            steps = stepsValue
            print("   - Set steps to \(stepsValue)")
        }
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
    }
    
    // MARK: - Cache Management

    private func loadCachedGoals() async -> UserHealthGoals? {
        let cached = await CacheService.shared.loadJSON(UserHealthGoals.self, filename: cacheKey)
        if let cached = cached {
            print("💾 HealthGoalsViewModel: Cache loaded - file exists")
        } else {
            print("💾 HealthGoalsViewModel: Cache miss - no file found")
        }
        return cached
    }

    private func cacheGoals(_ goals: UserHealthGoals) async {
        print("💾 HealthGoalsViewModel: Saving to cache - sleep=\(goals.sleepHours?.description ?? "nil"), activeMin=\(goals.activeMinutes?.description ?? "nil"), steps=\(goals.steps?.description ?? "nil")")
        await CacheService.shared.saveJSON(goals, filename: cacheKey)
    }

    /// Clear the health goals cache - use this to fix corrupted cache issues
    func clearCache() async {
        print("🗑️ HealthGoalsViewModel: Clearing health goals cache")
        await CacheService.shared.delete(filename: cacheKey)
        goals = nil
        print("🗑️ HealthGoalsViewModel: Cache cleared, goals set to nil")
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

