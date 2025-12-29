import Foundation
import UIKit
import MapKit

/// Service for launching navigation to locations via Apple Maps or Google Maps
struct MapLauncherService {

    /// Shows an action sheet allowing the user to choose between Apple Maps and Google Maps
    /// - Parameters:
    ///   - latitude: Destination latitude
    ///   - longitude: Destination longitude
    ///   - destinationName: Name of the destination (for display in maps)
    ///   - address: Optional address string (used as fallback if coordinates unavailable)
    static func showDirectionsOptions(
        latitude: Double,
        longitude: Double,
        destinationName: String,
        address: String? = nil
    ) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            // Fallback: just open Apple Maps directly
            openAppleMaps(latitude: latitude, longitude: longitude, name: destinationName)
            return
        }

        // Find the topmost presented view controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        let alert = UIAlertController(
            title: "Get Directions",
            message: "Choose your preferred maps app",
            preferredStyle: .actionSheet
        )

        // Apple Maps option
        alert.addAction(UIAlertAction(title: "Apple Maps", style: .default) { _ in
            openAppleMaps(latitude: latitude, longitude: longitude, name: destinationName)
        })

        // Google Maps option
        alert.addAction(UIAlertAction(title: "Google Maps", style: .default) { _ in
            openGoogleMaps(latitude: latitude, longitude: longitude, name: destinationName)
        })

        // Cancel
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // For iPad: configure popover
        if let popover = alert.popoverPresentationController {
            popover.sourceView = topController.view
            popover.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        topController.present(alert, animated: true)
    }

    /// Open Apple Maps with directions to the specified location
    static func openAppleMaps(latitude: Double, longitude: Double, name: String) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name

        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    /// Open Google Maps with directions to the specified location
    /// Falls back to web Google Maps if the app is not installed
    static func openGoogleMaps(latitude: Double, longitude: Double, name: String) {
        // Try Google Maps app first
        let googleMapsURL = "comgooglemaps://?daddr=\(latitude),\(longitude)&directionsmode=driving"

        if let url = URL(string: googleMapsURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // Fall back to Google Maps web
            let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let webURL = "https://www.google.com/maps/dir/?api=1&destination=\(latitude),\(longitude)&destination_place_id=\(encodedName)"

            if let url = URL(string: webURL) {
                UIApplication.shared.open(url)
            }
        }
    }

    /// Open maps using address string (fallback when coordinates unavailable)
    static func openMapsWithAddress(_ address: String, name: String? = nil) {
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Use Apple Maps with address
        let urlString = "http://maps.apple.com/?daddr=\(encodedAddress)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}
