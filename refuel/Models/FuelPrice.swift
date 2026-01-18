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
    
    // Custom coding keys to exclude ID if we don't want to encode it, 
    // or we can rely on default if needed. 
    // For now, default synthesis is fine, but typically we decode from API where ID isn't present.
    // We'll init manually from XML.
    
    init(fuelType: FuelType, price: Double, lastUpdate: Date) {
        self.fuelType = fuelType
        self.price = price
        self.lastUpdate = lastUpdate
    }
}
