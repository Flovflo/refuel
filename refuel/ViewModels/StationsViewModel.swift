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
    var selectedFuelType: FuelType = .gazole {
        didSet {
            priceAnalysisCache.removeAll()
        }
    }
    var adviceMessage: String?
    var bestDealNearHome: FuelStation?
    var bestDealNearWork: FuelStation?

    private let dataService: FuelDataService
    private let locationManager: LocationManager
    private let advisorService: AdvisorService
    private let logger = Logger.refuel
    private var userProfile: UserProfile?
    private var cachedStationsById: [String: FuelStation] = [:]
    private var cachedRegions: [RegionCache] = []
    private var debounceTask: Task<Void, Never>?
    private var priceAnalysisCache: [PriceAnalysisKey: PriceAnalysis] = [:]
    private var priceAnalysisInFlight: Set<PriceAnalysisKey> = []

    init(
        dataService: FuelDataService? = nil,
        locationManager: LocationManager? = nil,
        advisorService: AdvisorService? = nil
    ) {
        self.dataService = dataService ?? FuelDataService()
        self.locationManager = locationManager ?? LocationManager()
        self.advisorService = advisorService ?? AdvisorService()
        loadUserProfile()
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

        do {
            let resolvedLocation = await resolveUserLocation()
            guard let resolvedLocation else {
                throw FuelError.missingLocation
            }
            let fetchedStations = try await dataService.fetchStations(
                latitude: resolvedLocation.coordinate.latitude,
                longitude: resolvedLocation.coordinate.longitude,
                radius: maxRadiusKm
            )
            setCachedStations(fetchedStations)
            cachedRegions = [
                RegionCache(center: resolvedLocation.coordinate, radiusKm: maxRadiusKm)
            ]
            let fuelType = selectedFuelType
            let radius = maxRadiusKm
            let sortedStations = await Task.detached(priority: .userInitiated) {
                StationsViewModel.processStations(
                    fetchedStations,
                    with: resolvedLocation,
                    fuelType: fuelType,
                    maxRadiusKm: radius
                )
            }.value
            stations = sortedStations
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
            logger.info("search: empty city, delegating to loadStations")
            await loadStations()
            return
        }

        logger.info("search: start city=\(trimmed, privacy: .public)")
        state = .loading
        errorMessage = nil
        var finalState: ViewState = .idle
        defer {
            state = finalState
            logger.info("search: end state=\(String(describing: finalState), privacy: .public)")
        }

        do {
            let coordinate = try await locationManager.geocode(city: trimmed)
            let searchLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let fetchedStations = try await dataService.fetchStations(
                latitude: searchLocation.coordinate.latitude,
                longitude: searchLocation.coordinate.longitude,
                radius: maxRadiusKm
            )
            setCachedStations(fetchedStations)
            cachedRegions = [
                RegionCache(center: searchLocation.coordinate, radiusKm: maxRadiusKm)
            ]
            let fuelType = selectedFuelType
            let radius = maxRadiusKm
            let sortedStations = await Task.detached(priority: .userInitiated) {
                StationsViewModel.processStations(
                    fetchedStations,
                    with: searchLocation,
                    fuelType: fuelType,
                    maxRadiusKm: radius
                )
            }.value
            stations = sortedStations
            await loadStationsNearHome(using: fetchedStations)
            await loadStationsNearWork(using: fetchedStations)
            updateAdviceMessage()
        } catch let error as FuelError {
            let message = StationsViewModelError.data(error).localizedDescription
            errorMessage = message
            finalState = .error(message)
            logger.error("search: data error \(error.localizedDescription, privacy: .public)")
        } catch {
            let message = StationsViewModelError.location(error).localizedDescription
            errorMessage = message
            finalState = .error(message)
            logger.error("search: location error \(error.localizedDescription, privacy: .public)")
        }
    }

    private func resolveUserLocation() async -> CLLocation? {
        logger.info("resolveUserLocation: start")
        
        // PRIORITY 1: Use saved home coordinates (instant, no network/GPS needed)
        if let homeCoordinate = userProfile?.homeCoordinate {
            logger.info("resolveUserLocation: using home coordinates (lat: \(homeCoordinate.latitude), lon: \(homeCoordinate.longitude))")
            return CLLocation(latitude: homeCoordinate.latitude, longitude: homeCoordinate.longitude)
        }
        
        // PRIORITY 2: Use cached GPS location if available
        if let cached = locationManager.lastKnownLocation {
            logger.info("resolveUserLocation: using cached GPS location")
            return cached
        }
        
        // PRIORITY 3: Try to get fresh GPS (with 2s timeout built into LocationManager)
        logger.info("resolveUserLocation: attempting fresh GPS")
        do {
            let loc = try await locationManager.getCurrentLocation()
            logger.info("resolveUserLocation: GPS success")
            return loc
        } catch {
            logger.warning("resolveUserLocation: GPS failed: \(error.localizedDescription, privacy: .public)")
            // No location available at all
            return nil
        }
    }

    private func fetchStationsSorted(using location: CLLocation?) async throws -> [FuelStation] {
        guard let location else {
            throw FuelError.missingLocation
        }
        let fetchedStations = try await dataService.fetchStations(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            radius: maxRadiusKm
        )
        let fuelType = selectedFuelType
        let radius = maxRadiusKm
        let sorted = await Task.detached(priority: .userInitiated) {
            StationsViewModel.processStations(
                fetchedStations,
                with: location,
                fuelType: fuelType,
                maxRadiusKm: radius
            )
        }.value
        logger.info("fetchStationsSorted: result count \(sorted.count, privacy: .public)")
        return sorted
    }

    /// Maximum search radius in kilometers
    private let maxRadiusKm: Double = 15.0

    nonisolated static func processStations(
        _ stations: [FuelStation],
        with location: CLLocation?,
        fuelType: FuelType,
        maxRadiusKm: Double
    ) -> [FuelStation] {
        guard let location else {
            // No location: return sorted by city name, limited to 50
            return Array(stations.sorted { lhs, rhs in
                let leftCity = lhs.city ?? ""
                let rightCity = rhs.city ?? ""
                return leftCity.localizedCaseInsensitiveCompare(rightCity) == .orderedAscending
            }.prefix(50))
        }

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
        var nearbyStations = allWithDistance.filter { ($0.distanceKm ?? .greatestFiniteMagnitude) <= maxRadiusKm }

        // FALLBACK: If no stations within radius, take the closest 20 regardless of distance
        if nearbyStations.isEmpty {
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

    func loadStationsForRegion(lat: Double, lon: Double, radius: Double) {
        debounceTask?.cancel()
        let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let radiusKm = max(1.0, radius)
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            await self?.fetchStationsForRegion(center: center, radiusKm: radiusKm)
        }
    }

    func loadPriceAnalysis(for station: FuelStation) async {
        let key = PriceAnalysisKey(stationId: station.id, fuelType: selectedFuelType)
        if priceAnalysisCache[key] != nil || priceAnalysisInFlight.contains(key) {
            return
        }
        priceAnalysisInFlight.insert(key)
        defer { priceAnalysisInFlight.remove(key) }
        do {
            if let analysis = try await dataService.fetchPriceAnalysis(
                stationId: station.id,
                fuelType: selectedFuelType
            ) {
                priceAnalysisCache[key] = analysis
            }
        } catch {
            logger.warning("loadPriceAnalysis: \(error.localizedDescription, privacy: .public)")
        }
    }

    func priceLevel(for station: FuelStation) -> PriceLevel? {
        let key = PriceAnalysisKey(stationId: station.id, fuelType: selectedFuelType)
        return priceAnalysisCache[key]?.priceLevel
    }

    private func loadStationsNearHome(using stations: [FuelStation]) async {
        guard let coordinate = userProfile?.homeCoordinate else {
            bestDealNearHome = nil
            return
        }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let fuelType = selectedFuelType
        let radius = maxRadiusKm
        let sortedStations = await Task.detached(priority: .userInitiated) {
            StationsViewModel.processStations(
                stations,
                with: location,
                fuelType: fuelType,
                maxRadiusKm: radius
            )
        }.value
        bestDealNearHome = sortedStations.first
    }

    private func loadStationsNearWork(using stations: [FuelStation]) async {
        guard let coordinate = userProfile?.workCoordinate else {
            bestDealNearWork = nil
            return
        }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let fuelType = selectedFuelType
        let radius = maxRadiusKm
        let sortedStations = await Task.detached(priority: .userInitiated) {
            StationsViewModel.processStations(
                stations,
                with: location,
                fuelType: fuelType,
                maxRadiusKm: radius
            )
        }.value
        bestDealNearWork = sortedStations.first
    }

    private func loadUserProfile() {
        userProfile = PersistenceManager.shared.fetchUserProfile()
        if let profile = userProfile {
            selectedFuelType = profile.fuelType
        }
    }

    private func updateAdviceMessage() {
        guard let profile = userProfile else {
            adviceMessage = nil
            return
        }
        let cheapestStation = bestDealNearHome ?? bestDealNearWork ?? stations.first
        adviceMessage = advisorService.advice(profile: profile, cheapestStation: cheapestStation)
    }

    private var cachedStations: [FuelStation] {
        Array(cachedStationsById.values)
    }

    private func setCachedStations(_ stations: [FuelStation]) {
        cachedStationsById = Dictionary(uniqueKeysWithValues: stations.map { ($0.id, $0) })
    }

    private func cacheStations(_ stations: [FuelStation]) {
        for station in stations {
            cachedStationsById[station.id] = station
        }
    }

    private func fetchStationsForRegion(center: CLLocationCoordinate2D, radiusKm: Double) async {
        if isRegionCovered(center: center, radiusKm: radiusKm) {
            stations = stationsForVisibleRegion(center: center, radiusKm: radiusKm)
            return
        }

        state = .loading
        var finalState: ViewState = .idle
        defer { state = finalState }
        do {
            let fetchedStations = try await dataService.fetchStations(
                latitude: center.latitude,
                longitude: center.longitude,
                radius: radiusKm
            )
            cacheStations(fetchedStations)
            cachedRegions.append(RegionCache(center: center, radiusKm: radiusKm))
            stations = stationsForVisibleRegion(center: center, radiusKm: radiusKm)
        } catch let error as FuelError {
            let message = StationsViewModelError.data(error).localizedDescription
            errorMessage = message
            finalState = .error(message)
        } catch {
            let message = StationsViewModelError.unexpected(error).localizedDescription
            errorMessage = message
            finalState = .error(message)
        }
    }

    private func stationsForVisibleRegion(center: CLLocationCoordinate2D, radiusKm: Double) -> [FuelStation] {
        let location = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let fuelType = selectedFuelType
        let stations = cachedStations
        let stationsWithDistance = stations.map { station -> FuelStation in
            var mutable = station
            let stationCoordinate = CLLocationCoordinate2D(
                latitude: station.latitude,
                longitude: station.longitude
            )
            mutable.distanceKm = LocationManager.distanceKm(from: location.coordinate, to: stationCoordinate)
            return mutable
        }
        let filtered = stationsWithDistance.filter { ($0.distanceKm ?? .greatestFiniteMagnitude) <= radiusKm }
        if filtered.isEmpty {
            return stationsWithDistance
        }
        return filtered.filter { station in
            station.prices.contains { $0.fuelType == fuelType }
        }
    }

    private func isRegionCovered(center: CLLocationCoordinate2D, radiusKm: Double) -> Bool {
        cachedRegions.contains { cached in
            let distance = LocationManager.distanceKm(from: cached.center, to: center)
            return distance + radiusKm <= cached.radiusKm
        }
    }
}

private struct RegionCache {
    let center: CLLocationCoordinate2D
    let radiusKm: Double
}

private struct PriceAnalysisKey: Hashable {
    let stationId: String
    let fuelType: FuelType
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
