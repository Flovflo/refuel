# Codex Prompt: Fix iOS JSON Decoding

**Goal**: Fix the `DecodingError` ("The data couldn’t be read because it isn’t in the correct format").

**Diagnosis**:
1.  **Date Format**: The backend returns ISO strings *without timezone* (e.g., `"2026-01-14T07:45:22"`). The current `JSONDecoder.dateDecodingStrategy = .iso8601` fails on this.
    - **Fix**: In `FuelDataService.swift`, use a custom `DateFormatter` with format `"yyyy-MM-dd'T'HH:mm:ss"`.
2.  **Nullability**: The backend may return `null` for `address`, `city`, or `cp`.
    - **Fix**: In `FuelStation.swift`, change `address`, `city`, and `postalCode` from `String` to `String?` (Optional). Update `init(from decoder:)` to use `decodeIfPresent` for them.

**Task**:
1.  **Refactor `FuelStation.swift`**:
    - Make `address`, `city`, `postalCode` optional.
    - Update `init(from:)`.
2.  **Refactor `FuelDataService.swift`**:
    - Change `decoder.dateDecodingStrategy` to use a formatter that handles the backend's date format.
3.  **Check `FuelType`**:
    - Ensure `FuelType` enum (wherever it is defined) matches the backend strings: "Gazole", "SP95", "SP98", "E10", "E85", "GPLc".

**Output**:
Modify the files directly.
