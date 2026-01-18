# Codex Feature Prompt: City Search

**Context**: 
The app runs, but in the Simulator (defaulting to Cupertino), no French fuel stations are found. 
To fix this and improve usability, the user wants to **search by City Name** manually.

**Objective**:
Implement a "Search by City" feature.

**Tasks**:

1.  **Logic (`StationsViewModel.swift` & `LocationManager.swift`)**:
    -   Add a function to geocode a city name string into coordinates (e.g., `func geocode(city: String) async throws -> CLLocationCoordinate2D`). You can use `CLGeocoder`.
    -   Update `StationsViewModel`:
        -   Add a `search(city: String)` function.
        -   When called, it should geocode the city, update the "current location" reference (or just use the result for sorting/fetching), and reload stations.

2.  **UI (`StationListView.swift`)**:
    -   Add `.searchable(text: $searchText)` to the `NavigationStack`.
    -   Trigger the search logic when the user submits the search.

3.  **Constraints**:
    -   Keep complying with `AGENTS.md` (LiquidGlass, MVVM, async/await).
    -   **Strict Concurrency**: Ensure `CLGeocoder` usage doesn't break MainActor rules (it's non-sendable usually, handle with care).

4.  **Verification**:
    -   Create a Unit Test `testGeocoding()` in `ServicesTests.swift` that mocks or tests `CLGeocoder` (note: CLGeocoder requires network, might be flaky in CI, but fine for local Codex run).
    -   Run `xcodebuild test` to confirm nothing broke.
