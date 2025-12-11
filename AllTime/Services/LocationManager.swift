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
        print("📍 LocationManager: Requesting location permission...")
        isLoading = true
        errorMessage = nil
        
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            errorMessage = "Location access denied. Please enable it in Settings."
            isLoading = false
        @unknown default:
            errorMessage = "Unknown location authorization status"
            isLoading = false
        }
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
                
                self.isLoading = false
                self.stopLocationUpdates()
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            self.location = location
            print("📍 LocationManager: Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
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
            print("📍 LocationManager: Authorization status changed: \(authorizationStatus.rawValue)")
            
            switch authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                if isLoading {
                    startLocationUpdates()
                }
            case .denied, .restricted:
                errorMessage = "Location access denied. Please enable it in Settings."
                isLoading = false
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
}

