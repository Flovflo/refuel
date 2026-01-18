//
//  StationsViewModel.swift
//  refuel
//
//  Created by Codex on 2026-01-18.
//

import CoreLocation
import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class StationsViewModel {
    enum ViewState: Equatable {
        case idle
        case loading
        case error(String)
    }

    enum StationsViewModelError: LocalizedError {
        case data(FuelError)
        case location(Error)
        case unexpected(Error)

        var errorDescription: String? {
            switch self {
            case .data(let error):
                return error.errorDescription
            case .location(let error):
                return error.localizedDescription
            case .unexpected(let error):
                return error.localizedDescription
            }
        }
    }

    var stations: [FuelStation] = []
    var state: ViewState = .idle
    var errorMessage: String?
    var selectedFuelType: FuelType = .gazole {
        didSet {
            Task { await loadStations(forceRefresh: false) }
        }
    }

    // Dependencies
    private let dataService: FuelDataService
    private let locationManager: LocationManager
    private let advisorService: AdvisorService
    
    // User Profile
    var userProfile: UserProfile?
    var bestDealNearHome: FuelStation?
    var bestDealNearWork: FuelStation?
    var adviceMessage: String?
    
    // Cache
    private var cachedStations: [FuelStation] = []
    private let logger = Logger(subsystem: "caflex.refuel", category: "StationsViewModel")

    init(
        dataService: FuelDataService? = nil,
        locationManager: LocationManager? = nil,
        advisorService: AdvisorService? = nil
    ) {
        self.dataService = dataService ?? FuelDataService()
        self.locationManager = locationManager ?? LocationManager()
        self.advisorService = advisorService ?? AdvisorService()
        // Do NOT call sync loadUserProfile here to avoid blocking init
    }
    
    /// Main entry point to load data
    func loadStations(forceRefresh: Bool = true) async {
        state = .loading
        errorMessage = nil
        
        // 1. Load User Profile if needed
        if userProfile == nil {
            userProfile = PersistenceManager.shared.fetchUserProfile()
            if let profile = userProfile {
                // Only set if not already set by user interaction, but here we init
                if forceRefresh { selectedFuelType = profile.fuelType }
            }
        }

        do {
            // 2. Fetch Data (Network)
            if forceRefresh || cachedStations.isEmpty {
                cachedStations = try await dataService.fetchStations()
            }
            
            // 3. Resolve Location (GPS -> Home -> Work -> Fallback)
            let userLocation = await resolveUserLocation()
            
            // 4. Sort and Filter (Background Task)
            // Use local copies to capture context safely
            let rawStations = cachedStations
            let type = selectedFuelType
            let radius = 5.0 // 5km limit
            
            stations = await Task.detached {
                return StationsViewModel.filterAndSortStations(
                    stations: rawStations,
                    location: userLocation,
                    fuelType: type,
                    radius: radius
                )
            }.value
            
            // 5. Update Advice & Home/Work deals
            await updateDealsAndAdvice()
            
            state = .idle
            
        } catch {
            handleError(error)
        }
    }

    /// Search for a specific city
    func search(city: String) async {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await loadStations(forceRefresh: false)
            return
        }
        
        state = .loading
        do {
            let coordinate = try await locationManager.geocode(city: trimmed)
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            let rawStations = cachedStations
            let type = selectedFuelType
            let radius = 5.0
            
            stations = await Task.detached {
                return StationsViewModel.filterAndSortStations(
                    stations: rawStations,
                    location: location,
                    fuelType: type,
                    radius: radius
                )
            }.value
            
            state = .idle
        } catch {
            state = .error("Ville introuvable")
        }
    }

    // MARK: - Private Helpers

    private func resolveUserLocation() async -> CLLocation {
        // A. Try One-Shot GPS (Preferred if working)
        do {
            logger.info("Attempting to get GPS location...")
            return try await locationManager.getCurrentLocation()
        } catch {
            logger.warning("GPS failed or timed out: \(error.localizedDescription). Falling back.")
        }
        
        // B. Try Home
        if let home = userProfile?.homeCoordinate {
            logger.info("Using Home location")
            return CLLocation(latitude: home.latitude, longitude: home.longitude)
        }
        
        // C. Try Work
        if let work = userProfile?.workCoordinate {
            logger.info("Using Work location")
            return CLLocation(latitude: work.latitude, longitude: work.longitude)
        }
        
        // D. Fallback (Paris) - Ensures data always shows
        logger.warning("No location found. Defaulting to Paris.")
        return CLLocation(latitude: 48.8566, longitude: 2.3522)
    }

    private func updateDealsAndAdvice() async {
        guard let profile = userProfile else { return }
        
        let type = selectedFuelType
        let localStations = cachedStations
        
        // Compute best deals for Home/Work (Offloaded)
        if let home = profile.homeCoordinate {
             let loc = CLLocation(latitude: home.latitude, longitude: home.longitude)
             let sorted = await Task.detached {
                 return StationsViewModel.filterAndSortStations(
                    stations: localStations,
                    location: loc,
                    fuelType: type,
                    radius: 5.0
                 )
             }.value
             bestDealNearHome = sorted.first
        }
        
        if let work = profile.workCoordinate {
             let loc = CLLocation(latitude: work.latitude, longitude: work.longitude)
             let sorted = await Task.detached {
                 return StationsViewModel.filterAndSortStations(
                    stations: localStations,
                    location: loc,
                    fuelType: type,
                    radius: 5.0
                 )
             }.value
             bestDealNearWork = sorted.first
        }
        
        let cheapest = bestDealNearHome ?? bestDealNearWork ?? stations.first
        adviceMessage = advisorService.advice(profile: profile, cheapestStation: cheapest)
    }
    
    private func handleError(_ error: Error) {
        if let fuelError = error as? FuelError {
            let msg = StationsViewModelError.data(fuelError).localizedDescription
            self.errorMessage = msg
            self.state = .error(msg)
        } else {
            let msg = StationsViewModelError.unexpected(error).localizedDescription
            self.errorMessage = msg
            self.state = .error(msg)
        }
    }
    
    func price(for station: FuelStation, fallbackToCheapest: Bool = false) -> Double? {
        if let match = station.prices.first(where: { $0.fuelType == selectedFuelType }) {
            return match.price
        }
        return fallbackToCheapest ? station.cheapestPrice : nil
    }

    // MARK: - Static Sorting Logic (Background Safe)
    
    /// Pure function for filtering and sorting. Runs off-main-thread.
    nonisolated static func filterAndSortStations(
        stations: [FuelStation],
        location: CLLocation,
        fuelType: FuelType,
        radius: Double
    ) -> [FuelStation] {
        // 1. Rough Bounding Box Filter (Fast)
        // 1 deg lat ~ 111km. 0.2 deg ~ 20km.
        let userLat = location.coordinate.latitude
        let userLon = location.coordinate.longitude
        let boxSize = 0.25
        
        let candidates = stations.filter { s in
            // Check fuel first
            guard s.prices.contains(where: { $0.fuelType == fuelType }) else { return false }
            // Check box
            return abs(s.latitude - userLat) < boxSize && abs(s.longitude - userLon) < boxSize
        }
        
        // 2. Precise Distance Calc
        var valid = candidates.compactMap { s -> FuelStation? in
            var m = s
            let dist = LocationManager.distanceKm(
                from: location.coordinate,
                to: CLLocationCoordinate2D(latitude: s.latitude, longitude: s.longitude)
            )
            if dist <= radius {
                m.distanceKm = dist
                return m
            }
            return nil
        }
        
        // 3. Fallback if empty (Desert mode)
        if valid.isEmpty {
             // Take closest 20 globally (Slow but safe fallback)
             var all = stations.map { s -> FuelStation in
                 var m = s
                 m.distanceKm = LocationManager.distanceKm(
                    from: location.coordinate,
                    to: CLLocationCoordinate2D(latitude: s.latitude, longitude: s.longitude)
                 )
                 return m
             }
             // Filter by fuel type
             all = all.filter { s in s.prices.contains(where: { $0.fuelType == fuelType }) }
             
             // Sort by distance
             all.sort { ($0.distanceKm ?? 9999) < ($1.distanceKm ?? 9999) }
             valid = Array(all.prefix(20))
        }
        
        // 4. Sort by Price
        valid.sort { lhs, rhs in
            let p1 = lhs.prices.first(where: { $0.fuelType == fuelType })?.price ?? 999
            let p2 = rhs.prices.first(where: { $0.fuelType == fuelType })?.price ?? 999
            return p1 < p2
        }
        
        // 5. Strict Limit (30)
        return Array(valid.prefix(30))
    }
}

#if DEBUG
@MainActor
extension StationsViewModel {
    static func preview(stations: [FuelStation]? = nil) -> StationsViewModel {
        let viewModel = StationsViewModel()
        viewModel.stations = stations ?? previewStations
        viewModel.state = .idle
        viewModel.errorMessage = nil
        return viewModel
    }

    static var previewStations: [FuelStation] {
        [
            FuelStation(
                id: "preview-1",
                address: "10 Rue de la Paix",
                city: "Paris",
                postalCode: "75002",
                latitude: 48.8686,
                longitude: 2.3317,
                prices: [
                    FuelPrice(fuelType: .gazole, price: 1.689, lastUpdate: Date()),
                    FuelPrice(fuelType: .sp95, price: 1.799, lastUpdate: Date())
                ],
                services: ["Lavage", "Boutique", "Air"],
                isOpen24h: true,
                distanceKm: 2.4
            ),
            FuelStation(
                id: "preview-2",
                address: "42 Avenue des Champs",
                city: "Lyon",
                postalCode: "69000",
                latitude: 45.7640,
                longitude: 4.8357,
                prices: [
                    FuelPrice(fuelType: .gazole, price: 1.659, lastUpdate: Date()),
                    FuelPrice(fuelType: .e10, price: 1.719, lastUpdate: Date())
                ],
                services: ["Restaurant", "Toilettes"],
                isOpen24h: false,
                distanceKm: 5.8
            )
        ]
    }
}
#endif
