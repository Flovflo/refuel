//
//  StationMiniCard.swift
//  refuel
//
//  Created by Codex on 2026-01-21.
//

import SwiftUI

struct StationMiniCard: View {
    let station: FuelStation
    let fuelType: FuelType

    var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text((station.city ?? "Unknown city").capitalized)
                    .font(.headline)

                Text((station.address ?? "Unknown address").capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let price = station.prices.first(where: { $0.fuelType == fuelType })?.price {
                    HStack(spacing: 6) {
                        Image(systemName: fuelType.icon)
                        Text(String(format: "%.3f €/L", price))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(fuelType.color)
                }

                if let distance = station.distanceKm {
                    Label(String(format: "%.1f km", distance), systemImage: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    StationMiniCard(station: StationsViewModel.previewStations.first!, fuelType: .gazole)
        .padding()
}
