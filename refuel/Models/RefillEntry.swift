//
//  RefillEntry.swift
//  refuel
//
//  Created by Codex on 2026-01-20.
//

import Foundation
import SwiftData

@Model
final class RefillEntry {
    var date: Date
    var pricePerLiter: Double
    var amount: Double
    var totalCost: Double
    var stationID: String
    var kilometerCount: Int?
    var profile: UserProfile?

    init(
        date: Date = Date(),
        pricePerLiter: Double,
        amount: Double,
        totalCost: Double,
        stationID: String,
        kilometerCount: Int? = nil,
        profile: UserProfile? = nil
    ) {
        self.date = date
        self.pricePerLiter = pricePerLiter
        self.amount = amount
        self.totalCost = totalCost
        self.stationID = stationID
        self.kilometerCount = kilometerCount
        self.profile = profile
    }
}
