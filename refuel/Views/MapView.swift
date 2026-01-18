//
//  MapView.swift
//  refuel
//
//  Created by Codex on 2026-01-18.
//

import SwiftUI
import MapKit

struct MapView: View {
    @State private var viewModel: StationsViewModel
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedStation: FuelStation?

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
                Map(position: $position) {
                    UserAnnotation()

                    ForEach(viewModel.stations) { station in
                        Annotation(station.city, coordinate: station.coordinate) {
                            Button {
                                selectedStation = station
                            } label: {
                                PriceBadge(
                                    price: viewModel.price(for: station, fallbackToCheapest: true),
                                    fuelType: viewModel.selectedFuelType
                                )
                                .shadow(radius: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }

                if case .loading = viewModel.state {
                    ProgressView("Chargement de la carte...")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                if case .error(let message) = viewModel.state {
                    ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle.fill", description: Text(message))
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
            .navigationTitle("Carte")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.loadStations() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .navigationDestination(item: $selectedStation) { station in
                StationDetailView(station: station)
            }
            .task {
                if !isPreview {
                    await viewModel.loadStations()
                }
            }
        }
    }

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

#Preview {
    MapView(viewModel: .preview())
}
