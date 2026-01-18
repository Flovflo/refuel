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
    let userCoordinate = location.coordinate

    // Calculate distance for all stations
    var allWithDistance = stations.map { station -> FuelStation in
        var mutable = station
        let stationCoordinate = CLLocationCoordinate2D(
            latitude: station.latitude,
            longitude: station.longitude
        )
        mutable.distanceKm = LocationManager.distanceKm(from: userCoordinate, to: stationCoordinate)
        return mutable
    }

    // Filter to only stations that have the selected fuel type
    allWithDistance = allWithDistance.filter { station in
        station.prices.contains { $0.fuelType == fuelType }
    }

    // Filter by radius
    var nearbyStations = allWithDistance.filter { ($0.distanceKm ?? .greatestFiniteMagnitude) <= radius }

    // FALLBACK: If no stations within radius, take the closest 20 regardless of distance
    if nearbyStations.isEmpty {
        // Sort full list by distance
        allWithDistance.sort { ($0.distanceKm ?? .greatestFiniteMagnitude) < ($1.distanceKm ?? .greatestFiniteMagnitude) }
        nearbyStations = Array(allWithDistance.prefix(20))
    }

    // Sort by cheapest price for the selected fuel type
    nearbyStations.sort { lhs, rhs in
        let leftPrice = lhs.prices.first(where: { $0.fuelType == fuelType })?.price ?? .greatestFiniteMagnitude
        let rightPrice = rhs.prices.first(where: { $0.fuelType == fuelType })?.price ?? .greatestFiniteMagnitude
        return leftPrice < rightPrice
    }

    return nearbyStations
}
