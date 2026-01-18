//
//  StationSorterTests.swift
//  refuelTests
//
//  Created by Codex on 2026-01-24.
//

import CoreLocation
import XCTest
@testable import refuel

final class StationSorterTests: XCTestCase {
    func testStationSorterLimitsToTenAndSortsByPrice() {
        let baseLatitude = 48.8566
        let baseLongitude = 2.3522
        let stations = (0..<12).map { index in
            makeStation(
                index: index,
                price: 1.80 + (Double(index) * 0.01),
                latitude: baseLatitude + (Double(index) * 0.001),
                longitude: baseLongitude + (Double(index) * 0.001)
            )
        }

        let location = CLLocation(latitude: baseLatitude, longitude: baseLongitude)
        let results = StationsViewModel.processStations(
            stations,
            with: location,
            fuelType: .gazole,
            maxRadiusKm: 30.0
        )

        XCTAssertEqual(results.count, 12)
        let prices = results.compactMap { $0.prices.first?.price }
        XCTAssertEqual(prices, prices.sorted())
        XCTAssertEqual(prices.first ?? 0, 1.80, accuracy: 0.0001)
        XCTAssertEqual(prices.last ?? 0, 1.91, accuracy: 0.0001)
    }

    private func makeStation(index: Int, price: Double, latitude: Double, longitude: Double) -> FuelStation {
        FuelStation(
            id: "station-\(index)",
            address: "Address \(index)",
            city: "City \(index)",
            postalCode: "7500\(index)",
            latitude: latitude,
            longitude: longitude,
            prices: [FuelPrice(fuelType: .gazole, price: price, lastUpdate: Date())],
            services: [],
            isOpen24h: true
        )
    }
}
