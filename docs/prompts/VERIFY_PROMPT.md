# Codex Verification Prompt

**Context**: 
We fixed a "Misaligned Pointer" crash in valid ZIP parsing and stopped the simulator loop.
The app should now be stable.

**Objective**:
Run a FINAL sanity check test to ensure `testRealNetworkFetch` passes without crashing.

**Instructions**:
1.  **Run ONE Specific Test**:
    -   Execute `xcodebuild test -project refuel.xcodeproj -scheme refuel -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:refuelTests/ServicesTests/testRealNetworkFetch`
    -   **DO NOT** run all tests.
    -   **DO NOT** start multiple simulators.
2.  **Report**:
    -   If it passes, we are 100% done.
