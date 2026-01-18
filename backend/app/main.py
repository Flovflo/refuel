from fastapi import FastAPI

from app.importer import download_and_import
from app.routers.stations import router as stations_router

app = FastAPI()
app.include_router(stations_router)


@app.get("/health")
async def health_check() -> dict:
    return {"status": "ok"}


@app.on_event("startup")
async def startup_event() -> None:
    await download_and_import()
