//
//  PriceBadge.swift
//  refuel
//
//  Created by Codex on 2026-01-18.
//

import SwiftUI

struct PriceBadge: View {
    let price: Double?
    let fuelType: FuelType
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: fuelType.icon)
            Text(priceText)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(fuelType.color.opacity(0.6), lineWidth: 1)
                )
        )
        .foregroundStyle(fuelType.color)
    }

    private var priceText: String {
        guard let price else { return "Indispo" }
        return String(format: "%.3f€", price)
    }
}

#Preview {
    VStack(spacing: 12) {
        PriceBadge(price: 1.659, fuelType: .gazole)
        PriceBadge(price: nil, fuelType: .e10)
    }
}
