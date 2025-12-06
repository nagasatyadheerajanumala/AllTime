//
//  LocationManager.swift
//  AllTime
//
//  Created for location services
//

import Foundation
import CoreLocation
import Combine

@MainActor
class LocationManager: NSObject, ObservableObject {
    @Published var location: CLLocation?
    @Published var locationString: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let locationManager = CLLocationManager()
    private var geocoder = CLGeocoder()
    private let locationAPI = LocationAPI()
    
    static let shared = LocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func checkAuthorizationStatus() {
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        print("📍 LocationManager: ===== REQUESTING LOCATION PERMISSION =====")
        print("📍 LocationManager: Current status: \(authorizationStatusName)")
        isLoading = true
        errorMessage = nil
        
        switch authorizationStatus {
        case .notDetermined:
            print("📍 LocationManager: Requesting permission from user...")
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ LocationManager: Already authorized! Starting location updates...")
            startLocationUpdates()
        case .denied, .restricted:
            print("❌ LocationManager: Permission denied or restricted")
            errorMessage = "Location access denied. Please enable it in Settings."
            isLoading = false
        @unknown default:
            errorMessage = "Unknown location authorization status"
            isLoading = false
        }
    }
    
    func forceLocationUpdate() {
        print("📍 LocationManager: FORCING location update...")
        locationManager.requestLocation()
    }
    
    // MARK: - Location Updates
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            errorMessage = "Location permission not granted"
            isLoading = false
            return
        }
        
        print("📍 LocationManager: Starting location updates...")
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        isLoading = false
    }
    
    func getCurrentLocation() {
        requestLocationPermission()
    }
    
    // MARK: - Reverse Geocoding
    
    private func reverseGeocodeLocation(_ location: CLLocation) {
        print("📍 LocationManager: Reverse geocoding location...")
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ LocationManager: Reverse geocoding failed: \(error.localizedDescription)")
                    self.errorMessage = "Failed to get location name: \(error.localizedDescription)"
                    self.isLoading = false
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    print("❌ LocationManager: No placemark found")
                    self.errorMessage = "Could not determine location name"
                    self.isLoading = false
                    return
                }
                
                // Build location string from placemark
                var locationParts: [String] = []
                
                if let city = placemark.locality {
                    locationParts.append(city)
                }
                
                if let state = placemark.administrativeArea {
                    locationParts.append(state)
                }
                
                if let country = placemark.country {
                    locationParts.append(country)
                }
                
                let locationString = locationParts.joined(separator: ", ")
                
                if !locationString.isEmpty {
                    self.locationString = locationString
                    print("✅ LocationManager: Location found: \(locationString)")
                } else {
                    // Fallback: use coordinates
                    self.locationString = String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
                    print("📍 LocationManager: Using coordinates: \(self.locationString ?? "")")
                }
                
                // Send location to backend
                Task {
                    await self.sendLocationToBackend(location: location, placemark: placemark)
                }
                
                self.isLoading = false
                self.stopLocationUpdates()
            }
        }
    }
    
    // MARK: - Backend Integration
    
    private func sendLocationToBackend(location: CLLocation, placemark: CLPlacemark) async {
        let address = [
            placemark.subThoroughfare,
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea
        ].compactMap { $0 }.joined(separator: ", ")
        
        print("📤 LocationManager: ===== SENDING LOCATION TO BACKEND =====")
        print("📤 LocationManager: Latitude: \(location.coordinate.latitude)")
        print("📤 LocationManager: Longitude: \(location.coordinate.longitude)")
        print("📤 LocationManager: City: \(placemark.locality ?? "Unknown")")
        print("📤 LocationManager: State: \(placemark.administrativeArea ?? "Unknown")")
        print("📤 LocationManager: Country: \(placemark.country ?? "Unknown")")
        print("📤 LocationManager: Full Address: \(address)")
        
        do {
            try await locationAPI.updateLocation(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                address: address.isEmpty ? nil : address,
                city: placemark.locality,
                country: placemark.country
            )
            print("✅ LocationManager: Location sent to backend successfully")
            print("✅ LocationManager: Backend now has your ACTUAL location")
        } catch {
            print("❌ LocationManager: Failed to send location to backend: \(error.localizedDescription)")
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            self.location = location
            print("📍 LocationManager: ===== LOCATION UPDATED =====")
            print("📍 LocationManager: Latitude: \(location.coordinate.latitude)")
            print("📍 LocationManager: Longitude: \(location.coordinate.longitude)")
            print("📍 LocationManager: Accuracy: \(location.horizontalAccuracy)m")
            
            // Determine region for debugging
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude
            if lat > 40.0 && lat < 42.0 && lon > -75.0 && lon < -73.0 {
                print("✅ LocationManager: Location is in NEW JERSEY area (correct!)")
            } else if lat > 37.0 && lat < 38.0 && lon > -123.0 && lon < -121.0 {
                print("❌ LocationManager: Location is in SAN FRANCISCO area (WRONG!)")
                print("❌ LocationManager: This should NOT happen if you're in New Jersey!")
            } else {
                print("📍 LocationManager: Location is in different region")
            }
            
            reverseGeocodeLocation(location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("❌ LocationManager: Location update failed: \(error.localizedDescription)")
            errorMessage = "Failed to get location: \(error.localizedDescription)"
            isLoading = false
            stopLocationUpdates()
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            print("📍 LocationManager: ===== AUTHORIZATION CHANGED =====")
            print("📍 LocationManager: Status: \(authorizationStatus.rawValue)")
            print("📍 LocationManager: Status name: \(authorizationStatusName)")
            
            switch authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                print("✅ LocationManager: Location permission GRANTED!")
                print("📍 LocationManager: Starting location updates...")
                // Always start updates when authorized (removed isLoading check)
                startLocationUpdates()
            case .denied, .restricted:
                print("❌ LocationManager: Location permission DENIED")
                errorMessage = "Location access denied. Please enable it in Settings."
                isLoading = false
            case .notDetermined:
                print("⏳ LocationManager: Location permission not yet determined")
                break
            @unknown default:
                print("⚠️ LocationManager: Unknown authorization status")
                break
            }
        }
    }
    
    private var authorizationStatusName: String {
        switch authorizationStatus {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Authorized Always"
        case .authorizedWhenInUse: return "Authorized When In Use"
        @unknown default: return "Unknown"
        }
    }
}

