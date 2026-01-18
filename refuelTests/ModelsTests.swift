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
}
