//
//  FuelPrice.swift
//  refuel
//
//  Created by Codex on 2026-01-18.
//

import Foundation

struct FuelPrice: Identifiable, Codable {
    var id = UUID()
    let fuelType: FuelType
    let price: Double
    let lastUpdate: Date

    enum CodingKeys: String, CodingKey {
        case fuelType = "fuel_type"
        case price
        case lastUpdate = "update_date"
    }

    init(fuelType: FuelType, price: Double, lastUpdate: Date) {
        self.fuelType = fuelType
        self.price = price
        self.lastUpdate = lastUpdate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fuelType = try container.decode(FuelType.self, forKey: .fuelType)
        price = try container.decode(Double.self, forKey: .price)
        lastUpdate = try container.decode(Date.self, forKey: .lastUpdate)
        id = UUID()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fuelType, forKey: .fuelType)
        try container.encode(price, forKey: .price)
        try container.encode(lastUpdate, forKey: .lastUpdate)
    }
}
