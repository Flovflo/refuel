//
//  FuelStation.swift
//  refuel
//
//  Created by Codex on 2026-01-18.
//

import Foundation
import CoreLocation

struct FuelStation: Identifiable, Codable, Hashable {
    let id: String
    let address: String
    let city: String
    let postalCode: String
    let latitude: Double
    let longitude: Double
    var prices: [FuelPrice]
    var services: [String]
    var isOpen24h: Bool
    
    // Distance from user (calculated at runtime)
    var distanceKm: Double?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var cheapestPrice: Double? {
        prices.map(\.price).min()
    }
    
    var cheapestGazole: Double? {
        prices.first(where: { $0.fuelType == .gazole })?.price
    }
}

extension FuelStation {
    static func == (lhs: FuelStation, rhs: FuelStation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
