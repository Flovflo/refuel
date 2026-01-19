//
//  StationDetailViewModel.swift
//  refuel
//
//  Created by Codex on 2026-01-21.
//

import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class StationDetailViewModel {
    enum ViewState: Equatable {
        case idle
        case loading
        case error(String)
    }

    let station: FuelStation
    var analysisByFuelType: [FuelType: PriceAnalysis] = [:]
    var state: ViewState = .idle
    var errorMessage: String?
    var selectedFuelType: FuelType = .gazole

    private let dataService: FuelDataService
    private let persistenceManager: PersistenceManager
    private let logger = Logger.refuel

    init(
        station: FuelStation,
        dataService: FuelDataService? = nil,
        persistenceManager: PersistenceManager? = nil
    ) {
        self.station = station
        self.dataService = dataService ?? FuelDataService()
        self.persistenceManager = persistenceManager ?? .shared
        if let profile = self.persistenceManager.fetchUserProfile() {
            selectedFuelType = profile.fuelType
        }
    }

    var primaryAnalysis: PriceAnalysis? {
        analysisByFuelType[selectedFuelType]
    }

    func load() async {
        state = .loading
        errorMessage = nil
        var finalState: ViewState = .idle
        defer { state = finalState }

        let stationId = station.id
        let fuelTypes = Set(station.prices.map { $0.fuelType })
        var results: [FuelType: PriceAnalysis] = [:]

        await withTaskGroup(of: (FuelType, PriceAnalysis?).self) { group in
            for fuelType in fuelTypes {
                group.addTask { [dataService] in
                    do {
                        let analysis = try await dataService.fetchPriceAnalysis(
                            stationId: stationId,
                            fuelType: fuelType
                        )
                        return (fuelType, analysis)
                    } catch {
                        return (fuelType, nil)
                    }
                }
            }

            for await (fuelType, analysis) in group {
                if let analysis {
                    results[fuelType] = analysis
                }
            }
        }

        analysisByFuelType = results
        if analysisByFuelType.isEmpty {
            let message = "Analyse indisponible."
            errorMessage = message
            finalState = .error(message)
            logger.warning("StationDetail analysis empty")
        }
    }
}
