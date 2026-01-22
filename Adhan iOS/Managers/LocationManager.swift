import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let manager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var heading: CLHeading?
    @Published var initializationStatus: CLAuthorizationStatus = .notDetermined
    
    // Manual Override
    @Published var manualLocation: CLLocation?
    @Published var isUsingManualLocation: Bool = false
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers // Lower accuracy for battery
        manager.distanceFilter = 3000 // 3km significant change
    }
    
    func requestPermission() {
        manager.requestAlwaysAuthorization()
    }
    
    func startUpdating() {
        if !isUsingManualLocation {
            manager.allowsBackgroundLocationUpdates = true
            manager.pausesLocationUpdatesAutomatically = true // Allow OS to pause
            manager.showsBackgroundLocationIndicator = false
            
            // Significant Location Change is most battery efficient
            // Significant Location Change is most battery efficient
            manager.startMonitoringSignificantLocationChanges()
            // NB: Heading is NOT started by default to save battery
        }
    }
    
    func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }
    
    func startHeadingUpdates() {
        manager.startUpdatingHeading()
    }
    
    func stopHeadingUpdates() {
        manager.stopUpdatingHeading()
    }
    
    func setManualLocation(_ loc: CLLocation) {
        self.manualLocation = loc
        self.location = loc // Force update published property
        self.isUsingManualLocation = true
        manager.stopUpdatingLocation() // Stop GPS to save battery and avoid override
    }
    
    func resetToGPS() {
        self.manualLocation = nil
        self.isUsingManualLocation = false
        manager.startUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.initializationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            startUpdating()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if !isUsingManualLocation, let loc = locations.last {
            self.location = loc
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        self.heading = newHeading
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed: \(error.localizedDescription)")
    }
}
