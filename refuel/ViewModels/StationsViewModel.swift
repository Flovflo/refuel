import CoreLocation
import Foundation
import Observation

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

    private let dataService: FuelDataService
    private let locationManager: LocationManager

    init(
        dataService: FuelDataService? = nil,
        locationManager: LocationManager? = nil
    ) {
        self.dataService = dataService ?? FuelDataService()
        self.locationManager = locationManager ?? LocationManager()
    }

    func loadStations() async {
        state = .loading
        errorMessage = nil

        do {
            let fetchedStations = try await fetchStationsSorted(using: await resolveUserLocation())
            stations = fetchedStations
            state = .idle
        } catch let error as FuelError {
            let message = StationsViewModelError.data(error).localizedDescription
            errorMessage = message
            state = .error(message)
        } catch {
            let message = StationsViewModelError.unexpected(error).localizedDescription
            errorMessage = message
            state = .error(message)
        }
    }

    func search(city: String) async {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await loadStations()
            return
        }

        state = .loading
        errorMessage = nil

        do {
            let coordinate = try await locationManager.geocode(city: trimmed)
            let searchLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let fetchedStations = try await fetchStationsSorted(using: searchLocation)
            stations = fetchedStations
            state = .idle
        } catch let error as FuelError {
            let message = StationsViewModelError.data(error).localizedDescription
            errorMessage = message
            state = .error(message)
        } catch {
            let message = StationsViewModelError.location(error).localizedDescription
            errorMessage = message
            state = .error(message)
        }
    }

    private func resolveUserLocation() async -> CLLocation? {
        do {
            return try await locationManager.getCurrentLocation()
        } catch {
            // Simplify error handling for location
            errorMessage = StationsViewModelError.location(error).localizedDescription
            return locationManager.lastKnownLocation
        }
    }

    private func fetchStationsSorted(using location: CLLocation?) async throws -> [FuelStation] {
        let fetchedStations = try await dataService.fetchStations()
        return sortStations(fetchedStations, with: location)
    }

    private func sortStations(_ stations: [FuelStation], with location: CLLocation?) -> [FuelStation] {
        guard let location else {
            return stations.sorted { lhs, rhs in
                lhs.city.localizedCaseInsensitiveCompare(rhs.city) == .orderedAscending
            }
        }

        let userCoordinate = location.coordinate
        var updated = stations.map { station -> FuelStation in
            var mutable = station
            let stationCoordinate = CLLocationCoordinate2D(
                latitude: station.latitude,
                longitude: station.longitude
            )
            mutable.distanceKm = LocationManager.distanceKm(from: userCoordinate, to: stationCoordinate)
            return mutable
        }

        updated.sort { lhs, rhs in
            let leftDistance = lhs.distanceKm ?? .greatestFiniteMagnitude
            let rightDistance = rhs.distanceKm ?? .greatestFiniteMagnitude
            return leftDistance < rightDistance
        }

        return updated
    }

    func price(for station: FuelStation, fallbackToCheapest: Bool = false) -> Double? {
        if let match = station.prices.first(where: { $0.fuelType == selectedFuelType }) {
            return match.price
        }
        return fallbackToCheapest ? station.cheapestPrice : nil
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
