//
//  LocationManager.swift
//  refuel
//
//  Created by Codex on 2026-01-18.
//

import Foundation
import CoreLocation

@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    enum LocationError: LocalizedError {
        case authorizationDenied
        case authorizationRestricted
        case invalidCity
        case noGeocodingResult

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
            }
        }
    }

    var location: CLLocation?
    var isAuthorized = false
    var errorMessage: String?
    
    private let manager = CLLocationManager()
    
    var lastKnownLocation: CLLocation? { location }
    private var continuation: CheckedContinuation<CLLocation, Error>?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }
    
    func getCurrentLocation() async throws -> CLLocation {
        // Build a continuation
        // If we have a recent location (e.g. < 1 min old), return it?
        // For simplicity, request new one.
        
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                isAuthorized = true
                manager.requestLocation() // Request one-shot location
            case .notDetermined:
                isAuthorized = false
                manager.requestWhenInUseAuthorization()
            case .denied:
                isAuthorized = false
                continuation.resume(throwing: LocationError.authorizationDenied)
                self.continuation = nil
            case .restricted:
                isAuthorized = false
                continuation.resume(throwing: LocationError.authorizationRestricted)
                self.continuation = nil
            @unknown default:
                isAuthorized = false
                continuation.resume(throwing: LocationError.authorizationDenied)
                self.continuation = nil
            }
        }
    }

    @MainActor
    func geocode(city: String) async throws -> CLLocationCoordinate2D {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LocationError.invalidCity
        }

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
    
    func StartUpdating() { // capitalized to avoid conflict if any, actually simpler: use manager directly if needed
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        self.location = newLocation
        
        // Fulfill continuation if pending
        if let output = continuation {
            output.resume(returning: newLocation)
            continuation = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
        
        if let output = continuation {
            output.resume(throwing: error)
            continuation = nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            isAuthorized = true
            if continuation != nil {
                manager.requestLocation()
            }
        case .denied:
            isAuthorized = false
            errorMessage = LocationError.authorizationDenied.localizedDescription
            if let output = continuation {
                output.resume(throwing: LocationError.authorizationDenied)
                continuation = nil
            }
        case .restricted:
            isAuthorized = false
            errorMessage = LocationError.authorizationRestricted.localizedDescription
            if let output = continuation {
                output.resume(throwing: LocationError.authorizationRestricted)
                continuation = nil
            }
        case .notDetermined:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }
}
