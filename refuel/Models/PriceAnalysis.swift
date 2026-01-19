//
//  PriceAnalysis.swift
//  refuel
//
//  Created by Codex on 2026-01-21.
//

import SwiftUI

struct PriceAnalysis: Codable, Identifiable {
    let stationId: String
    let fuelType: FuelType
    let currentPrice: Double
    let avg30Days: Double
    let min30Days: Double
    let max30Days: Double
    let percentile: Int
    let trend: String

    var id: String { "\(stationId)-\(fuelType.rawValue)" }

    var priceLevel: PriceLevel {
        if percentile <= 25 { return .low }
        if percentile <= 75 { return .average }
        return .high
    }

    enum CodingKeys: String, CodingKey {
        case stationId = "station_id"
        case fuelType = "fuel_type"
        case currentPrice = "current_price"
        case avg30Days = "avg_30_days"
        case min30Days = "min_30_days"
        case max30Days = "max_30_days"
        case percentile
        case trend
    }
}

enum PriceLevel: String, Codable {
    case low
    case average
    case high

    var color: Color {
        switch self {
        case .low:
            return Color(red: 0.204, green: 0.780, blue: 0.349)
        case .average:
            return Color(red: 1.0, green: 0.584, blue: 0.0)
        case .high:
            return Color(red: 1.0, green: 0.231, blue: 0.188)
        }
    }

    var label: String {
        switch self {
        case .low:
            return "Prix Bas"
        case .average:
            return "Prix Moyen"
        case .high:
            return "Prix Eleve"
        }
    }

    var badgeLabel: String {
        switch self {
        case .low:
            return "Prix Bas \u{1F525}"
        case .average:
            return "Prix Moyen"
        case .high:
            return "Prix Eleve \u{26A0}\u{FE0F}"
        }
    }
}
