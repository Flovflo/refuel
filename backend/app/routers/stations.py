from __future__ import annotations

from collections.abc import Sequence

from fastapi import APIRouter, Depends
from geoalchemy2 import Geography, Geometry
from sqlalchemy import cast, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
from app.models import FuelStation, FuelType, Price
from app.schemas import PriceResponse, StationResponse

router = APIRouter()


@router.get("/stations", response_model=list[StationResponse])
async def list_stations(
    lat: float,
    lon: float,
    radius: float = 10.0,
    fuel_type: FuelType | None = None,
    session: AsyncSession = Depends(get_session),
) -> list[StationResponse]:
    radius_meters = radius * 1000.0
    point = func.ST_SetSRID(func.ST_MakePoint(lon, lat), 4326)
    distance_expr = func.ST_DistanceSphere(FuelStation.location, point)
    dwithin_expr = func.ST_DWithin(
        cast(FuelStation.location, Geography),
        cast(point, Geography),
        radius_meters,
    )

    if fuel_type is not None:
        stmt = (
            select(
                FuelStation, 
                Price, 
                distance_expr.label("distance"),
                func.ST_Y(cast(FuelStation.location, Geometry)).label("latitude"),
                func.ST_X(cast(FuelStation.location, Geometry)).label("longitude")
            )
            .join(Price)
            .where(dwithin_expr, Price.fuel_type == fuel_type)
            .order_by(Price.price.asc())
            .limit(50)
        )
        result = await session.execute(stmt)
        rows: Sequence[tuple[FuelStation, Price, float, float, float]] = result.all()
        return [
            StationResponse(
                id=station.id,
                address=station.address,
                city=station.city,
                cp=station.cp,
                latitude=float(latitude),
                longitude=float(longitude),
                distance=float(distance),
                prices=[
                    PriceResponse(
                        fuel_type=price.fuel_type,
                        price=price.price,
                        update_date=price.update_date,
                    )
                ],
            )
            for station, price, distance, latitude, longitude in rows
        ]

    station_stmt = (
        select(
            FuelStation.id, 
            distance_expr.label("distance"),
            func.ST_Y(cast(FuelStation.location, Geometry)).label("latitude"),
            func.ST_X(cast(FuelStation.location, Geometry)).label("longitude")
        )
        .where(dwithin_expr)
        .order_by(distance_expr.asc())
        .limit(50)
    )
    station_result = await session.execute(station_stmt)
    station_rows = station_result.all()
    if not station_rows:
        return []

    station_ids = [row.id for row in station_rows]
    distances = {row.id: float(row.distance) for row in station_rows}
    coords = {row.id: (float(row.latitude), float(row.longitude)) for row in station_rows}

    stmt = (
        select(FuelStation, Price)
        .outerjoin(Price)
        .where(FuelStation.id.in_(station_ids))
    )
    result = await session.execute(stmt)
    rows: Sequence[tuple[FuelStation, Price | None]] = result.all()

    stations: dict[str, StationResponse] = {}
    for station, price in rows:
        entry = stations.get(station.id)
        if entry is None:
            lat, lon = coords.get(station.id, (0.0, 0.0))
            entry = StationResponse(
                id=station.id,
                address=station.address,
                city=station.city,
                cp=station.cp,
                latitude=lat,
                longitude=lon,
                distance=distances.get(station.id, 0.0),
                prices=[],
            )
            stations[station.id] = entry
        if price is not None:
            entry.prices.append(
                PriceResponse(
                    fuel_type=price.fuel_type,
                    price=price.price,
                    update_date=price.update_date,
                )
            )

    return [stations[station_id] for station_id in station_ids if station_id in stations]
