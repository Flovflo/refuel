//
//  PersistenceTests.swift
//  refuelTests
//
//  Created by Codex on 2026-01-20.
//

import SwiftData
import XCTest
@testable import refuel

final class PersistenceTests: XCTestCase {

    @MainActor
    func testCreateAndFetchProfile() {
        let manager = PersistenceManager(inMemory: true)
        let lastRefillDate = Date(timeIntervalSince1970: 1_728_000_000)

        let created = manager.createProfile(
            fuelType: .sp95,
            tankCapacity: 52.0,
            consumption: 6.4,
            lastRefillDate: lastRefillDate,
            refillFrequencyDays: 14
        )

        let fetched = manager.fetchUserProfile()

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.fuelType, created.fuelType)
        XCTAssertEqual(fetched?.tankCapacity, 52.0)
        XCTAssertEqual(fetched?.fuelConsumption, 6.4)
        XCTAssertEqual(fetched?.lastRefillDate, lastRefillDate)
        XCTAssertEqual(fetched?.refillFrequencyDays, 14)
    }

    @MainActor
    func testRecordPriceHistoryUpsertsByDay() {
        let manager = PersistenceManager(inMemory: true)
        let date = Date(timeIntervalSince1970: 1_728_268_800)

        let stations = [
            FuelStation(
                id: "station-1",
                address: "Rue Test",
                city: "Paris",
                postalCode: "75001",
                latitude: 48.8566,
                longitude: 2.3522,
                prices: [
                    FuelPrice(fuelType: .gazole, price: 1.789, lastUpdate: date)
                ],
                services: [],
                isOpen24h: false
            )
        ]

        manager.recordPriceHistory(for: stations, calendar: Calendar(identifier: .gregorian))
        manager.recordPriceHistory(
            for: [
                FuelStation(
                    id: "station-1",
                    address: "Rue Test",
                    city: "Paris",
                    postalCode: "75001",
                    latitude: 48.8566,
                    longitude: 2.3522,
                    prices: [
                        FuelPrice(fuelType: .gazole, price: 1.799, lastUpdate: date)
                    ],
                    services: [],
                    isOpen24h: false
                )
            ],
            calendar: Calendar(identifier: .gregorian)
        )

        let predicate = #Predicate<StationPriceHistory> {
            $0.stationID == "station-1"
        }
        let descriptor = FetchDescriptor<StationPriceHistory>(predicate: predicate)
        let fetchedHistory = try? manager.context.fetch(descriptor)
        let history = fetchedHistory?.filter { $0.fuelType == .gazole }

        XCTAssertEqual(history?.count, 1)
        XCTAssertEqual(history?.first?.price, 1.799)
    }
}
