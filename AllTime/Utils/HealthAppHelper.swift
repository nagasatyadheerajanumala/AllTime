import Foundation
import UIKit

/// Helper for opening Health app settings
enum HealthAppHelper {
    /// Opens the Health app to the Sources section where AllTime permissions can be managed
    /// Falls back to iOS Settings if Health app URL scheme is not available
    static func openHealthAppSettings() {
        // Try to open Health app directly to Sources → AllTime
        // Health app URL scheme: x-apple-health://
        if let healthAppURL = URL(string: "x-apple-health://") {
            if UIApplication.shared.canOpenURL(healthAppURL) {
                // Try to open Health app (will open to main screen)
                UIApplication.shared.open(healthAppURL) { success in
                    if success {
                        print("✅ Opened Health app")
                    } else {
                        // Fallback to Settings
                        openSettings()
                    }
                }
                return
            }
        }
        
        // Fallback to iOS Settings
        openSettings()
    }
    
    /// Opens iOS Settings app
    static func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

