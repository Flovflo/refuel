# Codex Prompt: Database Models & Importer

**Goal**: Implement the database schema and the XML importer logic.

**Context**:
- We have a running FastAPI app + PostGIS db.
- We need to store Fuel Stations and Price History.

**Task**:
1.  **`app/models.py`**:
    - `FuelStation`: id (string, PK), lat/lon (Geometry), address, city, cp.
    - `Price`: id (int, PK), station_id (FK), fuel_type (enum), price (float), update_date (datetime).
    - `PriceHistory`: Same as price but for historical logging.

2.  **`app/importer.py`**:
    - `download_and_import()` function.
    - detailed steps:
        - Download `instantane.zip`.
        - Unzip in memory or temp.
        - Parse XML (iteratively using `lxml` or `xml.etree` for speed).
        - **Upsert** stations (INSERT/UPDATE).
        - **Insert** prices if changed.

3.  **`app/main.py` update**:
    - Add a startup event to trigger the importer (or use APScheduler).

**Note**: Use `geoalchemy2` for the `geometry(Point, 4326)` column in `FuelStation`.

**Output**:
Write `app/models.py`, `app/importer.py`, `app/database.py`, and update `app/main.py`.
