//
//  UserProfile.swift
//  refuel
//
//  Created by Codex on 2026-01-20.
//

import CoreLocation
import Foundation
import SwiftData

@Model
final class UserProfile {
    var fuelType: FuelType
    var tankCapacity: Double
    var fuelConsumption: Double
    var lastRefillDate: Date?
    var refillFrequencyDays: Int?
    var homeLatitude: Double?
    var homeLongitude: Double?
    var workLatitude: Double?
    var workLongitude: Double?
    @Relationship(deleteRule: .cascade, inverse: \RefillEntry.profile) var refills: [RefillEntry]

    init(
        fuelType: FuelType,
        tankCapacity: Double,
        fuelConsumption: Double,
        lastRefillDate: Date? = nil,
        refillFrequencyDays: Int? = nil,
        homeLatitude: Double? = nil,
        homeLongitude: Double? = nil,
        workLatitude: Double? = nil,
        workLongitude: Double? = nil,
        refills: [RefillEntry] = []
    ) {
        self.fuelType = fuelType
        self.tankCapacity = tankCapacity
        self.fuelConsumption = fuelConsumption
        self.lastRefillDate = lastRefillDate
        self.refillFrequencyDays = refillFrequencyDays
        self.homeLatitude = homeLatitude
        self.homeLongitude = homeLongitude
        self.workLatitude = workLatitude
        self.workLongitude = workLongitude
        self.refills = refills
    }

    var homeCoordinate: CLLocationCoordinate2D? {
        guard let latitude = homeLatitude, let longitude = homeLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var workCoordinate: CLLocationCoordinate2D? {
        guard let latitude = workLatitude, let longitude = workLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
