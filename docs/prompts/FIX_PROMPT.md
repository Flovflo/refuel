# Codex Fix Prompt

**Context**: 
The project is failing to build due to `MainActor` isolation issues and syntax errors in `StationsViewModel.swift`.

**Current Errors**:

1.  **Syntax Error in `StationsViewModel.swift`**:
    -   around line 49-51: `static func preview` is declared but not closed properly, and it duplicates the one in the extension.
    -   There is a stray comment `// ... (rest of methods)`.

2.  **Concurrency Errors (MainActor)**:
    -   `StationListView.init` and `MapView.init` call `StationsViewModel()` as a default argument. `StationsViewModel.init` uses default arguments `FuelDataService()` and `LocationManager()` which might be actor-isolated or declared in a way that Swift 6 concurrency forbids in a synchronous context.
    -   Error: `call to main actor-isolated initializer 'init(dataService:locationManager:)' in a synchronous nonisolated context`.

**Objective**:
Fix `StationsViewModel.swift`, `StationListView.swift`, and `MapView.swift` to compile cleanly on iOS 26+ (Swift 6 strict concurrency).

**Instructions**:
1.  **Fix `StationsViewModel.swift`**:
    -   Remove the broken `static func preview` code block around line 49.
    -   Ensure `init` is safe to call. Consider making the parameters optional `nil` by default and initializing them inside the body, or keeping the init non-isolated if possible.
    -   Ensure `preview` in the extension is correct.

2.  **Fix `StationListView` and `MapView`**:
    -   Ensure they initialize `StationsViewModel` safely. (e.g., using `State(initialValue: ...)` inside the init body with optional parameters, or passing a pre-initialized model).

3.  **Verify**:
    -   Run `xcodebuild -scheme refuel -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` and ensure it SUCCEEDS.
