# Codex Prompt: Phase 1 - Persistence (Smart Advisor)

**Context**: 
We are building the "Smart Advisor" feature on branch `feature/smart-advisor`.
We need to persist the user's car information and habits.

**Objective**:
Implement **SwiftData** persistence for the app.

**Tasks**:

1.  **Create Models (`Models/`)**:
    -   `UserProfile.swift`:
        -   `@Model` class.
        -   Properties: `fuelType: FuelType` (Enum needs to be Codable/Persistable, maybe store as String or Int rawValue if SwiftData struggles with complex enums, but strictly typed accessor is preferred), `tankCapacity: Double` (Liters), `fuelConsumption: Double` (L/100km).
        -   Properties: `homeLatitude: Double?`, `homeLongitude: Double?` (Store coords as primitives, helper for CLLocationCoordinate2D). same for `work`.
        -   Relationship: `refills: [RefillEntry]`
    -   `RefillEntry.swift`:
        -   `@Model` class.
        -   Properties: `date: Date`, `pricePerLiter: Double`, `amount: Double`, `totalCost: Double`, `stationID: String`, `kilometerCount: Int?`.

2.  **Create Manager (`Services/PersistenceManager.swift`)**:
    -   `@MainActor` class.
    -   Initialize `ModelContainer` for `UserProfile` and `RefillEntry`.
    -   Provide methods:
        -   `fetchUserProfile() -> UserProfile?` (Should return the single profile if it exists).
        -   `save()` (autosave context).
        -   `createProfile(fuelType:tankCapacity:consumption:)`

3.  **Update App Interface (`refuelApp.swift`)**:
    -   Inject the `.modelContainer` into the `WindowGroup`.

4.  **Verification**:
    -   Create `Tests/PersistenceTests.swift`.
    -   Test: `testCreateAndFetchProfile()` using an **in-memory** ModelConfiguration.
    -   Run `xcodebuild test -only-testing:refuelTests/PersistenceTests`

**Constraints**:
-   Target iOS 17+.
-   Use `import SwiftData`.
-   Ensure `FuelType` works with SwiftData (might need `Codable` or `@Attribute`).
