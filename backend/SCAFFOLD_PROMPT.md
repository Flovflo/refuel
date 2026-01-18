# Codex Prompt: Scaffold FastAPI Backend

**Goal**: Transform the current `/API` directory into a robust **FastAPI + PostgreSQL** application running on **Docker**.

**Context**:
- We have existing scripts (`find_stations.py`) but we want a proper API server.
- The server must fetch fuel data from `https://donnees.roulez-eco.fr/opendata/instantane` periodically.

**Task**:
Generate the following files for a production-ready setup:

1.  **`requirements.txt`**:
    - `fastapi`, `uvicorn[standard]`, `sqlalchemy`, `asyncpg`, `alembic`, `geoalchemy2` (for PostGIS), `requests`, `apscheduler`, `lxml` (for parsing).

2.  **`Dockerfile`**:
    - Python 3.11-slim
    - Install system dependencies for PostGIS/GeoAlchemy if needed (`libpq-dev`, `gcc`).
    - Copy code and install requirements.

3.  **`docker-compose.yml`**:
    - **db**: `postgis/postgis:15-3.3` (PostgreSQL with GIS extensions pre-installed).
        - Environment: `POSTGRES_USER=refuel`, `POSTGRES_PASSWORD=refuel`, `POSTGRES_DB=refuel_db`.
        - Local volume for persistence.
    - **api**: Builds from `.`.
        - Links to `db`.
        - Ports: `8000:8000`.
        - Environment: `DATABASE_URL=postgresql+asyncpg://refuel:refuel@db/refuel_db`.

4.  **`app/main.py`**:
    - Basic FastAPI app setup.
    - Include a test endpoint `GET /health` returning `{"status": "ok"}`.

5.  **`app/config.py`**:
    - Use `pydantic-settings` to manage env vars (Database URL, API Keys).

**Output**:
Write these files directly.
