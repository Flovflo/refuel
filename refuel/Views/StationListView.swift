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
            ZStack {
                backgroundView
                    .allowsHitTesting(false)

                contentView
            }
            .navigationTitle("REFUEL")
            .searchable(text: $searchText, prompt: "Ville")
            .onSubmit(of: .search) {
                Task { await viewModel.search(city: searchText) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Task { await viewModel.loadStations() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .navigationDestination(item: $selectedStation) { station in
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

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .loading:
            ProgressView("Recherche des stations...")
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        case .error(let message):
            VStack(spacing: 16) {
                ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle.fill", description: Text(message))
                Button("Réessayer") {
                    Task { await viewModel.loadStations() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        case .idle:
            stationListView
        }
    }

    private var stationListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let message = viewModel.adviceMessage {
                    adviceCard(message: message)
                }

                headerCard

                bestDealSection

                if let message = viewModel.errorMessage {
                    GlassCard {
                        Label(message, systemImage: "location.slash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                LazyVStack(spacing: 14) {
                    ForEach(viewModel.stations) { station in
                        Button {
                            selectedStation = station
                        } label: {
                            StationRow(
                                station: station,
                                fuelType: viewModel.selectedFuelType,
                                price: viewModel.price(for: station)
                            )
                        }
                        .contentShape(Rectangle())
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .refreshable {
            await viewModel.loadStations()
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
                Text(station.city.capitalized)
                    .font(.headline)
                Text(station.address.capitalized)
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
    
    var body: some View {
        GlassCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(station.city.capitalized)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(station.address.capitalized)
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
                
                PriceBadge(price: price, fuelType: fuelType)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    StationListView(viewModel: .preview())
}
