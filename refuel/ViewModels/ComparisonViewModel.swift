//
//  ComparisonViewModel.swift
//  refuel
//
//  Created by Codex on 2026-01-21.
//

import CoreLocation
import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class ComparisonViewModel {
    var bestNearHome: FuelStation?
    var bestNearWork: FuelStation?
    var recommendation: String?
    var errorMessage: String?
    var isLoading = false
    var fuelType: FuelType = .gazole
    var comparisonRadius: Double = 15.0

    private let dataService: FuelDataService
    private let persistenceManager: PersistenceManager
    private let logger = Logger.refuel
    private var userProfile: UserProfile?

    init(
        dataService: FuelDataService? = nil,
        persistenceManager: PersistenceManager? = nil
    ) {
        self.dataService = dataService ?? FuelDataService()
        self.persistenceManager = persistenceManager ?? .shared
        loadUserProfile()
    }

    func loadComparison() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        guard let profile = userProfile else {
            errorMessage = "Profil utilisateur introuvable."
            return
        }

        fuelType = profile.fuelType
        comparisonRadius = profile.comparisonRadius
        let radius = comparisonRadius

        if let home = profile.homeCoordinate {
            bestNearHome = await fetchBestStation(near: home, radius: radius)
        } else {
            bestNearHome = nil
        }

        if let work = profile.workCoordinate {
            bestNearWork = await fetchBestStation(near: work, radius: radius)
        } else {
            bestNearWork = nil
        }

        recommendation = buildRecommendation(profile: profile)
    }

    private func fetchBestStation(near coordinate: CLLocationCoordinate2D, radius: Double) async -> FuelStation? {
        do {
            let fetchedStations = try await dataService.fetchStations(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                radius: radius
            )
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let fuelType = fuelType
            let sortedStations = await Task.detached(priority: .userInitiated) {
                StationsViewModel.processStations(
                    fetchedStations,
                    with: location,
                    fuelType: fuelType,
                    maxRadiusKm: radius
                )
            }.value
            return sortedStations.first
        } catch {
            logger.error("Comparison fetch failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Impossible de charger la comparaison."
            return nil
        }
    }

    private func buildRecommendation(profile: UserProfile) -> String? {
        guard let homeStation = bestNearHome,
              let workStation = bestNearWork else {
            return nil
        }

        guard let homePrice = homeStation.prices.first(where: { $0.fuelType == fuelType })?.price,
              let workPrice = workStation.prices.first(where: { $0.fuelType == fuelType })?.price else {
            return nil
        }

        let tankCapacity = profile.tankCapacity
        let difference = abs(homePrice - workPrice)
        if difference < 0.001 {
            return "Prix similaires entre maison et travail."
        }

        let savings = difference * tankCapacity
        if workPrice < homePrice {
            return String(format: "Vous economisez %.2f€ en faisant le plein pres du travail.", savings)
        }
        return String(format: "Vous economisez %.2f€ en faisant le plein pres de la maison.", savings)
    }

    private func loadUserProfile() {
        userProfile = persistenceManager.fetchUserProfile()
        if let profile = userProfile {
            fuelType = profile.fuelType
            comparisonRadius = profile.comparisonRadius
        }
    }
}
