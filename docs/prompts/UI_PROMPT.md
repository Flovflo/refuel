# Codex UI Prompt

**Context**: 
- `AGENTS.md` is the strict project constitution.
- `Models` and `Services` are **ALREADY IMPLEMENTED AND TESTED**. Do not modify them unless necessary for the UI.

**Objective**:
Implement the **UI Layer** for the REFUEL app using SwiftUI and the "LiquidGlass" design system detailed in `AGENTS.md`.

**Tasks**:

1.  **ViewModel**:
    -   Update/Create `StationsViewModel.swift`. Ensure it exposes `stations` and handles loading/error states from `FuelDataService`.

2.  **Components**:
    -   `Components/GlassCard.swift`: Reusable background with `.ultraThinMaterial`.
    -   `Components/PriceBadge.swift`: Visual badge for fuel prices.

3.  **Views**:
    -   `Views/StationListView.swift`: Main list of stations. Use `GlassCard`.
    -   `Views/StationDetailView.swift`: Detailed view with Map + Prices + Services.
    -   `Views/MapView.swift`: Map integration showing station markers.

4.  **Entry Point**:
    -   Update `ContentView.swift` to include `StationListView` (wrapped in a TabView if desired, or just the main nav).

**Verification**:
-   After creating files, run `xcodebuild -scheme refuel -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` to ensure no compile errors.
