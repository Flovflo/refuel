# Codex Prompt: Fix Predicate & Enhance Onboarding

**Context**: 
1.  **Crash**: The user encountered a crash during SwiftData execution: `Unsupported Predicate: Captured/constant values of type 'FuelPrice' are not supported`. This is likely happening in `PersistenceManager` (or `PersistenceTests`) where we try to look up existing history. We cannot use complex structs (like `FuelPrice`) inside a `#Predicate`.
2.  **New Requirements**: The user wants to capture more info during onboarding.

**Tasks**:

1.  **Fix SwiftData Predicate (`PersistenceManager.swift`)**:
    -   Locate where `#Predicate` is used (likely `recordPriceHistory`).
    -   **Problem**: Accessing properties of a captured struct (e.g., `someFuelPrice.fuelType`) inside the macro is forbidden.
    -   **Fix**: Extract the primitive values **before** the predicate.
    -   *Example*:
        ```swift
        // BAD
        #Predicate<StationPriceHistory> { $0.fuelType == price.fuelType }
        
        // GOOD
        let targetType = price.fuelType // Extract unique value (Enum is fine if Codable, but relying on RawValue is safer if issues persist)
        #Predicate<StationPriceHistory> { $0.fuelType == targetType }
        ```
    -   *Observation*: The log mentions `Captured/constant values of type 'FuelPrice'`. Verify specifically that `FuelPrice` is not passed into the closure.

2.  **Update `UserProfile` Model**:
    -   Add `lastRefillDate: Date?`
    -   Add `refillFrequencyDays: Int?` (e.g. 7 for weekly, 14 for bi-weekly).

3.  **Update `OnboardingView` & `ViewModel`**:
    -   Add a **New Step** (or add to Step 1/2):
        -   **"Last Refill"**: `DatePicker` (displayed as "When was your last full tank?").
        -   **"Refill Frequency"**: A Picker or Stepper "How often do you refill?" (Options: "Every week", "Every 2 weeks", "Once a month", etc., mapping to days: 7, 14, 30).
    -   Update `createProfile` signature in `PersistenceManager` to accept these new arguments.

4.  **Verification**:
    -   Run `PersistenceTests`.
    -   Run `OnboardingTests` (or verify via `xcodebuild build` if tests are incomplete).
