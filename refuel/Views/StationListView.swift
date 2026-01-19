//
//  StationListView.swift
//  refuel
//
//  Created by Codex on 2026-01-18.
//

import SwiftUI

struct StationListView: View {
    @State private var viewModel: StationsViewModel
    @State private var hasAppeared = false
    @State private var selectedStation: FuelStation?
    @State private var searchText = ""

    @MainActor
    init(viewModel: StationsViewModel? = nil) {
        if let viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            _viewModel = State(initialValue: StationsViewModel())
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView("Recherche des stations...")
                case .error(let message):
                    ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle", description: Text(message))
                case .idle:
                    List {
                        // 🔥 BEST DEAL - Highlighted cheapest station
                        if let cheapest = viewModel.stations.first {
                            Section {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "star.fill")
                                            .foregroundStyle(.yellow)
                                        Text("Meilleure Offre")
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if let price = viewModel.price(for: cheapest) {
                                            Text(String(format: "%.3f €/L", price))
                                                .font(.title2.bold())
                                                .foregroundStyle(.green)
                                        }
                                    }
                                    
                                    NavigationLink(value: cheapest) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(cheapest.city ?? "Station")
                                                    .font(.subheadline.bold())
                                                Text(cheapest.address ?? "")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            if let distance = cheapest.distanceKm {
                                                Text(String(format: "%.1f km", distance))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.1))
                            )
                        }
                        
                        // 🏠🏢 Home vs Work comparison if both are set
                        if let home = viewModel.bestDealNearHome,
                           let work = viewModel.bestDealNearWork {
                            Section("Où faire le plein?") {
                                HStack(spacing: 16) {
                                    // Home card
                                    VStack(spacing: 4) {
                                        Image(systemName: "house.fill")
                                            .font(.title2)
                                        Text("Maison")
                                            .font(.caption.bold())
                                        if let price = viewModel.price(for: home) {
                                            Text(String(format: "%.3f€", price))
                                                .font(.headline)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                                    
                                    // Work card
                                    VStack(spacing: 4) {
                                        Image(systemName: "briefcase.fill")
                                            .font(.title2)
                                        Text("Travail")
                                            .font(.caption.bold())
                                        if let price = viewModel.price(for: work) {
                                            Text(String(format: "%.3f€", price))
                                                .font(.headline)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        
                        // Advice section
                        if let message = viewModel.adviceMessage {
                            Section {
                                Label(message, systemImage: "lightbulb.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                            }
                        }
                        
                        // Fuel type picker
                        Section("Carburant") {
                            Picker("Type", selection: $viewModel.selectedFuelType) {
                                ForEach(FuelType.allCases) { fuel in
                                    Text(fuel.rawValue).tag(fuel)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        // Stations list
                        Section("Toutes les stations (\\(viewModel.stations.count))") {
                            ForEach(viewModel.stations) { station in
                                NavigationLink(value: station) {
                                    StationRow(
                                        station: station,
                                        fuelType: viewModel.selectedFuelType,
                                        price: viewModel.price(for: station),
                                        priceLevel: viewModel.priceLevel(for: station)
                                    )
                                }
                                .task {
                                    await viewModel.loadPriceAnalysis(for: station)
                                }
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.loadStations()
                    }
                }
            }
            .navigationTitle("REFUEL")
            .searchable(text: $searchText, prompt: "Ville")
            .onSubmit(of: .search) {
                Task { await viewModel.search(city: searchText) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.loadStations() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .navigationDestination(for: FuelStation.self) { station in
                StationDetailView(station: station)
            }
            .task {
                if !hasAppeared && !isPreview {
                    await viewModel.loadStations()
                    hasAppeared = true
                }
            }
        }
    }

    private func adviceCard(message: String) -> some View {
        GlassCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
    }

    @ViewBuilder
    private var bestDealSection: some View {
        if let homeStation = viewModel.bestDealNearHome,
           let workStation = viewModel.bestDealNearWork {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Best Deal Near Home vs Work")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    bestDealCard(title: "Home", station: homeStation)
                    bestDealCard(title: "Work", station: workStation)
                }
            }
        }
    }

    private func bestDealCard(title: String, station: FuelStation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text((station.city ?? "Unknown city").capitalized)
                    .font(.headline)
                Text((station.address ?? "Unknown address").capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            PriceBadge(price: viewModel.price(for: station), fuelType: viewModel.selectedFuelType)
        }
    }

    private var headerCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Votre carburant")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Picker("Carburant", selection: $viewModel.selectedFuelType) {
                    ForEach(FuelType.allCases) { fuel in
                        Text(fuel.rawValue).tag(fuel)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.cyan.opacity(0.18),
                    Color.orange.opacity(0.12),
                    Color.blue.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.yellow.opacity(0.18))
                .frame(width: 240, height: 240)
                .blur(radius: 40)
                .offset(x: 140, y: -220)

            RoundedRectangle(cornerRadius: 120, style: .continuous)
                .fill(Color.cyan.opacity(0.12))
                .frame(width: 280, height: 180)
                .blur(radius: 50)
                .offset(x: -160, y: 240)
        }
    }

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

struct StationRow: View {
    let station: FuelStation
    let fuelType: FuelType
    let price: Double?
    let priceLevel: PriceLevel?
    
    var body: some View {
        GlassCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text((station.city ?? "Unknown city").capitalized)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text((station.address ?? "Unknown address").capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let distance = station.distanceKm {
                        Label(String(format: "%.1f km", distance), systemImage: "location.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    PriceBadge(price: price, fuelType: fuelType)
                    if let priceLevel {
                        Circle()
                            .fill(priceLevel.color)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                            .accessibilityLabel(priceLevel.label)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    StationListView(viewModel: .preview())
}
