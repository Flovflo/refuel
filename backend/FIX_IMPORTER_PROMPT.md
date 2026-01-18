# Codex Prompt: Fix Importer Crash

**Goal**: debug and fix the `app/importer.py` crash on startup.

**Problem**:
The app crashes with `sqlalchemy.exc.StatementError` (gkpj) during `_upsert_stations` or `_upsert_prices` with a huge parameter list in the logs.
This usually means:
1.  **Inconsistent keys** in the list of dicts passed to `.values()`.
2.  **Enum serialization issue** (FuelType).
3.  **Geometry serialization issue** (PostGIS).

**Task**:
Modify `app/importer.py` to:
1.  **Add Logging**: `logging.basicConfig(level=logging.INFO)` in `download_and_import`.
2.  **Fix Geometry**: Ensure `location` in `_station_row_from_element` handles `None` correctly for `geoalchemy2`. 
    - *Hint*: If `location` is `None`, maybe exclude it from the dict? Or ensure `geoalchemy2` handles it.
3.  **Reduce Batch Size**: Change `BATCH_SIZE` to 500.
4.  **Try/Except Blocks**: Wrap `await _upsert_stations(...)` and `await _upsert_prices(...)` in try/except blocks that log the exception details (and maybe the first item of the batch) and **continue** instead of crashing the whole app.
5.  **Sanitize Data**: Ensure `FuelType` is converted to string if SQLAlchemy expects string, or ensure `Native Enum` support is enabled in `models.py`.

**Output**:
Rewrite `app/importer.py` with these fixes.
