//
//  PriceLevelBadge.swift
//  refuel
//
//  Created by Codex on 2026-01-21.
//

import SwiftUI

struct PriceLevelBadge: View {
    let level: PriceLevel

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: level.icon)
                .font(.caption)
            Text(level.badgeLabel)
                .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().stroke(level.color.opacity(0.7), lineWidth: 1))
        )
        .foregroundStyle(level.color)
        .accessibilityLabel(level.label)
    }
}

private extension PriceLevel {
    var icon: String {
        switch self {
        case .low:
            return "flame.fill"
        case .average:
            return "equal.circle.fill"
        case .high:
            return "exclamationmark.triangle.fill"
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        PriceLevelBadge(level: .low)
        PriceLevelBadge(level: .average)
        PriceLevelBadge(level: .high)
    }
    .padding()
}
