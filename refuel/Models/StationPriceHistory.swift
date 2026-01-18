//
//  StationPriceHistory.swift
//  refuel
//
//  Created by Codex on 2026-01-20.
//

import Foundation
import SwiftData

@Model
final class StationPriceHistory {
    var stationID: String
    var date: Date
    var fuelType: FuelType
    var price: Double

    init(stationID: String, date: Date, fuelType: FuelType, price: Double) {
        self.stationID = stationID
        self.date = date
        self.fuelType = fuelType
        self.price = price
    }
}
