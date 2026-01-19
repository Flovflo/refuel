//
//  PersistenceManager.swift
//  refuel
//
//  Created by Codex on 2026-01-20.
//

import CoreLocation
import Foundation
import SwiftData

@MainActor
final class PersistenceManager {
    static let shared = PersistenceManager()

    let container: ModelContainer
    let context: ModelContext

    init(inMemory: Bool = false) {
        Self.ensureApplicationSupportDirectoryExists()
        let schema = Schema([UserProfile.self, RefillEntry.self, StationPriceHistory.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print(
                "CRITICAL: Failed to create persistent container, falling back to in-memory. Error: \(error)"
            )
            let fallbackConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: schema, configurations: [fallbackConfiguration])
        }

        context = container.mainContext
    }

    func fetchUserProfile() -> UserProfile? {
        var descriptor = FetchDescriptor<UserProfile>()
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func createProfile(
        fuelType: FuelType,
        tankCapacity: Double,
        consumption: Double,
        lastRefillDate: Date? = nil,
        refillFrequencyDays: Int? = nil,
        homeCoordinate: CLLocationCoordinate2D? = nil,
        workCoordinate: CLLocationCoordinate2D? = nil,
        homeAddress: String? = nil,
        workAddress: String? = nil,
        comparisonRadius: Double = 15.0
    ) -> UserProfile {
        let profile = UserProfile(
            fuelType: fuelType,
            tankCapacity: tankCapacity,
            fuelConsumption: consumption,
            lastRefillDate: lastRefillDate,
            refillFrequencyDays: refillFrequencyDays,
            homeLatitude: homeCoordinate?.latitude,
            homeLongitude: homeCoordinate?.longitude,
            workLatitude: workCoordinate?.latitude,
            workLongitude: workCoordinate?.longitude,
            homeAddress: homeAddress,
            workAddress: workAddress,
            comparisonRadius: comparisonRadius
        )
        context.insert(profile)
        save()
        return profile
    }

    func updateProfile(_ profile: UserProfile) {
        save()
    }

    func save() {
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to save SwiftData context: \(error.localizedDescription)")
        }
    }

    func recordPriceHistory(for stations: [FuelStation], calendar: Calendar = .current) {
        for station in stations {
            for price in station.prices {
                let day = calendar.startOfDay(for: price.lastUpdate)
                let stationID = station.id
                let fuelType = price.fuelType
                let priceValue = price.price
                let predicate = #Predicate<StationPriceHistory> {
                    $0.stationID == stationID && $0.date == day
                }
                var descriptor = FetchDescriptor(predicate: predicate)
                // descriptor.fetchLimit = 1 // Remove limit to find all for this day/station, then filter by type

                do {
                    let candidates = try context.fetch(descriptor)
                    if let existing = candidates.first(where: { $0.fuelType == fuelType }) {
                        existing.price = priceValue
                        existing.date = day
                    } else {
                        let record = StationPriceHistory(
                            stationID: stationID,
                            date: day,
                            fuelType: fuelType,
                            price: priceValue
                        )
                        context.insert(record)
                    }
                } catch {
                    assertionFailure("Failed to fetch price history: \(error.localizedDescription)")
                }
            }
        }
        save()
    }

    private static func ensureApplicationSupportDirectoryExists() {
        let fileManager = FileManager.default
        let appSupportURL = URL.applicationSupportDirectory

        guard !fileManager.fileExists(atPath: appSupportURL.path) else { return }

        do {
            try fileManager.createDirectory(
                at: appSupportURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            fatalError("Failed to create Application Support directory: \(error.localizedDescription)")
        }
    }
}
