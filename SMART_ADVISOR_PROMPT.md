# Codex Prompt: Smart Advisor Integration

**Context**: 
We have collected user data in `UserProfile` (fuel type, home/work coordinates, refill frequency), but `StationsViewModel` is NOT using any of it. The user wants a truly personalized experience.

**Objective**:
Make the app use the user's onboarding data to find the best fuel prices near their HOME and WORK locations, and predict when they should refill.

**Tasks**:

## 1. Update `StationsViewModel.swift`
- **Load User Profile** on init:
    ```swift
    private var userProfile: UserProfile?
    
    init(...) {
        ...
        loadUserProfile()
    }
    
    private func loadUserProfile() {
        self.userProfile = PersistenceManager.shared.fetchUserProfile()
        if let profile = userProfile {
            self.selectedFuelType = profile.fuelType
        }
    }
    ```
- **Use Home/Work Locations**:
    - In `resolveUserLocation()`, instead of ONLY using GPS, also consider:
        - If GPS fails, fallback to `homeLatitude/homeLongitude` from profile.
    - Add a new method `loadStationsNearHome()` and `loadStationsNearWork()` that use profile coordinates.

## 2. Create `AdvisorService.swift` (new file)
Location: `refuel/Services/AdvisorService.swift`

```swift
import Foundation
import OSLog

@MainActor
final class AdvisorService {
    private let logger = Logger.refuel
    
    /// Calculate days until next predicted refill
    func daysUntilRefill(profile: UserProfile) -> Int? {
        guard let lastRefill = profile.lastRefillDate,
              let frequency = profile.refillFrequencyDays else { return nil }
        let nextRefill = Calendar.current.date(byAdding: .day, value: frequency, to: lastRefill) ?? Date()
        let days = Calendar.current.dateComponents([.day], from: Date(), to: nextRefill).day ?? 0
        return max(0, days)
    }
    
    /// Calculate cost per 100km for a station
    func costPer100Km(station: FuelStation, fuelType: FuelType, consumption: Double) -> Double? {
        guard let price = station.prices.first(where: { $0.fuelType == fuelType })?.price else { return nil }
        return price * consumption // consumption is L/100km
    }
    
    /// Generate advice message
    func advice(profile: UserProfile, cheapestStation: FuelStation?) -> String {
        guard let days = daysUntilRefill(profile: profile) else {
            return "Complete your profile to get personalized advice."
        }
        if days <= 2 {
            if let station = cheapestStation {
                return "⛽️ Time to refuel! Best price: \(station.city) at \(station.prices.first?.price ?? 0)€/L"
            }
            return "⛽️ Time to refuel soon!"
        } else if days <= 5 {
            return "📊 You have about \(days) days until your next refill."
        }
        return "✅ All good! Next refill in ~\(days) days."
    }
}
```

## 3. Update UI (`StationListView.swift`)
- Display the `advice` message at the top of the list (e.g., in a GlassCard).
- Show a "Best Deal Near Home" vs "Best Deal Near Work" section if both locations are set.

## 4. Verification
- Run the app.
- Check that the user's preferred fuel type is selected by default.
- Verify the advice message appears.
