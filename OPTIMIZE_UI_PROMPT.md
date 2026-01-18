# Codex Prompt: Fix Frozen UI & Limit Stations

**Critical Issues**:
1. **App Freeze**: The user says the app is "frozen like an image". This is caused by `StationsViewModel` (which is `@MainActor`) performing distance calculations and sorting for **~10,000 stations** directly on the Main Thread.
2. **Too Many Results**: The user explicitly requested to **limit the list to 10 stations maximum**.

**Tasks**:

## 1. Optimize `StationsViewModel.swift`
- **Move Sorting Off Main Thread**:
    - Create a **non-isolated** static helper method (or separate service method) to perform the filtering and sorting.
    - `StationsViewModel.loadStations` should call this helper in a `Task.detached` or background context, and ONLY update the `@Published stations` property on the Main Thread at the end.
- **Implement Limit**:
    - Hard limit the final `stations` array to **prefix(10)**.

```swift
// Example approach:

// 1. Define a struct or non-isolated helper for processing
struct StationSorter {
    static func process(stations: [FuelStation], location: CLLocation?, fuelType: FuelType) -> [FuelStation] {
        // ... Calculate distances ...
        // ... Sort ...
        // ... Filter ...
        // ... RETURN ONLY 10 ITEMS ...
        return Array(result.prefix(10))
    }
}

// 2. In ViewModel (MainActor)
func loadStations() async {
    state = .loading
    // ... fetch data ...
    
    // OFF-LOAD TO BACKGROUND
    let userLoc = await resolveUserLocation()
    let rawStations = self.cachedStations
    let currentFuel = self.selectedFuelType
    
    let processed = await Task.detached(priority: .userInitiated) {
        return StationSorter.process(stations: rawStations, location: userLoc, fuelType: currentFuel)
    }.value
    
    // UPDATE UI
    self.stations = processed
    state = .idle
}
```

## 2. Verify `StationListView.swift`
- Ensure the `ForEach` loop is lightweight (now that it only has 10 items, it should be fine).
- Ensure `GlassCard` isn't doing anything crazy expensive.

**Goal**:
- **Zero freeze** on load.
- **Max 10 stations** on screen.
- **Fluid scrolling**.
