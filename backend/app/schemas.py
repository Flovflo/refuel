from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models import FuelType


class PriceResponse(BaseModel):
    fuel_type: FuelType
    price: float
    update_date: datetime

    model_config = ConfigDict(from_attributes=True)


class StationResponse(BaseModel):
    id: str
    address: str | None
    city: str | None
    cp: str | None
    latitude: float
    longitude: float
    distance: float
    prices: list[PriceResponse]

    model_config = ConfigDict(from_attributes=True)


class PriceAnalysisResponse(BaseModel):
    station_id: str
    fuel_type: FuelType
    current_price: float
    avg_30_days: float
    min_30_days: float
    max_30_days: float
    percentile: int
    trend: str
