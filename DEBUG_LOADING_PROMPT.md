# Codex Prompt: Debug Infinite Loading & Add Logging

**Context**: 
1.  **Issue**: The user reports the app is "stuck searching" (infinite loading loop) and "no logs are visible".
2.  **Hypothesis**: The `StationsViewModel` sets `state = .loading` but might not always transition back to `.idle` or `.error` if an async task hangs or fails silently.
3.  **Missing Logs**: We are currently relying on `print()`, which might be filtered. We should use `OSLog` (Logger).

**Tasks**:

1.  **Add `Logger` Infrastructure**:
    -   Import `OSLog`.
    -   Create a static `Logger` extension (e.g., `Logger.refuel`, `Logger.network`, `Logger.persistence`).

2.  **Instrument `StationsViewModel.swift`**:
    -   Log entry/exit of `loadStations` and `search(city:)`.
    -   Log the result count of `fetchStationsSorted`.
    -   **Critical**: Ensure `state = .idle` or `.error` is set in a `defer` block or `ensure` block to guarantee the spinner stops.
    -   Log specific errors in the `catch` blocks using `logger.error(...)`.

3.  **Instrument `FuelDataService.swift`**:
    -   Log "Downloading URL..."
    -   Log "Download complete, size: X bytes"
    -   Log "Unzipping..."
    -   Log "Parsing XML..."
    -   Log "Fetch complete, found X stations".
    -   Use `Logger` so these show up in the Mac Console / Xcode output reliably.

4.  **Instrument `LocationManager.swift`**:
    -   Log "Requesting location..."
    -   Log "Location received: \(loc)" vs "Location error".
    -   **Fix**: Ensure `continuation.resume` is called exactly once (check for existing bugs where it might hang).

5.  **Output**:
    -   Swift code changes only. No architectural changes, just instrumentation and safety guards for state.
