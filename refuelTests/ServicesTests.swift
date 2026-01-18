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
    
    func testJSONDecoding() throws {
        let json = """
        [
          {
            "id": "123456",
            "address": null,
            "city": null,
            "cp": null,
            "distance": 1.2,
            "prices": [
              { "fuel_type": "Gazole", "price": 1.7, "update_date": "2026-01-14T10:00:00" }
            ]
          }
        ]
        """

        guard let data = json.data(using: .utf8) else {
            XCTFail("Failed to create Data")
            return
        }

        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        decoder.dateDecodingStrategy = .formatted(formatter)
        let stations = try decoder.decode([FuelStation].self, from: data)

        XCTAssertEqual(stations.count, 1)
        let station = stations.first!

        XCTAssertEqual(station.id, "123456")
        XCTAssertNil(station.city)
        XCTAssertNil(station.postalCode)
        XCTAssertEqual(station.distanceKm ?? 0, 1.2, accuracy: 0.0001)
        XCTAssertEqual(station.prices.count, 1)
        XCTAssertEqual(station.prices.first?.price, 1.7)
        XCTAssertEqual(station.services, [])
        XCTAssertFalse(station.isOpen24h)
    }

    func testRealNetworkFetch() async throws {
        let shouldRun = ProcessInfo.processInfo.environment["RUN_REAL_NETWORK_TESTS"] == "1"
        try XCTSkipUnless(shouldRun, "Set RUN_REAL_NETWORK_TESTS=1 to run real network fetch.")

        let service = FuelDataService()
        let stations = try await service.fetchStations(
            latitude: 48.8566,
            longitude: 2.3522,
            radius: 5.0
        )
        XCTAssertGreaterThan(stations.count, 0)
    }

    @MainActor
    func testAdvisorServiceDaysUntilRefillReturnsZeroWhenDue() {
        let profile = UserProfile(
            fuelType: .gazole,
            tankCapacity: 50,
            fuelConsumption: 6.5,
            lastRefillDate: Date().addingTimeInterval(-10 * 24 * 60 * 60),
            refillFrequencyDays: 10
        )
        let service = AdvisorService()

        let days = service.daysUntilRefill(profile: profile)

        XCTAssertEqual(days, 0)
    }

    @MainActor
    func testAdvisorServiceCostPer100Km() {
        let station = FuelStation(
            id: "test",
            address: "Rue de Test",
            city: "Paris",
            postalCode: "75001",
            latitude: 48.8566,
            longitude: 2.3522,
            prices: [FuelPrice(fuelType: .gazole, price: 1.8, lastUpdate: Date())],
            services: [],
            isOpen24h: true
        )
        let service = AdvisorService()

        let cost = service.costPer100Km(station: station, fuelType: .gazole, consumption: 6.5)

        XCTAssertEqual(cost ?? 0, 11.7, accuracy: 0.0001)
    }

    @MainActor
    func testAdvisorServiceAdviceWithMissingProfileData() {
        let profile = UserProfile(
            fuelType: .sp95,
            tankCapacity: 45,
            fuelConsumption: 7.0
        )
        let service = AdvisorService()

        let message = service.advice(profile: profile, cheapestStation: nil)

        XCTAssertEqual(message, "Complete your profile to get personalized advice.")
    }
}
