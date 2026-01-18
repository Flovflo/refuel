# Codex Fix Prompt: Add Files to Project

**Context**: 
The following files were created on disk but are **NOT** in `refuel.xcodeproj`:
- `refuel/Models/UserProfile.swift`
- `refuel/Models/RefillEntry.swift`
- `refuel/Services/PersistenceManager.swift`
- `refuelTests/PersistenceTests.swift`

**Objective**:
Register these files in `refuel.xcodeproj/project.pbxproj` so they are compiled and reachable.

**Instructions**:
1.  **Modify `project.pbxproj`**:
    -   Add file references (PBXFileReference).
    -   Add to groups (PBXGroup):
        -   `UserProfile.swift` and `RefillEntry.swift` -> `Models` group.
        -   `PersistenceManager.swift` -> `Services` group.
        -   `PersistenceTests.swift` -> `refuelTests` group.
    -   Add to build phases (PBXSourcesBuildPhase):
        -   App targets need the Models and Manager.
        -   Test target `refuelTests` needs `PersistenceTests.swift` AND the Models/Manager (if not strictly app-host, but here app-host is used so just app target is fine for models).

2.  **Verify**:
    -   Run `xcodebuild test -project refuel.xcodeproj -scheme refuel -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:refuelTests/PersistenceTests`
    -   It should **PASS** (or at least compile and run the test).
