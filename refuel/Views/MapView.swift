//
//  MapView.swift
//  refuel
//
//  Created by Codex on 2026-01-18.
//

import MapKit
import SwiftUI

struct MapView: View {
    @State private var viewModel: StationsViewModel
    @State private var selectedStation: FuelStation?
    @State private var hasLoaded = false

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
                StationMapRepresentable(
                    stations: $viewModel.stations,
                    selectedStation: $selectedStation,
                    fuelType: viewModel.selectedFuelType,
                    priceProvider: { station in
                        viewModel.price(for: station, fallbackToCheapest: true)
                    },
                    onRegionChange: { region in
                        let radiusKm = max(1.0, region.span.latitudeDelta * 111 / 2)
                        viewModel.loadStationsForRegion(
                            lat: region.center.latitude,
                            lon: region.center.longitude,
                            radius: radiusKm
                        )
                    }
                )

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
                guard !isPreview, !hasLoaded else { return }
                await viewModel.loadStations()
                hasLoaded = true
            }
        }
    }

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

private struct StationMapRepresentable: UIViewRepresentable {
    @Binding var stations: [FuelStation]
    @Binding var selectedStation: FuelStation?
    let fuelType: FuelType
    let priceProvider: (FuelStation) -> Double?
    let onRegionChange: (MKCoordinateRegion) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.pointOfInterestFilter = .excludingAll
        mapView.register(MKAnnotationView.self, forAnnotationViewWithReuseIdentifier: StationAnnotationView.reuseIdentifier)
        setupControls(in: mapView)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.priceProvider = priceProvider
        context.coordinator.fuelType = fuelType
        context.coordinator.selectedStation = $selectedStation
        updateAnnotations(on: mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onRegionChange: onRegionChange)
    }

    private func updateAnnotations(on mapView: MKMapView) {
        let existing = mapView.annotations.compactMap { $0 as? StationAnnotation }
        let existingIds = Set(existing.map { $0.station.id })
        let newIds = Set(stations.map { $0.id })

        if existingIds != newIds {
            mapView.removeAnnotations(existing)
            let annotations = stations.map { StationAnnotation(station: $0) }
            mapView.addAnnotations(annotations)
        }
    }

    private func setupControls(in mapView: MKMapView) {
        let trackingButton = MKUserTrackingButton(mapView: mapView)
        trackingButton.translatesAutoresizingMaskIntoConstraints = false

        let compass = MKCompassButton(mapView: mapView)
        compass.translatesAutoresizingMaskIntoConstraints = false

        let scale = MKScaleView(mapView: mapView)
        scale.translatesAutoresizingMaskIntoConstraints = false
        scale.scaleVisibility = .visible

        mapView.addSubview(trackingButton)
        mapView.addSubview(compass)
        mapView.addSubview(scale)

        NSLayoutConstraint.activate([
            trackingButton.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -16),
            trackingButton.bottomAnchor.constraint(equalTo: mapView.bottomAnchor, constant: -28),
            compass.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -16),
            compass.topAnchor.constraint(equalTo: mapView.topAnchor, constant: 16),
            scale.leadingAnchor.constraint(equalTo: mapView.leadingAnchor, constant: 16),
            scale.bottomAnchor.constraint(equalTo: mapView.bottomAnchor, constant: -20)
        ])
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onRegionChange: (MKCoordinateRegion) -> Void
        var priceProvider: (FuelStation) -> Double? = { _ in nil }
        var fuelType: FuelType = .gazole
        var selectedStation: Binding<FuelStation?> = .constant(nil)

        init(onRegionChange: @escaping (MKCoordinateRegion) -> Void) {
            self.onRegionChange = onRegionChange
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            onRegionChange(mapView.region)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }

            guard let stationAnnotation = annotation as? StationAnnotation else {
                return nil
            }

            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: StationAnnotationView.reuseIdentifier,
                for: annotation
            )
            view.annotation = stationAnnotation
            view.canShowCallout = false

            let price = priceProvider(stationAnnotation.station)
            view.contentConfiguration = UIHostingConfiguration {
                PriceBadge(price: price, fuelType: fuelType)
                    .shadow(radius: 2)
            }
            view.backgroundColor = .clear
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let station = (view.annotation as? StationAnnotation)?.station else { return }
            selectedStation.wrappedValue = station
        }
    }
}

private final class StationAnnotation: NSObject, MKAnnotation {
    let station: FuelStation

    init(station: FuelStation) {
        self.station = station
        super.init()
    }

    var coordinate: CLLocationCoordinate2D {
        station.coordinate
    }

    var title: String? {
        station.city ?? "Station"
    }
}

private enum StationAnnotationView {
    static let reuseIdentifier = "StationAnnotationView"
}

#Preview {
    MapView(viewModel: .preview())
}
