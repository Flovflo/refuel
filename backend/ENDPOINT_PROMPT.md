# Codex Prompt: Implement Search Endpoint

**Goal**: Create the `/stations` API endpoint to search for stations by location.

**Context**:
- Models: `FuelStation`, `Price`.
- Database: PostGIS enabled.
- We need to return the nearby stations sorted by price (best deal).

**Task**:
1.  Create `app/schemas.py`:
    - `StationResponse` (Pydantic model): id, address, city, cp, distance (float), prices (list of PriceResponse).
    - `PriceResponse`: fuel_type, price, update_date.

2.  Create `app/routers/stations.py`:
    - Endpoint: `GET /stations`
    - Params: `lat` (float), `lon` (float), `radius` (float, default 10km), `fuel_type` (optional enum).
    - Logic:
        - Use `func.ST_DWithin` to filter by radius.
        - Use `func.ST_DistanceSphere` (or `ST_Distance` with cast) to calculate distance.
        - Perform a JOIN with `Price` to get the prices.
        - If `fuel_type` is provided, filter prices AND sort by price (cheapest first).
        - Limit results to 50.

3.  Update `app/main.py`:
    - Include the router.

**Output**:
Write `app/schemas.py`, `app/routers/stations.py`, and update `app/main.py`.
