# Codex Prompt: Fix UI Freeze (Background Sorting)

**Context**:
The app fetches 9933 stations. The UI currently uses a native `List` and `Picker`.
**Problem**: After loading stations, the app becomes unresponsive ("buttons don't work"). This is because `StationsViewModel` (MainActor) calculates distances and sorts all 9933 stations **on the main thread**.

**Task**:
Refactor `StationsViewModel.swift` to:
1.  **Keep `fetchStations` as is** (fetching all stations).
2.  **Move the sorting/filtering logic** (distance calc + sort) into a **background task** (`Task.detached`).
3.  **Only update the `@Published stations`** property on the Main Thread once processing is done.

**Constraints**:
- **DO NOT** change `StationListView.swift` (Keep native UI).
- **DO NOT** filter during download (keep fetch as is).
- **DO** use `Task.detached` for the heavy lifting of `sortStations` or equivalent logic.

**Implementation Details**:
- In `loadStations()`:
  - Fetch data.
  - Call a `nonisolated` helper or static method to process the array.
  - Update `self.stations = result` back on MainActor.
