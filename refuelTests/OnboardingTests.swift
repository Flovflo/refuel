//
//  OnboardingTests.swift
//  refuelTests
//
//  Created by Codex on 2026-01-20.
//

import CoreLocation
import XCTest
@testable import refuel

final class OnboardingTests: XCTestCase {
    @MainActor
    func testOnboardingCreatesProfile() {
        let manager = PersistenceManager(inMemory: true)
        let home = CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
        let work = CLLocationCoordinate2D(latitude: 45.7640, longitude: 4.8357)
        let lastRefillDate = Date(timeIntervalSince1970: 1_728_100_000)

        _ = manager.createProfile(
            fuelType: .sp95,
            tankCapacity: 60.0,
            consumption: 7.1,
            lastRefillDate: lastRefillDate,
            refillFrequencyDays: 30,
            homeCoordinate: home,
            workCoordinate: work
        )

        guard let fetched = manager.fetchUserProfile() else {
            XCTFail("Expected a persisted profile.")
            return
        }

        XCTAssertEqual(fetched.fuelType, .sp95)
        XCTAssertEqual(fetched.tankCapacity, 60.0, accuracy: 0.001)
        XCTAssertEqual(fetched.fuelConsumption, 7.1, accuracy: 0.001)
        XCTAssertEqual(fetched.lastRefillDate, lastRefillDate)
        XCTAssertEqual(fetched.refillFrequencyDays, 30)
        XCTAssertNotNil(fetched.homeLatitude)
        XCTAssertNotNil(fetched.homeLongitude)
        XCTAssertNotNil(fetched.workLatitude)
        XCTAssertNotNil(fetched.workLongitude)
        XCTAssertEqual(fetched.homeLatitude ?? 0, home.latitude, accuracy: 0.000_001)
        XCTAssertEqual(fetched.homeLongitude ?? 0, home.longitude, accuracy: 0.000_001)
        XCTAssertEqual(fetched.workLatitude ?? 0, work.latitude, accuracy: 0.000_001)
        XCTAssertEqual(fetched.workLongitude ?? 0, work.longitude, accuracy: 0.000_001)
    }
}
