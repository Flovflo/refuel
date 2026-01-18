# Codex Prompt: Connect iOS App to Custom Backend

**Goal**: Switch the `refuel` app from parsing local XML to fetching JSON from our new Python backend.

**Context**:
- **New Backend URL**: `http://MacBook-Pro-de-Florian-2.local:8000/stations`
- **Endpoint**: `GET /stations?lat=...&lon=...&radius=...&fuel_type=...`
- **JSON Response**:
    ```json
    [
      {
        "id": "123456",
        "address": "...",
        "city": "...",
        "cp": "...",
        "distance": 1.2,
        "prices": [
           {"fuel_type": "Gazole", "price": 1.7, "update_date": "..."}
        ]
      }
    ]
    ```

**Task**:
1.  **Refactor `FuelStation.swift`**:
    - Update/Add coding keys to match the JSON (`cp` -> `postalCode`).
    - Ensure it decodes correctly.

2.  **Refactor `FuelDataService.swift`**:
    - **Remove** all XML Unzipping/Parsing logic.
    - **Implement** `fetchStations(latitude: Double, longitude: Double, radius: Double) async throws -> [FuelStation]`.
    - Use `URLSession` to call `http://MacBook-Pro-de-Florian-2.local:8000/stations`.
    - Handle decoding.

3.  **Update `StationsViewModel.swift`**:
    - Update `loadStations` to pass the latitude/longitude to `fetchStations`.

**Output**:
Modify the files `refuel/Models/FuelStation.swift`, `refuel/Services/FuelDataService.swift`, and `refuel/ViewModels/StationsViewModel.swift`.
