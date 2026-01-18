//
//  OnboardingView.swift
//  refuel
//
//  Created by Codex on 2026-01-20.
//

import CoreLocation
import Foundation
import SwiftData
import SwiftUI

struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel

    @MainActor
    init(viewModel: OnboardingViewModel? = nil) {
        if let viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            _viewModel = State(
                initialValue: OnboardingViewModel(
                    persistenceManager: .shared,
                    locationManager: LocationManager()
                )
            )
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView

                TabView(selection: $viewModel.step) {
                    vehicleStep
                        .tag(0)

                    locationStep
                        .tag(1)

                    finishStep
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(.easeInOut, value: viewModel.step)
            }
            .navigationTitle("Bienvenue")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
            .alert(
                "Erreur",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.errorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var vehicleStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Votre vehicule", systemImage: "car.fill")
                            .font(.headline)

                        Text("Choisissez votre carburant et renseignez les capacites.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Picker("Carburant", selection: $viewModel.fuelType) {
                            ForEach(FuelType.allCases) { fuel in
                                Text(fuel.rawValue).tag(fuel)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                GlassCard {
                    VStack(spacing: 12) {
                        TextField("Capacite du reservoir (L)", text: $viewModel.tankCapacityText)
                            .keyboardType(.decimalPad)
                            .textInputAutocapitalization(.never)

                        Divider()

                        TextField("Consommation (L/100 km)", text: $viewModel.consumptionText)
                            .keyboardType(.decimalPad)
                            .textInputAutocapitalization(.never)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Habitudes de plein", systemImage: "clock.arrow.circlepath")
                            .font(.headline)

                        DatePicker(
                            "Quand etait votre dernier plein ?",
                            selection: $viewModel.lastRefillDate,
                            displayedComponents: .date
                        )

                        Divider()

                        Picker("Frequence de plein", selection: $viewModel.refillFrequencyDays) {
                            ForEach(viewModel.refillFrequencyOptions) { option in
                                Text(option.label).tag(option.days)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 120)
        }
    }

    private var locationStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Vos trajets", systemImage: "location.fill")
                            .font(.headline)

                        Text("Renseignez vos lieux principaux pour prioriser les stations.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                GlassCard {
                    VStack(spacing: 12) {
                        TextField("Domicile (ville ou adresse)", text: $viewModel.homeAddress)
                            .textInputAutocapitalization(.words)

                        Divider()

                        TextField("Travail (ville ou adresse)", text: $viewModel.workAddress)
                            .textInputAutocapitalization(.words)
                    }
                }

                Text("Le geocodage est fait au moment de la validation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 120)
        }
    }

    private var finishStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Resume", systemImage: "checkmark.seal.fill")
                            .font(.headline)

                        HStack {
                            Text("Carburant")
                            Spacer()
                            Text(viewModel.fuelType.rawValue)
                        }
                        .font(.subheadline)

                        HStack {
                            Text("Reservoir")
                            Spacer()
                            Text("\(viewModel.formatted(value: viewModel.tankCapacityValue)) L")
                        }
                        .font(.subheadline)

                        HStack {
                            Text("Conso")
                            Spacer()
                            Text("\(viewModel.formatted(value: viewModel.consumptionValue)) L/100")
                        }
                        .font(.subheadline)

                        HStack {
                            Text("Dernier plein")
                            Spacer()
                            Text(viewModel.lastRefillDateText)
                        }
                        .font(.subheadline)

                        HStack {
                            Text("Frequence")
                            Spacer()
                            Text(viewModel.refillFrequencyLabel)
                        }
                        .font(.subheadline)

                        if !viewModel.homeAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HStack {
                                Text("Domicile")
                                Spacer()
                                Text(viewModel.homeAddress)
                                    .multilineTextAlignment(.trailing)
                            }
                            .font(.subheadline)
                        }

                        if !viewModel.workAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HStack {
                                Text("Travail")
                                Spacer()
                                Text(viewModel.workAddress)
                                    .multilineTextAlignment(.trailing)
                            }
                            .font(.subheadline)
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pret a economiser ?")
                            .font(.headline)
                        Text("Appuyez sur Start ReFueling pour lancer la recherche.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 120)
        }
    }

    private var actionBar: some View {
        GlassCard(cornerRadius: 18) {
            HStack(spacing: 12) {
                if viewModel.step > 0 {
                    Button("Retour") {
                        withAnimation(.easeInOut) {
                            viewModel.previousStep()
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if viewModel.step < 2 {
                    Button("Suivant") {
                        withAnimation(.easeInOut) {
                            viewModel.nextStep()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.step == 0 && !viewModel.canAdvanceFromVehicle)
                } else {
                    Button {
                        Task { await viewModel.finish() }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Start ReFueling")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canAdvanceFromVehicle || viewModel.isSaving)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.orange.opacity(0.2),
                    Color.cyan.opacity(0.15),
                    Color.blue.opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 260, height: 260)
                .blur(radius: 45)
                .offset(x: 140, y: -220)

            RoundedRectangle(cornerRadius: 120, style: .continuous)
                .fill(Color.cyan.opacity(0.15))
                .frame(width: 300, height: 180)
                .blur(radius: 50)
                .offset(x: -160, y: 240)
        }
    }
}

@MainActor
@Observable
final class OnboardingViewModel {
    var step = 0
    var fuelType: FuelType = .gazole
    var tankCapacityText = ""
    var consumptionText = ""
    var lastRefillDate = Date()
    var refillFrequencyDays = 7
    var homeAddress = ""
    var workAddress = ""
    var errorMessage: String?
    var isSaving = false

    private let persistenceManager: PersistenceManager
    private let locationManager: LocationManager

    init(
        persistenceManager: PersistenceManager,
        locationManager: LocationManager
    ) {
        self.persistenceManager = persistenceManager
        self.locationManager = locationManager
    }

    var tankCapacityValue: Double? {
        parseDouble(from: tankCapacityText)
    }

    var consumptionValue: Double? {
        parseDouble(from: consumptionText)
    }

    var canAdvanceFromVehicle: Bool {
        tankCapacityValue != nil && consumptionValue != nil
    }

    var refillFrequencyOptions: [RefillFrequencyOption] {
        [
            RefillFrequencyOption(label: "Chaque semaine", days: 7),
            RefillFrequencyOption(label: "Toutes les 2 semaines", days: 14),
            RefillFrequencyOption(label: "Une fois par mois", days: 30),
            RefillFrequencyOption(label: "Toutes les 6 semaines", days: 42)
        ]
    }

    var lastRefillDateText: String {
        Self.dateFormatter.string(from: lastRefillDate)
    }

    var refillFrequencyLabel: String {
        refillFrequencyOptions.first(where: { $0.days == refillFrequencyDays })?.label
            ?? "\(refillFrequencyDays) jours"
    }

    func nextStep() {
        step = min(step + 1, 2)
    }

    func previousStep() {
        step = max(step - 1, 0)
    }

    func finish() async {
        guard !isSaving else { return }
        guard let tankCapacityValue, let consumptionValue else {
            errorMessage = "Renseignez la capacite et la consommation."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let homeCoordinate = try await geocodeIfNeeded(homeAddress)
            let workCoordinate = try await geocodeIfNeeded(workAddress)

            _ = persistenceManager.createProfile(
                fuelType: fuelType,
                tankCapacity: tankCapacityValue,
                consumption: consumptionValue,
                lastRefillDate: lastRefillDate,
                refillFrequencyDays: refillFrequencyDays,
                homeCoordinate: homeCoordinate,
                workCoordinate: workCoordinate
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func formatted(value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f", value)
    }

    private func parseDouble(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private func geocodeIfNeeded(_ address: String) async throws -> CLLocationCoordinate2D? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return try await locationManager.geocode(city: trimmed)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

struct RefillFrequencyOption: Identifiable {
    let label: String
    let days: Int

    var id: Int { days }
}

#Preview {
    OnboardingView()
        .modelContainer(PersistenceManager(inMemory: true).container)
}
