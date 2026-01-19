from __future__ import annotations

from collections.abc import Sequence
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends
from geoalchemy2 import Geography, Geometry
from sqlalchemy import cast, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
from app.models import FuelStation, FuelType, Price, PriceHistory
from app.schemas import PriceAnalysisResponse, PriceResponse, StationResponse

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


@router.get("/stations/{station_id}/price-analysis", response_model=PriceAnalysisResponse)
async def get_price_analysis(
    station_id: str,
    fuel_type: FuelType = FuelType.GAZOLE,
    session: AsyncSession = Depends(get_session),
) -> PriceAnalysisResponse:
    current_stmt = select(Price).where(
        Price.station_id == station_id,
        Price.fuel_type == fuel_type,
    )
    current_result = await session.execute(current_stmt)
    current_price = current_result.scalar_one_or_none()
    if current_price is None:
        return {
            "station_id": station_id,
            "fuel_type": fuel_type,
            "current_price": 0.0,
            "avg_30_days": 0.0,
            "min_30_days": 0.0,
            "max_30_days": 0.0,
            "percentile": 0,
            "trend": "stable",
        }

    thirty_days_ago = datetime.utcnow() - timedelta(days=30)
    history_stmt = (
        select(PriceHistory)
        .where(
            PriceHistory.station_id == station_id,
            PriceHistory.fuel_type == fuel_type,
            PriceHistory.update_date >= thirty_days_ago,
        )
        .order_by(PriceHistory.update_date.asc())
    )
    history_result = await session.execute(history_stmt)
    history_entries = history_result.scalars().all()

    history_prices = [entry.price for entry in history_entries]
    if not history_prices:
        return {
            "station_id": station_id,
            "fuel_type": fuel_type,
            "current_price": float(current_price.price),
            "avg_30_days": float(current_price.price),
            "min_30_days": float(current_price.price),
            "max_30_days": float(current_price.price),
            "percentile": 50,
            "trend": "stable",
        }

    avg_price = sum(history_prices) / len(history_prices)
    min_price = min(history_prices)
    max_price = max(history_prices)

    sorted_prices = sorted(history_prices)
    percentile = int(
        sum(1 for price in sorted_prices if price <= current_price.price)
        / len(sorted_prices)
        * 100
    )

    trend = "stable"
    if len(history_prices) >= 4:
        midpoint = len(history_prices) // 2
        first_half = history_prices[:midpoint]
        second_half = history_prices[midpoint:]
        first_avg = sum(first_half) / len(first_half)
        second_avg = sum(second_half) / len(second_half)
        delta = second_avg - first_avg
        threshold = max(0.002, first_avg * 0.005)
        if delta > threshold:
            trend = "increasing"
        elif delta < -threshold:
            trend = "decreasing"

    return {
        "station_id": station_id,
        "fuel_type": fuel_type,
        "current_price": float(current_price.price),
        "avg_30_days": round(avg_price, 3),
        "min_30_days": float(min_price),
        "max_30_days": float(max_price),
        "percentile": percentile,
        "trend": trend,
    }


@router.get("/stations/{station_id}/price-history")
async def get_price_history(
    station_id: str,
    fuel_type: FuelType = FuelType.GAZOLE,
    session: AsyncSession = Depends(get_session),
) -> dict:
    """Get 30 days of price history for charting."""
    thirty_days_ago = datetime.utcnow() - timedelta(days=30)
    history_stmt = (
        select(PriceHistory)
        .where(
            PriceHistory.station_id == station_id,
            PriceHistory.fuel_type == fuel_type,
            PriceHistory.update_date >= thirty_days_ago,
        )
        .order_by(PriceHistory.update_date.asc())
    )
    history_result = await session.execute(history_stmt)
    history_entries = history_result.scalars().all()

    history = [
        {
            "date": entry.update_date.strftime("%Y-%m-%d"),
            "price": float(entry.price),
        }
        for entry in history_entries
    ]

    return {
        "station_id": station_id,
        "fuel_type": fuel_type.value,
        "history": history,
    }

