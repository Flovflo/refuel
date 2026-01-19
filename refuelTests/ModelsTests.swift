//
//  ModelsTests.swift
//  refuelTests
//
//  Created by Codex on 2026-01-18.
//

import XCTest
import CoreLocation
@testable import refuel

final class ModelsTests: XCTestCase {

    func testFuelTypeAttributes() {
        XCTAssertEqual(FuelType.gazole.icon, "fuelpump.fill")
        XCTAssertEqual(FuelType.gazole.id, "Gazole")
    }
    
    func testFuelStationGetters() {
        let price1 = FuelPrice(fuelType: .gazole, price: 1.65, lastUpdate: Date())
        let price2 = FuelPrice(fuelType: .sp95, price: 1.75, lastUpdate: Date())
        
        let station = FuelStation(
            id: "1",
            address: "Rue Test",
            city: "TestCity",
            postalCode: "12345",
            latitude: 48.0,
            longitude: 2.0,
            prices: [price1, price2],
            services: ["DAB"],
            isOpen24h: true
        )
        
        XCTAssertEqual(station.cheapestGazole, 1.65)
        XCTAssertEqual(station.cheapestPrice, 1.65)
        XCTAssertEqual(station.coordinate.latitude, 48.0)
    }

    func testPriceAnalysisLevel() {
        let analysisLow = PriceAnalysis(
            stationId: "1",
            fuelType: .gazole,
            currentPrice: 1.45,
            avg30Days: 1.50,
            min30Days: 1.40,
            max30Days: 1.60,
            percentile: 15,
            trend: "decreasing"
        )
        let analysisAverage = PriceAnalysis(
            stationId: "2",
            fuelType: .gazole,
            currentPrice: 1.52,
            avg30Days: 1.50,
            min30Days: 1.40,
            max30Days: 1.60,
            percentile: 55,
            trend: "stable"
        )
        let analysisHigh = PriceAnalysis(
            stationId: "3",
            fuelType: .gazole,
            currentPrice: 1.58,
            avg30Days: 1.50,
            min30Days: 1.40,
            max30Days: 1.60,
            percentile: 90,
            trend: "increasing"
        )

        XCTAssertEqual(analysisLow.priceLevel, .low)
        XCTAssertEqual(analysisAverage.priceLevel, .average)
        XCTAssertEqual(analysisHigh.priceLevel, .high)
    }
}
