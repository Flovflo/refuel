//
//  LocationManager.swift
//  refuel
//
//  Created by Codex on 2026-01-18.
//

import Foundation
import CoreLocation
import OSLog

@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    enum LocationError: LocalizedError {
        case authorizationDenied
        case authorizationRestricted
        case invalidCity
        case noGeocodingResult
        case requestInProgress
        case timeout

        var errorDescription: String? {
            switch self {
            case .authorizationDenied:
                return "Location access denied. Enable it in Settings."
            case .authorizationRestricted:
                return "Location access is restricted."
            case .invalidCity:
                return "Enter a valid city name."
            case .noGeocodingResult:
                return "No results found for that city."
            case .requestInProgress:
                return "Location request already in progress."
            case .timeout:
                return "Location request timed out."
            }
        }
    }

    var location: CLLocation?
    var isAuthorized = false
    var errorMessage: String?
    
    private let manager = CLLocationManager()
    
    private var continuation: CheckedContinuation<CLLocation, Error>?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters // Enough for gas stations
    }
    
    func getCurrentLocation() async throws -> CLLocation {
        // 1. Check if we already have a location (fast path)
        if let location = location {
            return location
        }
        
        // 2. Check/Request Authorization
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
            // Wait briefly for auth
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }
        
        guard manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways else {
            throw LocationError.authorizationDenied
        }
        
        // 3. Request Location with Continuation
        if continuation != nil {
            continuation?.resume(throwing: LocationError.requestInProgress)
            continuation = nil
        }
        
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            self.manager.requestLocation()
            
            // 4. Safety Timeout
            Task {
                try? await Task.sleep(nanoseconds: 5 * 1_000_000_000) // 5s timeout
                if let c = self.continuation {
                    self.continuation = nil
                    c.resume(throwing: LocationError.timeout)
                    self.manager.stopUpdatingLocation()
                }
            }
        }
    }

    @MainActor
    func geocode(city: String) async throws -> CLLocationCoordinate2D {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LocationError.invalidCity }

        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(trimmed)
        guard let coordinate = placemarks.first?.location?.coordinate else {
            throw LocationError.noGeocodingResult
        }
        return coordinate
    }
    
    // Static helper for distance
    static func distanceKm(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2) / 1000.0
    }

    // MARK: - Delegate Methods
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        self.location = newLocation
        if let c = continuation {
            continuation = nil
            c.resume(returning: newLocation)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Ignore simple errors if we keep trying, but for requestLocation we must fail
        if let c = continuation {
            continuation = nil
            c.resume(throwing: error)
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        isAuthorized = (manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways)
    }
}
