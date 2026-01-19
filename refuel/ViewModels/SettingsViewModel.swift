//
//  SettingsViewModel.swift
//  refuel
//
//  Created by Codex on 2026-01-21.
//

import CoreLocation
import Foundation
import MapKit
import Observation
import OSLog

@Observable
@MainActor
final class SettingsViewModel: NSObject {
    var homeQuery: String = ""
    var workQuery: String = ""
    var homeCompletions: [MKLocalSearchCompletion] = []
    var workCompletions: [MKLocalSearchCompletion] = []
    var comparisonRadius: Double = 15.0
    var errorMessage: String?
    var isSaving = false

    private let homeCompleter = MKLocalSearchCompleter()
    private let workCompleter = MKLocalSearchCompleter()
    private let persistenceManager: PersistenceManager
    private let locationManager: LocationManager
    private let logger = Logger.refuel
    private var userProfile: UserProfile?

    init(
        persistenceManager: PersistenceManager? = nil,
        locationManager: LocationManager? = nil
    ) {
        self.persistenceManager = persistenceManager ?? .shared
        self.locationManager = locationManager ?? LocationManager()
        super.init()
        homeCompleter.delegate = self
        workCompleter.delegate = self
        homeCompleter.resultTypes = .address
        workCompleter.resultTypes = .address
        loadProfile()
    }

    func updateHomeQuery(_ value: String) {
        homeQuery = value
        homeCompleter.queryFragment = value
    }

    func updateWorkQuery(_ value: String) {
        workQuery = value
        workCompleter.queryFragment = value
    }

    func selectHomeCompletion(_ completion: MKLocalSearchCompletion) {
        homeQuery = completion.fullText
        homeCompletions = []
    }

    func selectWorkCompletion(_ completion: MKLocalSearchCompletion) {
        workQuery = completion.fullText
        workCompletions = []
    }

    func clearHome() {
        homeQuery = ""
        homeCompletions = []
    }

    func clearWork() {
        workQuery = ""
        workCompletions = []
    }

    func save() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil

        guard let profile = userProfile else {
            errorMessage = "Profil utilisateur introuvable."
            return
        }

        do {
            let homeCoordinate = try await geocodeIfNeeded(homeQuery)
            let workCoordinate = try await geocodeIfNeeded(workQuery)

            profile.homeLatitude = homeCoordinate?.latitude
            profile.homeLongitude = homeCoordinate?.longitude
            profile.workLatitude = workCoordinate?.latitude
            profile.workLongitude = workCoordinate?.longitude
            profile.homeAddress = homeQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.workAddress = workQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.comparisonRadius = comparisonRadius
            persistenceManager.updateProfile(profile)
        } catch {
            logger.error("Settings save failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    private func geocodeIfNeeded(_ address: String) async throws -> CLLocationCoordinate2D? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return try await locationManager.geocode(city: trimmed)
    }

    private func loadProfile() {
        userProfile = persistenceManager.fetchUserProfile()
        if let profile = userProfile {
            homeQuery = profile.homeAddress ?? ""
            workQuery = profile.workAddress ?? ""
            comparisonRadius = profile.comparisonRadius
        }
    }
}

extension SettingsViewModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        if completer === homeCompleter {
            homeCompletions = completer.results
        } else if completer === workCompleter {
            workCompletions = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }
}

extension MKLocalSearchCompletion {
    var fullText: String {
        [title, subtitle]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}
