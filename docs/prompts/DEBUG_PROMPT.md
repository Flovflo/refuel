# Codex Debug Prompt

**Context**: 
The app runs but fails to get location, showing `kCLErrorDomain error 1` (Denied). 
We have already updated `Info.plist` (via build settings) to include the usage description.

**Problem**: 
`LocationManager.swift` attempts to fetch location but **never calls `requestWhenInUseAuthorization()`**. This causes an immediate denial.

**Objective**:
Fix `LocationManager.swift` to correctly request authorization before implementing the location fetch.

**Instructions**:
1.  **Modify `LocationManager.swift`**:
    -   In `init()` or `getCurrentLocation()`, check `manager.authorizationStatus`.
    -   If not determined, call `manager.requestWhenInUseAuthorization()`.
    -   Ensure `getCurrentLocation` handles the delegate callback for authorization changes if needed, or simply requesting it once at init might be enough for this simple app (but better to handle it properly).
    -   **Important**: `requestLocation()` fails immediately if executed before authorization. You might need to wait for authorization? 
    -   *Simpler Fix*: Just add `manager.requestWhenInUseAuthorization()` in `init()`. And ensure `getCurrentLocation` doesn't crash if called too early.

2.  **Verify**:
    -   Run `xcodebuild test` to ensure no regressions.
