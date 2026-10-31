import CoreLocation
import Foundation
import Combine

@MainActor
final class LocationService: NSObject, @preconcurrency CLLocationManagerDelegate, ObservableObject {
    @Published private(set) var status = "Uses an approximate location for local weather."
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var enabled = false
    private var requesting = false
    private var lastFix: Date?
    var onLocation: ((WeatherLocation) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func configure(enabled: Bool) {
        self.enabled = enabled
        if enabled { request() }
        else { manager.stopUpdatingLocation(); geocoder.cancelGeocode(); requesting = false }
    }

    func request(force: Bool = false) {
        guard enabled, !requesting else { return }
        if !force, let lastFix, Date().timeIntervalSince(lastFix) < 21_600 { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            status = "Allow location access in the macOS prompt."
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorized:
            requesting = true
            status = "Finding your approximate location…"
            manager.requestLocation()
        case .denied, .restricted:
            status = "Location access is off. Allow it in System Settings → Privacy & Security → Location Services, or choose a city."
        @unknown default:
            status = "Location is unavailable. Choose a city instead."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard enabled else { return }
        request()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        requesting = false
        guard enabled, let fix = locations.last, fix.horizontalAccuracy >= 0,
              fix.horizontalAccuracy.isFinite, CLLocationCoordinate2DIsValid(fix.coordinate),
              abs(fix.timestamp.timeIntervalSinceNow) < 600 else { return }
        lastFix = Date()
        // Round to ~1 km before sending coordinates to the weather provider.
        let latitude = (fix.coordinate.latitude * 100).rounded() / 100
        let longitude = (fix.coordinate.longitude * 100).rounded() / 100
        let id = Int((latitude + 90) * 100) * 36_001 + Int((longitude + 180) * 100)
        status = "Automatic location is up to date."
        onLocation?(.init(id: id, name: "Current location", latitude: latitude, longitude: longitude, country: nil, admin1: nil))
        geocoder.reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude)) { [weak self] placemarks, _ in
            Task { @MainActor in
                guard let self, self.enabled, let place = placemarks?.first else { return }
                let location = WeatherLocation(id: id, name: place.locality ?? place.name ?? "Current location",
                                               latitude: latitude, longitude: longitude, country: place.country, admin1: place.administrativeArea)
                if location.isValid { self.onLocation?(location) }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        requesting = false
        status = "Couldn’t get a location. Check Location Services or choose a city."
    }
}
