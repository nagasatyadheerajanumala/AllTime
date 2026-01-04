import Foundation
import Network
import os.log
import Combine

/// Represents an offline operation that needs to be synced
struct OfflineOperation: Codable, Identifiable {
    let id: UUID
    let type: OperationType
    let payload: Data  // JSON-encoded operation data
    let createdAt: Date
    var retryCount: Int
    var lastError: String?

    enum OperationType: String, Codable {
        case createEvent
        case updateEvent
        case deleteEvent
        case createReminder
        case updateReminder
        case deleteReminder
        case completeReminder
    }
}

/// Manages offline operations queue and syncs when network is available
@MainActor
class OfflineQueueManager: ObservableObject {
    static let shared = OfflineQueueManager()

    private let log = OSLog(subsystem: "com.alltime.clara", category: "OFFLINE")
    private let diagnostics = AuthDiagnostics.shared
    private let apiService = APIService()

    // Queue storage key
    private let queueStorageKey = "offline_operations_queue"
    private let maxRetries = 3

    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private var networkQueue = DispatchQueue(label: "com.alltime.clara.network")

    // Published state
    @Published var isOnline = true
    @Published var pendingOperations: [OfflineOperation] = []
    @Published var isSyncing = false
    @Published var lastSyncError: String?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadQueue()
        startNetworkMonitoring()
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOffline = !(self?.isOnline ?? true)
                self?.isOnline = path.status == .satisfied

                if wasOffline && path.status == .satisfied {
                    os_log("[OFFLINE] Network restored, processing queue", log: self?.log ?? .default, type: .info)
                    self?.diagnostics.logNetworkStateChange(isOnline: true)
                    await self?.processQueue()
                } else if path.status != .satisfied {
                    os_log("[OFFLINE] Network lost", log: self?.log ?? .default, type: .info)
                    self?.diagnostics.logNetworkStateChange(isOnline: false)
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }

    // MARK: - Queue Management

    private func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: queueStorageKey),
              let operations = try? JSONDecoder().decode([OfflineOperation].self, from: data) else {
            pendingOperations = []
            return
        }
        pendingOperations = operations
        os_log("[OFFLINE] Loaded %{public}d pending operations from storage", log: log, type: .info, pendingOperations.count)
    }

    private func saveQueue() {
        guard let data = try? JSONEncoder().encode(pendingOperations) else { return }
        UserDefaults.standard.set(data, forKey: queueStorageKey)
    }

    // MARK: - Public API

    /// Queue an event creation operation
    func queueEventCreation(_ request: CreateEventRequest) {
        guard let payload = try? JSONEncoder().encode(request) else {
            os_log("[OFFLINE] Failed to encode event creation request", log: log, type: .error)
            return
        }

        let operation = OfflineOperation(
            id: UUID(),
            type: .createEvent,
            payload: payload,
            createdAt: Date(),
            retryCount: 0,
            lastError: nil
        )

        pendingOperations.append(operation)
        saveQueue()
        diagnostics.logOfflineQueueAdd(type: "event_create", id: operation.id.uuidString)
        os_log("[OFFLINE] Queued event creation: %{public}@", log: log, type: .info, request.title)
    }

    /// Queue a reminder creation operation
    func queueReminderCreation(_ request: ReminderRequest) {
        guard let payload = try? JSONEncoder().encode(request) else {
            os_log("[OFFLINE] Failed to encode reminder creation request", log: log, type: .error)
            return
        }

        let operation = OfflineOperation(
            id: UUID(),
            type: .createReminder,
            payload: payload,
            createdAt: Date(),
            retryCount: 0,
            lastError: nil
        )

        pendingOperations.append(operation)
        saveQueue()
        diagnostics.logOfflineQueueAdd(type: "reminder_create", id: operation.id.uuidString)
        os_log("[OFFLINE] Queued reminder creation: %{public}@", log: log, type: .info, request.title ?? "Untitled")
    }

    /// Queue a reminder completion operation
    func queueReminderCompletion(reminderId: Int64) {
        let completionData = ["reminderId": reminderId]
        guard let payload = try? JSONEncoder().encode(completionData) else {
            os_log("[OFFLINE] Failed to encode reminder completion", log: log, type: .error)
            return
        }

        let operation = OfflineOperation(
            id: UUID(),
            type: .completeReminder,
            payload: payload,
            createdAt: Date(),
            retryCount: 0,
            lastError: nil
        )

        pendingOperations.append(operation)
        saveQueue()
        diagnostics.logOfflineQueueAdd(type: "reminder_complete", id: String(reminderId))
        os_log("[OFFLINE] Queued reminder completion: %{public}lld", log: log, type: .info, reminderId)
    }

    /// Check if we should queue or attempt direct API call
    func shouldQueueOperation() -> Bool {
        return !isOnline
    }

    /// Get pending operations count
    var pendingCount: Int {
        return pendingOperations.count
    }

    // MARK: - Queue Processing

    /// Process all pending operations
    func processQueue() async {
        guard isOnline else {
            os_log("[OFFLINE] Cannot process queue - offline", log: log, type: .info)
            return
        }

        guard !isSyncing else {
            os_log("[OFFLINE] Queue processing already in progress", log: log, type: .info)
            return
        }

        guard !pendingOperations.isEmpty else {
            os_log("[OFFLINE] No pending operations to process", log: log, type: .info)
            return
        }

        isSyncing = true
        lastSyncError = nil
        os_log("[OFFLINE] Processing %{public}d pending operations", log: log, type: .info, pendingOperations.count)

        var successCount = 0
        var failCount = 0

        // Process operations in order
        var remainingOperations: [OfflineOperation] = []

        for var operation in pendingOperations {
            do {
                try await processOperation(operation)
                successCount += 1
                os_log("[OFFLINE] Successfully processed operation: %{public}@", log: log, type: .info, operation.id.uuidString)
            } catch {
                operation.retryCount += 1
                operation.lastError = error.localizedDescription

                if operation.retryCount < maxRetries {
                    remainingOperations.append(operation)
                    os_log("[OFFLINE] Operation failed (attempt %{public}d/%{public}d): %{public}@",
                           log: log, type: .error, operation.retryCount, maxRetries, error.localizedDescription)
                } else {
                    failCount += 1
                    os_log("[OFFLINE] Operation permanently failed after %{public}d attempts: %{public}@",
                           log: log, type: .fault, maxRetries, error.localizedDescription)
                }
            }
        }

        pendingOperations = remainingOperations
        saveQueue()
        diagnostics.logOfflineQueueSync(synced: successCount, failed: failCount)

        isSyncing = false
        os_log("[OFFLINE] Queue processing complete: %{public}d synced, %{public}d failed, %{public}d remaining",
               log: log, type: .info, successCount, failCount, remainingOperations.count)

        // Notify that data may have changed
        if successCount > 0 {
            NotificationCenter.default.post(name: NSNotification.Name("OfflineQueueSynced"), object: nil)
        }
    }

    private func processOperation(_ operation: OfflineOperation) async throws {
        switch operation.type {
        case .createEvent:
            let request = try JSONDecoder().decode(CreateEventRequest.self, from: operation.payload)
            // Convert ISO 8601 strings to Date objects
            let formatter = ISO8601DateFormatter()
            guard let startDate = formatter.date(from: request.startTime),
                  let endDate = formatter.date(from: request.endTime) else {
                throw NSError(domain: "OfflineQueue", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid date format"])
            }
            _ = try await apiService.createEvent(
                title: request.title,
                description: request.description,
                location: request.location,
                startDate: startDate,
                endDate: endDate,
                isAllDay: request.allDay,
                provider: request.provider,
                attendees: request.attendees,
                eventColor: request.eventColor
            )

        case .createReminder:
            let request = try JSONDecoder().decode(ReminderRequest.self, from: operation.payload)
            _ = try await apiService.createReminder(request)

        case .completeReminder:
            let data = try JSONDecoder().decode([String: Int64].self, from: operation.payload)
            if let reminderId = data["reminderId"] {
                _ = try await apiService.completeReminder(id: reminderId)
            }

        case .updateEvent, .deleteEvent, .updateReminder, .deleteReminder:
            // TODO: Implement these operations as needed
            os_log("[OFFLINE] Operation type %{public}@ not yet implemented", log: log, type: .error, operation.type.rawValue)
            throw NSError(domain: "OfflineQueue", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation not implemented"])
        }
    }

    /// Clear all pending operations (use with caution)
    func clearQueue() {
        pendingOperations = []
        saveQueue()
        os_log("[OFFLINE] Queue cleared", log: log, type: .info)
    }

    /// Force retry all pending operations
    func forceRetry() async {
        // Reset retry counts
        for i in pendingOperations.indices {
            pendingOperations[i].retryCount = 0
        }
        saveQueue()
        await processQueue()
    }
}

// Note: Uses existing CreateEventRequest from Models/Event.swift
// and ReminderRequest from Models/Reminder.swift
