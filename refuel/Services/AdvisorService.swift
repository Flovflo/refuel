//
//  AdvisorService.swift
//  refuel
//
//  Created by Codex on 2026-01-20.
//

import Foundation
import OSLog

@MainActor
final class AdvisorService {
    private let logger = Logger.refuel

    /// Calculate days until next predicted refill.
    func daysUntilRefill(profile: UserProfile) -> Int? {
        guard let lastRefill = profile.lastRefillDate,
              let frequency = profile.refillFrequencyDays else { return nil }
        let nextRefill = Calendar.current.date(byAdding: .day, value: frequency, to: lastRefill) ?? Date()
        let days = Calendar.current.dateComponents([.day], from: Date(), to: nextRefill).day ?? 0
        return max(0, days)
    }

    /// Calculate cost per 100km for a station.
    func costPer100Km(station: FuelStation, fuelType: FuelType, consumption: Double) -> Double? {
        guard let price = station.prices.first(where: { $0.fuelType == fuelType })?.price else { return nil }
        return price * consumption
    }

    /// Generate advice message.
    func advice(profile: UserProfile, cheapestStation: FuelStation?) -> String {
        guard let days = daysUntilRefill(profile: profile) else {
            return "Complete your profile to get personalized advice."
        }
        if days <= 2 {
            if let station = cheapestStation {
                let price = station.prices.first?.price ?? 0
                return "⛽️ Time to refuel! Best price: \(station.city) at \(price)€/L"
            }
            return "⛽️ Time to refuel soon!"
        } else if days <= 5 {
            return "📊 You have about \(days) days until your next refill."
        }
        return "✅ All good! Next refill in ~\(days) days."
    }
}
