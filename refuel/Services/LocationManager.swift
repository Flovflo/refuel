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
            }
        }
    }

    var location: CLLocation?
    var isAuthorized = false
    var errorMessage: String?
    
    private let manager = CLLocationManager()
    private let logger = Logger.location
    
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
        logger.info("getCurrentLocation: start")
        
        // Cancel any stale request
        if continuation != nil {
            logger.warning("Clearing stale location continuation")
            finishContinuation(with: .failure(LocationError.requestInProgress))
        }
        
        // Create a timeout task
        let timeoutTask = Task {
            try await Task.sleep(for: .seconds(5))
            return true
        }
        
        // Start location request on MainActor
        let locationTask = Task { @MainActor in
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocation, Error>) in
                self.continuation = continuation
                self.logger.info("Requesting location...")
                
                switch self.manager.authorizationStatus {
                case .authorizedAlways, .authorizedWhenInUse:
                    self.isAuthorized = true
                    self.manager.requestLocation()
                case .notDetermined:
                    self.isAuthorized = false
                    // Request authorization - continuation will be resumed in delegate
                    self.manager.requestWhenInUseAuthorization()
                case .denied:
                    self.isAuthorized = false
                    self.finishContinuation(with: .failure(LocationError.authorizationDenied))
                case .restricted:
                    self.isAuthorized = false
                    self.finishContinuation(with: .failure(LocationError.authorizationRestricted))
                @unknown default:
                    self.isAuthorized = false
                    self.finishContinuation(with: .failure(LocationError.authorizationDenied))
                }
            }
        }
        
        // Race: location vs timeout
        do {
            // Try to get location first
            for try await _ in AsyncStream<Bool> { continuation in
                Task {
                    do {
                        let result = try await locationTask.value
                        timeoutTask.cancel()
                        continuation.yield(true)
                        continuation.finish()
                    } catch {
                        continuation.finish()
                    }
                }
                Task {
                    if (try? await timeoutTask.value) == true {
                        locationTask.cancel()
                        self.finishContinuation(with: .failure(LocationError.authorizationDenied))
                        continuation.yield(false)
                        continuation.finish()
                    }
                }
            } {
                break
            }
            
            return try await locationTask.value
        } catch {
            timeoutTask.cancel()
            logger.error("getCurrentLocation failed: \(error.localizedDescription, privacy: .public)")
            throw error
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
        logger.info("Location received: \(newLocation, privacy: .public)")
        finishContinuation(with: .success(newLocation))
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
        logger.error("Location error: \(error.localizedDescription, privacy: .public)")
        finishContinuation(with: .failure(error))
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
            logger.error("Location authorization denied")
            finishContinuation(with: .failure(LocationError.authorizationDenied))
        case .restricted:
            isAuthorized = false
            errorMessage = LocationError.authorizationRestricted.localizedDescription
            logger.error("Location authorization restricted")
            finishContinuation(with: .failure(LocationError.authorizationRestricted))
        case .notDetermined:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }

    private func finishContinuation(with result: Result<CLLocation, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        switch result {
        case .success(let location):
            continuation.resume(returning: location)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
