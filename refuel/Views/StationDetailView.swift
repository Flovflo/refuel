//
//  StationDetailView.swift
//  refuel
//
//  Created by Codex on 2026-01-18.
//

import SwiftUI
import MapKit

struct StationDetailView: View {
    let station: FuelStation
    
    var body: some View {
        let cityName = station.city ?? "Unknown city"
        let addressLine = station.address ?? "Unknown address"
        let postalCode = station.postalCode
        ZStack {
            backgroundView
            ScrollView {
                VStack(spacing: 20) {
                    mapHeader

                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(cityName.capitalized)
                                .font(.title)
                                .bold()

                            Text(addressLine.capitalized)
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 12) {
                                if let postalCode {
                                    Label("CP \(postalCode)", systemImage: "mappin.and.ellipse")
                                }
                                if station.isOpen24h {
                                    Label("24/24", systemImage: "clock.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Carburants")
                            .font(.headline)
                            .padding(.horizontal, 16)

                        ForEach(station.prices) { price in
                            GlassCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(price.fuelType.rawValue)
                                            .font(.headline)
                                        Text(price.lastUpdate.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    PriceBadge(price: price.price, fuelType: price.fuelType)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    if !station.services.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Services")
                                .font(.headline)
                                .padding(.horizontal, 16)

                            GlassCard {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                                    ForEach(station.services, id: \.self) { service in
                                        Text(service)
                                            .font(.caption)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            .background(.ultraThinMaterial, in: Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    Spacer(minLength: 24)
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(cityName.capitalized)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var mapHeader: some View {
        ZStack(alignment: .bottomLeading) {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: station.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
            ))) {
                Marker(station.city ?? "Station", coordinate: station.coordinate)
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            GlassCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text((station.city ?? "Unknown city").capitalized)
                        .font(.headline)
                    if let distance = station.distanceKm {
                        Label(String(format: "%.1f km", distance), systemImage: "location.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
        }
        .padding(.horizontal, 16)
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color.blue.opacity(0.18),
                Color.orange.opacity(0.12),
                Color.cyan.opacity(0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    StationDetailView(station: StationsViewModel.previewStations.first!)
}
