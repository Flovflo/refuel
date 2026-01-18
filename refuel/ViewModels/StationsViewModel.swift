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
                return "Unexpected error: \(error.localizedDescription)"
            }
        }
    }

    var stations: [FuelStation] = []
    var state: ViewState = .idle
    var errorMessage: String?
    var selectedFuelType: FuelType = .gazole
    var adviceMessage: String?
    var bestDealNearHome: FuelStation?
    var bestDealNearWork: FuelStation?

    private let dataService: FuelDataService
    private let locationManager: LocationManager
    private let advisorService: AdvisorService
    private let logger = Logger.refuel
    private var userProfile: UserProfile?
    private var cachedStations: [FuelStation] = []

    init(
        dataService: FuelDataService? = nil,
        locationManager: LocationManager? = nil,
        advisorService: AdvisorService? = nil
    ) {
        self.dataService = dataService ?? FuelDataService()
        self.locationManager = locationManager ?? LocationManager()
        self.advisorService = advisorService ?? AdvisorService()
        // loadUserProfile()
    }

    func loadStations() async {
        logger.info("loadStations: start")
        state = .loading
        errorMessage = nil
        var finalState: ViewState = .idle
        defer {
            state = finalState
            logger.info("loadStations: end state=\(String(describing: finalState), privacy: .public)")
        }

        // LOAD PROFILE ASYNC HERE to avoid main thread block in init
        if userProfile == nil {
            logger.info("loadStations: loading user profile async")
            userProfile = PersistenceManager.shared.fetchUserProfile()
            if let profile = userProfile {
                selectedFuelType = profile.fuelType
            }
        }

        do {
            let fetchedStations = try await dataService.fetchStations()
            cachedStations = fetchedStations
            
            guard let resolvedLocation = await resolveUserLocation() else {
                 // Should not happen with fallback, but good safety
                 stations = []
                 logger.warning("No location resolved even with fallback")
                 return
            }
            
            // Offload heavy sorting to background task
            let type = selectedFuelType
            let radius = maxRadiusKm
            stations = await Task.detached {
                return filterAndSortStations(stations: fetchedStations, location: resolvedLocation, fuelType: type, radius: radius)
            }.value
            
            await loadStationsNearHome(using: fetchedStations)
            await loadStationsNearWork(using: fetchedStations)
            updateAdviceMessage()
        } catch let error as FuelError {
            let message = StationsViewModelError.data(error).localizedDescription
            errorMessage = message
            finalState = .error(message)
            logger.error("loadStations: data error \(error.localizedDescription, privacy: .public)")
        } catch {
            let message = StationsViewModelError.unexpected(error).localizedDescription
            errorMessage = message
            finalState = .error(message)
            logger.error("loadStations: unexpected error \(error.localizedDescription, privacy: .public)")
        }
    }

    func search(city: String) async {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await loadStations() // Reset to default/location based
            return
        }

        logger.info("search: start city=\(trimmed, privacy: .public)")
        state = .loading
        errorMessage = nil
        
        do {
            let coordinate = try await locationManager.geocode(city: trimmed)
            let searchLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            // Filter using the search location (offloaded)
            let type = selectedFuelType
            let radius = maxRadiusKm
            let localCached = cachedStations
            
            stations = await Task.detached {
                 return filterAndSortStations(stations: localCached, location: searchLocation, fuelType: type, radius: radius)
            }.value
            
            state = .idle
        } catch {
            logger.error("Search failed: \(error.localizedDescription)")
            errorMessage = "Ville introuvable. Veuillez réessayer."
            state = .error("Ville introuvable")
        }
    }

    private func resolveUserLocation() async -> CLLocation? {
        logger.info("resolveUserLocation: strictly using saved coordinates with fallback")
        
        // STRICT PRIORITY: Home -> Work -> Paris Default. NO GPS.
        if let homeCoordinate = userProfile?.homeCoordinate {
            logger.info("resolveUserLocation: using home coordinates")
            return CLLocation(latitude: homeCoordinate.latitude, longitude: homeCoordinate.longitude)
        }
        
        if let workCoordinate = userProfile?.workCoordinate {
            logger.info("resolveUserLocation: using work coordinates")
            return CLLocation(latitude: workCoordinate.latitude, longitude: workCoordinate.longitude)
        }
        
        // FALLBACK: User has no home/work set yet, but we must show something.
        // Default to Paris center to ensure data appears.
        logger.warning("resolveUserLocation: No Home/Work set. Defaulting to Paris.")
        return CLLocation(latitude: 48.8566, longitude: 2.3522)
    }

    private func fetchStationsSorted(using location: CLLocation?) async throws -> [FuelStation] {
         guard let location = location else { return cachedStations }
         let type = selectedFuelType
         let radius = maxRadiusKm
         let currentStations = cachedStations
         return await Task.detached {
             return filterAndSortStations(stations: currentStations, location: location, fuelType: type, radius: radius)
         }.value
    }

    /// Maximum search radius in kilometers
    private let maxRadiusKm: Double = 5.0

    func price(for station: FuelStation, fallbackToCheapest: Bool = false) -> Double? {
        if let match = station.prices.first(where: { $0.fuelType == selectedFuelType }) {
            return match.price
        }
        return fallbackToCheapest ? station.cheapestPrice : nil
    }

    func loadStationsNearHome() async {
        await loadStationsNearHome(using: cachedStations)
        updateAdviceMessage()
    }

    func loadStationsNearWork() async {
        await loadStationsNearWork(using: cachedStations)
        updateAdviceMessage()
    }

    private func loadStationsNearHome(using stations: [FuelStation]) async {
        guard let coordinate = userProfile?.homeCoordinate else {
            bestDealNearHome = nil
            return
        }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let type = selectedFuelType
        let radius = maxRadiusKm
        
        let sorted = await Task.detached {
            return filterAndSortStations(stations: stations, location: location, fuelType: type, radius: radius)
        }.value
        bestDealNearHome = sorted.first
    }

    private func loadStationsNearWork(using stations: [FuelStation]) async {
        guard let coordinate = userProfile?.workCoordinate else {
            bestDealNearWork = nil
            return
        }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let type = selectedFuelType
        let radius = maxRadiusKm
        
        let sorted = await Task.detached {
            return filterAndSortStations(stations: stations, location: location, fuelType: type, radius: radius)
        }.value
        bestDealNearWork = sorted.first
    }

    private func loadUserProfile() {
        // Keep empty/unused as we load async in loadStations
    }

    private func updateAdviceMessage() {
        guard let profile = userProfile else {
            adviceMessage = nil
            return
        }
        let cheapestStation = bestDealNearHome ?? bestDealNearWork ?? stations.first
        adviceMessage = advisorService.advice(profile: profile, cheapestStation: cheapestStation)
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

// Helper outside actor
private func filterAndSortStations(
    stations: [FuelStation],
    location: CLLocation,
    fuelType: FuelType,
    radius: Double
) -> [FuelStation] {
    let userLat = location.coordinate.latitude
    let userLon = location.coordinate.longitude
    
    // OPTIMIZATION: Bounding Box Filter
    // 1 degree lat ~= 111km. 0.1 degree ~= 11km.
    // Filter out stations clearly outside a generous 10-15km box BEFORE heavy distance calc.
    let latDelta = 0.15 
    let lonDelta = 0.15
    
    // First pass: Rapid reject based on simple float math & Fuel Type
    // This reduces the set from ~10,000 to ~200-500
    let candidates = stations.filter { station in
         // 1. Check Fuel Type (fastest check)
         guard station.prices.contains(where: { $0.fuelType == fuelType }) else { return false }
         
         // 2. Bounding Box (fast float math)
         let dLat = abs(station.latitude - userLat)
         let dLon = abs(station.longitude - userLon)
         return dLat < latDelta && dLon < lonDelta
    }

    // Second pass: Precise distance calculation on the reduced set
    var validStations = candidates.compactMap { station -> FuelStation? in
        var mutable = station
        let stationLocation = CLLocation(latitude: mutable.latitude, longitude: mutable.longitude)
        // Heavy calculation happens only here
        let dist = location.distance(from: stationLocation) / 1000.0 // Convert m to km
        
        if dist <= radius {
            mutable.distanceKm = dist
            return mutable
        }
        return nil
    }

    // Note: If no stations found within 5km, we might want to fallback.
    // But since we pre-filtered, looking for "closest 20 in France" requires scanning the whole 10k list again.
    // If empty, let's fast fallback to the original list's closest stations (expensive, but rare).
    if validStations.isEmpty {
         // Fallback: Scan everything but just for distance
         // This is the "slow path" but only happens if the user is in a desert
         var all = stations.map { s -> FuelStation in
             var m = s
             let sLoc = CLLocation(latitude: s.latitude, longitude: s.longitude)
             m.distanceKm = location.distance(from: sLoc) / 1000.0
             return m
         }
         all.sort { ($0.distanceKm ?? 9999) < ($1.distanceKm ?? 9999) }
         validStations = Array(all.prefix(20))
    }

    // Sort by cheapest price
    validStations.sort { lhs, rhs in
        let leftPrice = lhs.prices.first(where: { $0.fuelType == fuelType })?.price ?? 999
        let rightPrice = rhs.prices.first(where: { $0.fuelType == fuelType })?.price ?? 999
        return leftPrice < rightPrice
    }

    return Array(validStations.prefix(30))
}
