//
//  ServicesTests.swift
//  refuelTests
//
//  Created by Codex on 2026-01-18.
//

import XCTest
import CoreLocation
@testable import refuel

final class ServicesTests: XCTestCase {

    func testLocationManagerInit() {
        let manager = LocationManager()
        XCTAssertNotNil(manager)
        XCTAssertFalse(manager.isAuthorized)
    }

    @MainActor
    func testGeocoding() async throws {
        let manager = LocationManager()
        let coordinate = try await manager.geocode(city: "Paris")

        XCTAssertEqual(coordinate.latitude, 48.8566, accuracy: 1.0)
        XCTAssertEqual(coordinate.longitude, 2.3522, accuracy: 1.0)
    }
    
    func testXMLParsing() async throws {
        // Mock XML Data
        let xmlString = """
        <root>
            <pdv id="123" latitude="4885660" longitude="235220" cp="75001">
                <adresse>Rue de Rivoli</adresse>
                <ville>Paris</ville>
                <prix nom="Gazole" id="1" maj="2026-01-14T10:00:00" valeur="1.999"/>
            </pdv>
        </root>
        """
        
        guard let data = xmlString.data(using: .utf8) else {
            XCTFail("Failed to create Data")
            return
        }
        
        // We use the internal parser directly to test logic
        let service = FuelDataService()
        // Accessing internal/private components is hard in Swift external tests.
        // We might need to expose the parser or make it internal and use @testable (which we do).
        // Since PDVParser is inside FuelDataService.swift but outside the actor extension (if I put it there),
        // let's check where I put it. I put it as a class at file scope.
        
        let parser = PDVParser(data: data)
        let stations = try await parser.parse()
        
        XCTAssertEqual(stations.count, 1)
        let station = stations.first!
        
        XCTAssertEqual(station.id, "123")
        XCTAssertEqual(station.city, "Paris")
        // Check coordinate conversion
        XCTAssertEqual(station.latitude, 48.85660, accuracy: 0.00001)
        XCTAssertEqual(station.prices.count, 1)
        XCTAssertEqual(station.prices.first?.price, 1.999)
    }

    func testRealNetworkFetch() async throws {
        let shouldRun = ProcessInfo.processInfo.environment["RUN_REAL_NETWORK_TESTS"] == "1"
        try XCTSkipUnless(shouldRun, "Set RUN_REAL_NETWORK_TESTS=1 to run real network fetch.")

        let service = FuelDataService()
        let stations = try await service.fetchStations()
        XCTAssertGreaterThan(stations.count, 0)
    }
}
