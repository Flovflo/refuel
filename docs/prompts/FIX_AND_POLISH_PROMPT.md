# Codex Prompt: Fix Crash & Polish Repository

**Context**: 
1.  **URGENT CRASH**: The app crashes on launch in the Simulator (Codex environment). This is due to `fatalError` in `PersistenceManager` when the container fails to initialize (likely directory or schema mismatch issues).
2.  **User Request**: "Make a beautiful, clean, quality GitHub repo".

**Tasks**:

1.  **Fix `refuelApp.swift`**:
    -   Use `PersistenceManager.shared` instead of creating a new instance.
    -   Code: `private let persistenceManager = PersistenceManager.shared`

2.  **Make `PersistenceManager` Failsafe**:
    -   In `init`, **REMOVE `fatalError`**.
    -   If standard container creation fails, **fallback to an in-memory container** and log the error.
    -   This ensures the app *always* launches, even if persistence is broken (better than crashing).
    -   *Logic*:
        ```swift
        do {
            container = try ModelContainer(...)
        } catch {
            print("CRITICAL: Failed to create persistent container, falling back to in-memory. Error: \(error)")
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: schema, configurations: [config])
        }
        ```

3.  **Project Polish (GitHub Ready)**:
    -   **Create `README.md`**:
        -   Title: "REFUEL - Smart Fuel Advisor"
        -   Badges: iOS 17+, SwiftUI, SwiftData.
        -   Description: "Intelligent fuel station finder and consumption advisor for iOS. Helps users find the cheapest fuel and optimize their refill timing."
        -   Features List: Real-time government price data, Smart consumption tracking, City search, Offline support (SwiftData).
        -   Setup: `open refuel.xcodeproj`.
    -   **Cleanup**:
        -   Create a directory `docs/prompts`.
        -   Move all `*_PROMPT.md` files into `docs/prompts/`.
        -   Update `.gitignore` to ignore `docs/prompts` if desired (or keep them as documentation). User said "clean", so moving them is good.

4.  **Verification**:
    -   Run `xcodebuild build` to ensure no paths broke.
    -   Run `PersistenceTests` one last time.
