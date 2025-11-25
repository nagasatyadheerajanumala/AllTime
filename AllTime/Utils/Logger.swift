import Foundation
import os.log

/// Performance-optimized logging utility
/// Only logs in DEBUG builds to avoid console I/O overhead in production
struct Logger {
    private static let subsystem = "com.storillc.AllTime"
    
    #if DEBUG
    private static let isDebug = true
    #else
    private static let isDebug = false
    #endif
    
    // MARK: - API Service Logging
    
    static func api(_ message: String, level: LogLevel = .info) {
        guard isDebug else { return }
        log(message, category: "APIService", level: level)
    }
    
    // MARK: - ViewModel Logging
    
    static func viewModel(_ message: String, category: String = "ViewModel", level: LogLevel = .info) {
        guard isDebug else { return }
        log(message, category: category, level: level)
    }
    
    // MARK: - Cache Logging
    
    static func cache(_ message: String, level: LogLevel = .info) {
        guard isDebug else { return }
        log(message, category: "Cache", level: level)
    }
    
    // MARK: - Sync Logging
    
    static func sync(_ message: String, level: LogLevel = .info) {
        guard isDebug else { return }
        log(message, category: "Sync", level: level)
    }
    
    // MARK: - Error Logging (Always enabled)
    
    static func error(_ message: String, category: String = "Error") {
        // Always log errors, even in production
        log(message, category: category, level: .error)
    }
    
    // MARK: - Private Implementation
    
    private static func log(_ message: String, category: String, level: LogLevel) {
        #if DEBUG
        let prefix: String
        switch level {
        case .info:
            prefix = "ℹ️"
        case .success:
            prefix = "✅"
        case .warning:
            prefix = "⚠️"
        case .error:
            prefix = "❌"
        case .debug:
            prefix = "🔍"
        }
        
        // Use os_log for better performance than print
        let logMessage = "\(prefix) [\(category)] \(message)"
        os_log("%{public}@", log: OSLog(subsystem: subsystem, category: category), type: level.osLogType, logMessage)
        #endif
    }
    
    // MARK: - Truncate Long Strings
    
    static func truncate(_ string: String, maxLength: Int = 200) -> String {
        guard string.count > maxLength else { return string }
        return String(string.prefix(maxLength)) + "..."
    }
}

enum LogLevel {
    case info
    case success
    case warning
    case error
    case debug
    
    var osLogType: OSLogType {
        switch self {
        case .info, .success, .debug:
            return .info
        case .warning:
            return .default
        case .error:
            return .error
        }
    }
}

