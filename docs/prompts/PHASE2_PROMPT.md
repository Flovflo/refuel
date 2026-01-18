# Codex Prompt: Phase 2 - Onboarding (Smart Advisor)

**Context**: 
The persistence layer is ready (`PersistenceManager`, `UserProfile`).
We now need to implement the **First Run Experience**.

**Objective**:
Create a "Wizard" style onboarding flow that collects user data and saves it.

**Tasks**:

1.  **Create `Views/Onboarding/OnboardingView.swift`**:
    -   Use a `TabView` with `PageTabViewStyle` or a custom wizard flow.
    -   **Step 1: Vehicle**:
        -   Picker for `FuelType` (Use `FuelType.allCases`).
        -   TextField for `Tank Capacity` (Double).
        -   TextField for `Consumption` (Double).
    -   **Step 2: Locations**:
        -   TextFields for "Home CIty/Address" and "Work City/Address".
        -   *Hint*: Use `LocationManager.geocode(city:)` to convert these to coordinates.
    -   **Step 3: Finish**:
        -   Summary + "Start ReFueling" button.
        -   Action: Call `PersistenceManager.shared.createProfile(...)`.

2.  **Integrate in `ContentView.swift`**:
    -   Check if `UserProfile` exists (fetched from `PersistenceManager`).
    -   If `nil` -> Show `OnboardingView`.
    -   If exists -> Show `StationListView` (the main app).
    -   *Tech Note*: You might need a `@Query` or `@State` in ContentView to observe the profile presence.

3.  **Project Registration**:
    -   **IMPORTANT**: Manually register `OnboardingView.swift` (and any subviews) in `project.pbxproj` (use the same logic as before, find `PBXFileReference` section etc. or assume Xcode 15 sync if working).
    -   *Actually*, just create the file on disk. If `xcodebuild` fails, we will do the manual fix step again.

4.  **Verification**:
    -   Create `refuelTests/OnboardingTests.swift` (or add to `PersistenceTests`).
    -   Test: `testOnboardingCreatesProfile()`.
