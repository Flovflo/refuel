# Codex Prompt: Import Historical Fuel Data

**Goal**: Populate the `price_history` table with data from 2025 and 2026.

**Context**:
- **Dataset URLs**:
    - 2025: `https://donnees.roulez-eco.fr/opendata/annee/2025`
    - 2026: `https://donnees.roulez-eco.fr/opendata/annee/2026`
- **Existing Code**:
    - `app/models.py`: Defines `PriceHistory`.
    - `app/importer.py`: Defines logic for "Instantaneous" import.

**Task**:
1.  **Update `app/models.py`**:
    - Add a `UniqueConstraint` on `PriceHistory` for columns `(station_id, fuel_type, update_date)` to prevent duplicates.

2.  **Create `app/history_importer.py`**:
    - Implement a script/module to download and import historical data.
    - **Function**: `import_history(years=[2025, 2026])`.
    - **Logic**:
        - Download ZIP for each year.
        - Unzip and stream parse the XML (it may be large, so use `etree.iterparse` similar to `importer.py`).
        - **Upsert Stations**: Ensure stations exist.
        - **Insert Prices**: Batch insert into `PriceHistory`.
        - **Conflict Handling**: Use `ON CONFLICT DO NOTHING` for the `PriceHistory` inserts (using the new UniqueConstraint).
    - **Logging**: Log progress (e.g., "Processed 10,000 prices...").

**Execution**:
- Ensure the script can be run directly (e.g. `if __name__ == "__main__": asyncio.run(import_history())`).

**Output**:
Modify `app/models.py` and create `app/history_importer.py`.
