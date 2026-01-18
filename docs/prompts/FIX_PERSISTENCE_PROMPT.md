# Codex Prompt: Fix Persistence & Add Price History

**Context**: 
1.  **Persistence Crash**: Users report `CoreData: error: ... parent directory path reported as missing`. We need to ensure the persistent store directory exists before initializing `ModelContainer`.
2.  **Price History**: We need to fetch fuel prices for the last 7 days to enable "Smart Advisor" recommendations (e.g. "Price is rising, fill up now!").

**Tasks**:

1.  **Fix `PersistenceManager.swift`**:
    -   In `init`, before creating `ModelContainer`, explicitly check if `URL.applicationSupportDirectory` exists. If not, create it using `FileManager.default.createDirectory`.
    -   This prevents the "parent directory missing" crash on fresh simulators.

2.  **Implement Price History Logic (`FuelDataService`)**:
    -   The API `https://donnees.roulez-eco.fr/opendata/instantane` is a snapshot.
    -   **New Strategy**: To get history, we might need to fetch the "Annual Data" or "Daily Flux" if available, OR simpler: Start tracking history **locally** from today.
    -   *Correction*: The user explicitly asked to "recover data ... back to 1 week". The OpenData platform has "Flux Quotidien" (Daily Flux) at `https://donnees.roulez-eco.fr/opendata/jour`.
    -   **Action**: Add a method `fetchHistory()` that downloads the daily zip, unzips it, and parses it.
    -   *However, for MVP stability*: Let's implement a robust **Local Tracker**. Every time we fetch `Instantane`, we save a `PriceRecord` (new model or just store in RefillEntry relation? No, we need a Station Price History).
    -   *Let's check the API first*: I will stick to fixing the persistence first, and for history, I'll add a `PriceHistory` entity to storing the data locally as we fetch it.

3.  **Update `Models`**:
    -   `@Model class StationPriceHistory`: `stationID`, `date`, `fuelType`, `price`.
    -   Update `FuelStation` (in memory) to hold this history if needed, or just query it.

4.  **Verification**:
    -   Run `PersistenceTests` again (should pass now).
