//
//  StationDetailView.swift
//  refuel
//
//  Created by Codex on 2026-01-18.
//

import SwiftUI
import MapKit

struct StationDetailView: View {
    @State private var viewModel: StationDetailViewModel

    @MainActor
    init(station: FuelStation) {
        _viewModel = State(initialValue: StationDetailViewModel(station: station))
    }

    private var station: FuelStation { viewModel.station }

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

                    if let analysis = viewModel.primaryAnalysis {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Analyse Prix")
                                        .font(.headline)
                                    Spacer()
                                    PriceLevelBadge(level: analysis.priceLevel)
                                }

                                PriceTrendChart(analysis: analysis)

                                HStack {
                                    Text("Tendance: \(trendLabel(for: analysis.trend))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(String(format: "Actuel %.3f €/L", analysis.currentPrice))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    } else if case .loading = viewModel.state {
                        ProgressView("Analyse des prix...")
                    } else if case .error(let message) = viewModel.state {
                        ContentUnavailableView("Analyse indisponible", systemImage: "exclamationmark.triangle.fill", description: Text(message))
                    }

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

                                    VStack(alignment: .trailing, spacing: 6) {
                                        PriceBadge(price: price.price, fuelType: price.fuelType)
                                        if let analysis = viewModel.analysisByFuelType[price.fuelType] {
                                            PriceLevelBadge(level: analysis.priceLevel)
                                        }
                                    }
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
        .task {
            if !isPreview {
                await viewModel.load()
            }
        }
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

    private func trendLabel(for trend: String) -> String {
        switch trend {
        case "increasing":
            return "en hausse"
        case "decreasing":
            return "en baisse"
        default:
            return "stable"
        }
    }

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

struct PriceTrendChart: View {
    let analysis: PriceAnalysis

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let range = max(analysis.max30Days - analysis.min30Days, 0.001)
            let currentRatio = (analysis.currentPrice - analysis.min30Days) / range
            let currentX = max(0, min(width, width * currentRatio))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 6)

                Capsule()
                    .fill(analysis.priceLevel.color)
                    .frame(width: max(10, currentX), height: 6)

                Circle()
                    .fill(analysis.priceLevel.color)
                    .frame(width: 12, height: 12)
                    .offset(x: currentX - 6)
            }
        }
        .frame(height: 16)
    }
}

#Preview {
    StationDetailView(station: StationsViewModel.previewStations.first!)
}
