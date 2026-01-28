import SwiftUI
import UIKit
import Combine
import AVFoundation
import Photos

/// ViewModel for calendar import functionality
@MainActor
class CalendarImportViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var selectedImage: UIImage?
    @Published var showingImagePicker = false
    @Published var showingSourcePicker = false
    @Published var imageSourceType: UIImagePickerController.SourceType = .photoLibrary

    @Published var isProcessing = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    @Published var extractedEvents: [ExtractedEventDTO] = []
    @Published var selectedEvents: Set<String> = []

    @Published var showingSuccessAlert = false
    @Published var savedCount = 0

    // Camera availability
    @Published var isCameraAvailable = false

    // MARK: - Private Properties

    private let apiService = APIService()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        // Check camera availability on init
        isCameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    // MARK: - Camera Permission

    /// Request camera permission and open camera if granted
    func requestCameraAccess() {
        guard isCameraAvailable else {
            errorMessage = "Camera is not available on this device"
            return
        }

        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            // Already authorized, show camera
            imageSourceType = .camera
            showingImagePicker = true

        case .notDetermined:
            // Request permission
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.imageSourceType = .camera
                        self?.showingImagePicker = true
                    } else {
                        self?.errorMessage = "Camera access denied. Enable in Settings to take photos."
                    }
                }
            }

        case .denied, .restricted:
            errorMessage = "Camera access denied. Go to Settings > AllTime to enable camera."

        @unknown default:
            errorMessage = "Unable to access camera"
        }
    }

    /// Request photo library permission and open picker if granted
    func requestPhotoLibraryAccess() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            // Already authorized, show picker
            imageSourceType = .photoLibrary
            showingImagePicker = true

        case .notDetermined:
            // Request permission
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                Task { @MainActor in
                    if newStatus == .authorized || newStatus == .limited {
                        self?.imageSourceType = .photoLibrary
                        self?.showingImagePicker = true
                    } else {
                        self?.errorMessage = "Photo library access denied. Enable in Settings to select photos."
                    }
                }
            }

        case .denied, .restricted:
            errorMessage = "Photo library access denied. Go to Settings > AllTime to enable."

        @unknown default:
            errorMessage = "Unable to access photo library"
        }
    }

    // MARK: - Process Image

    func processImage() {
        guard let image = selectedImage else {
            errorMessage = "Please select an image first"
            return
        }

        isProcessing = true
        errorMessage = nil
        extractedEvents = []
        selectedEvents = []

        Task {
            do {
                let events = try await uploadAndProcessImage(image)
                self.extractedEvents = events
                // Don't select any events by default - let user choose
                self.selectedEvents = []

                if events.isEmpty {
                    self.errorMessage = "No events could be extracted. Try a clearer screenshot."
                }
            } catch {
                self.errorMessage = "Failed to process image: \(error.localizedDescription)"
            }
            self.isProcessing = false
        }
    }

    // MARK: - Toggle Selection

    func toggleEventSelection(_ event: ExtractedEventDTO) {
        if selectedEvents.contains(event.id) {
            selectedEvents.remove(event.id)
        } else {
            selectedEvents.insert(event.id)
        }
    }

    func selectAllEvents() {
        selectedEvents = Set(extractedEvents.map { $0.id })
    }

    func deselectAllEvents() {
        selectedEvents = []
    }

    var allEventsSelected: Bool {
        !extractedEvents.isEmpty && selectedEvents.count == extractedEvents.count
    }

    // MARK: - Import Events

    func importSelectedEvents() {
        let eventsToImport = extractedEvents.filter { selectedEvents.contains($0.id) }

        guard !eventsToImport.isEmpty else {
            errorMessage = "Please select at least one event"
            return
        }

        print("📅 CalendarImport: Starting import of \(eventsToImport.count) events")
        for event in eventsToImport {
            print("📅 CalendarImport: Event - \(event.title) on \(event.date) at \(event.startTime)-\(event.endTime)")
        }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                let count = try await confirmAndSaveEvents(eventsToImport)
                self.savedCount = count

                // Clear cache to force fresh fetch when calendar view loads
                EventCacheManager.shared.clearCache()

                print("📅 CalendarImport: Import successful! Saved \(count) events")
                self.showingSuccessAlert = true
            } catch let error as ImportError {
                print("📅 CalendarImport: Import failed with ImportError: \(error.localizedDescription ?? "unknown")")
                self.errorMessage = error.localizedDescription
            } catch {
                print("📅 CalendarImport: Import failed with error: \(error)")
                self.errorMessage = "Failed to import events: \(error.localizedDescription)"
            }
            self.isSaving = false
        }
    }

    // MARK: - API Calls

    private func uploadAndProcessImage(_ image: UIImage) async throws -> [ExtractedEventDTO] {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ImportError.invalidImage
        }

        guard let userId = UserDefaults.standard.value(forKey: "userId") as? Int64 else {
            throw ImportError.notAuthenticated
        }

        guard let token = KeychainManager.shared.getAccessToken() else {
            throw ImportError.notAuthenticated
        }

        let timezone = TimeZone.current.identifier

        // Create multipart form request
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(Constants.API.baseURL)/api/v1/calendar/import/image?timezone=\(timezone)")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(String(userId), forHTTPHeaderField: "X-User-ID")

        var body = Data()

        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"calendar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImportError.networkError
        }

        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorJson["message"] as? String {
                throw ImportError.serverError(message)
            }
            throw ImportError.serverError("Server returned status \(httpResponse.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventsArray = json["events"] as? [[String: Any]] else {
            throw ImportError.invalidResponse
        }

        let parsedEvents = eventsArray.compactMap { dict -> ExtractedEventDTO? in
            guard let title = dict["title"] as? String,
                  let date = dict["date"] as? String,
                  let startTime = dict["startTime"] as? String,
                  let endTime = dict["endTime"] as? String else {
                print("📅 CalendarImport: Skipping event with missing fields: \(dict)")
                return nil
            }

            print("📅 CalendarImport: Extracted event - title: '\(title)', date: '\(date)', time: '\(startTime)'-'\(endTime)'")

            return ExtractedEventDTO(
                id: UUID().uuidString,
                title: title,
                date: date,
                startTime: startTime,
                endTime: endTime,
                timeRange: dict["timeRange"] as? String ?? "\(startTime) - \(endTime)",
                location: dict["location"] as? String,
                description: dict["description"] as? String
            )
        }

        print("📅 CalendarImport: Successfully parsed \(parsedEvents.count) events from response")
        return parsedEvents
    }

    private func confirmAndSaveEvents(_ events: [ExtractedEventDTO]) async throws -> Int {
        guard let userId = UserDefaults.standard.value(forKey: "userId") as? Int64 else {
            throw ImportError.notAuthenticated
        }

        guard let token = KeychainManager.shared.getAccessToken() else {
            throw ImportError.notAuthenticated
        }

        let timezone = TimeZone.current.identifier

        // Build events array with proper nil handling
        // IMPORTANT: Include timeRange as fallback in case startTime/endTime are not being sent correctly
        let eventsArray: [[String: Any]] = events.map { event in
            var eventDict: [String: Any] = [
                "title": event.title,
                "date": event.date,
                "startTime": event.startTime,
                "endTime": event.endTime,
                "timeRange": event.timeRange  // Fallback for time parsing
            ]
            if let location = event.location {
                eventDict["location"] = location
            }
            if let description = event.description {
                eventDict["description"] = description
            }
            print("📅 CalendarImport: Event dict being sent: \(eventDict)")
            return eventDict
        }

        let requestBody: [String: Any] = [
            "timezone": timezone,
            "events": eventsArray
        ]

        print("📅 CalendarImport: Confirming \(events.count) events")
        print("📅 CalendarImport: Request body: \(requestBody)")

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw ImportError.invalidRequest
        }

        // DEBUG: Print actual JSON being sent
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📅 CalendarImport: ACTUAL JSON being sent: \(jsonString)")
        }

        var request = URLRequest(url: URL(string: "\(Constants.API.baseURL)/api/v1/calendar/import/confirm")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(String(userId), forHTTPHeaderField: "X-User-ID")
        request.httpBody = jsonData
        request.timeoutInterval = 30 // 30 second timeout

        print("📅 CalendarImport: Sending request to \(request.url?.absoluteString ?? "")")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("📅 CalendarImport: Invalid response type")
            throw ImportError.networkError
        }

        print("📅 CalendarImport: Response status: \(httpResponse.statusCode)")

        if let responseString = String(data: data, encoding: .utf8) {
            print("📅 CalendarImport: Response body: \(responseString)")
        }

        if httpResponse.statusCode != 200 {
            // Try to extract error message from response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                throw ImportError.serverError(message)
            }
            throw ImportError.serverError("Server returned status \(httpResponse.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let savedCount = json["savedCount"] as? Int else {
            throw ImportError.invalidResponse
        }

        print("📅 CalendarImport: Successfully saved \(savedCount) events")

        // Notify that events were created - post multiple notifications to ensure calendar refreshes
        NotificationCenter.default.post(name: NSNotification.Name("EventCreated"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("CalendarSynced"), object: nil)

        // Also post after a short delay to catch any views that aren't yet listening
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: NSNotification.Name("EventCreated"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("CalendarSynced"), object: nil)
        }

        return savedCount
    }

    // MARK: - Error Type

    enum ImportError: LocalizedError {
        case invalidImage
        case notAuthenticated
        case networkError
        case serverError(String)
        case invalidResponse
        case invalidRequest

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "Could not process the selected image"
            case .notAuthenticated:
                return "Please sign in to import events"
            case .networkError:
                return "Network error. Please check your connection."
            case .serverError(let message):
                return message
            case .invalidResponse:
                return "Invalid response from server"
            case .invalidRequest:
                return "Could not create request"
            }
        }
    }
}

// MARK: - DTO

struct ExtractedEventDTO: Identifiable {
    let id: String
    let title: String
    let date: String
    let startTime: String
    let endTime: String
    let timeRange: String
    let location: String?
    let description: String?

    var formattedDate: String {
        // Parse and format the date nicely
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "EEE, MMM d"

        if let date = inputFormatter.date(from: date) {
            return outputFormatter.string(from: date)
        }
        return date
    }
}
