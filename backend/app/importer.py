from __future__ import annotations

import asyncio
import io
import logging
import zipfile
from datetime import datetime
from typing import Iterable

import requests
from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert

from app.database import async_session, init_db
from app.models import FuelStation, FuelType, Price, PriceHistory

try:
    from lxml import etree as ET

    _HAS_LXML = True
except ImportError:  # pragma: no cover - lxml is a requirement, but keep a fallback
    import xml.etree.ElementTree as ET

    _HAS_LXML = False


logger = logging.getLogger(__name__)

DOWNLOAD_URL = "https://donnees.roulez-eco.fr/opendata/instantane"
BATCH_SIZE = 500


def _download_zip() -> bytes:
    response = requests.get(DOWNLOAD_URL, timeout=60)
    response.raise_for_status()
    return response.content


def _parse_update_date(value: str | None) -> datetime | None:
    if not value:
        return None
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S"):
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            continue
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


def _iter_pdv(xml_file: io.BufferedReader) -> Iterable[ET.Element]:
    if _HAS_LXML:
        context = ET.iterparse(xml_file, events=("end",), tag="pdv")
    else:
        context = ET.iterparse(xml_file, events=("end",))

    for _, elem in context:
        if elem.tag != "pdv":
            continue
        yield elem
        elem.clear()
        if hasattr(elem, "getprevious"):
            while elem.getprevious() is not None:
                del elem.getparent()[0]


def _station_row_from_element(pdv: ET.Element) -> dict:
    station_id = pdv.get("id")
    cp = pdv.get("cp")
    address = (pdv.findtext("adresse") or "").strip()
    city = (pdv.findtext("ville") or "").strip()
    lat_raw = pdv.get("latitude")
    lon_raw = pdv.get("longitude")

    location = None
    if lat_raw is not None and lon_raw is not None:
        try:
            lat = float(lat_raw) / 100000
            lon = float(lon_raw) / 100000
            if not (lat == 0 and lon == 0):
                # Use WKTElement for batch inserts
                from geoalchemy2.elements import WKTElement
                location = WKTElement(f"POINT({lon} {lat})", srid=4326)
        except ValueError:
            location = None

    return {
        "id": station_id,
        "location": location,
        "address": address,
        "city": city,
        "cp": cp,
    }


def _price_rows_from_element(pdv: ET.Element, station_id: str) -> list[dict]:
    rows: list[dict] = []
    for price_elem in pdv.findall("prix"):
        fuel_name = price_elem.get("nom")
        if not fuel_name:
            continue
        try:
            fuel_type = FuelType(fuel_name)
        except ValueError:
            continue
        value_raw = price_elem.get("valeur")
        if not value_raw:
            continue
        try:
            price_value = float(value_raw)
        except ValueError:
            continue
        update_date = _parse_update_date(price_elem.get("maj"))
        if update_date is None:
            continue
        rows.append(
            {
                "station_id": station_id,
                "fuel_type": fuel_type.value,
                "price": price_value,
                "update_date": update_date,
            }
        )
    return rows


async def _load_existing_prices(session) -> dict[tuple[str, str], tuple[float, datetime]]:
    result = await session.execute(
        select(Price.station_id, Price.fuel_type, Price.price, Price.update_date)
    )
    existing: dict[tuple[str, str], tuple[float, datetime]] = {}
    for station_id, fuel_type, price, update_date in result.all():
        fuel_key = fuel_type.value if isinstance(fuel_type, FuelType) else str(fuel_type)
        existing[(station_id, fuel_key)] = (price, update_date)
    return existing


async def _upsert_stations(session, stations: list[dict]) -> None:
    if not stations:
        return
    stmt = insert(FuelStation).values(stations)
    stmt = stmt.on_conflict_do_update(
        index_elements=[FuelStation.id],
        set_={
            "location": stmt.excluded.location,
            "address": stmt.excluded.address,
            "city": stmt.excluded.city,
            "cp": stmt.excluded.cp,
        },
    )
    await session.execute(stmt)


async def _upsert_prices(session, prices: list[dict]) -> None:
    if not prices:
        return
    stmt = insert(Price).values(prices)
    stmt = stmt.on_conflict_do_update(
        index_elements=[Price.station_id, Price.fuel_type],
        set_={
            "price": stmt.excluded.price,
            "update_date": stmt.excluded.update_date,
        },
    )
    await session.execute(stmt)


async def _insert_price_history(session, history_rows: list[dict]) -> None:
    if not history_rows:
        return
    await session.execute(PriceHistory.__table__.insert(), history_rows)


async def download_and_import() -> None:
    logging.basicConfig(level=logging.INFO)
    await init_db()
    logger.info("Downloading fuel price dataset")
    zip_bytes = await asyncio.to_thread(_download_zip)

    async with async_session() as session:
        existing_prices = await _load_existing_prices(session)
        station_rows: list[dict] = []
        price_rows: list[dict] = []
        history_rows: list[dict] = []

        with zipfile.ZipFile(io.BytesIO(zip_bytes)) as zf:
            xml_names = [name for name in zf.namelist() if name.endswith(".xml")]
            if not xml_names:
                raise RuntimeError("No XML file found in instantane.zip")

            with zf.open(xml_names[0]) as xml_file:
                for pdv in _iter_pdv(xml_file):
                    station_id = pdv.get("id")
                    if not station_id:
                        continue

                    station_rows.append(_station_row_from_element(pdv))

                    for price_row in _price_rows_from_element(pdv, station_id):
                        key = (station_id, price_row["fuel_type"])
                        current = existing_prices.get(key)
                        if current is not None:
                            if current[0] == price_row["price"] and current[1] == price_row["update_date"]:
                                continue
                        existing_prices[key] = (price_row["price"], price_row["update_date"])
                        price_rows.append(price_row)
                        history_rows.append(price_row)

                    if len(station_rows) >= BATCH_SIZE:
                        try:
                            await _upsert_stations(session, station_rows)
                        except Exception:
                            logger.exception(
                                "Failed to upsert stations batch; first item=%s",
                                station_rows[0] if station_rows else None,
                            )
                        station_rows.clear()

                    if len(price_rows) >= BATCH_SIZE:
                        if station_rows:
                            try:
                                await _upsert_stations(session, station_rows)
                            except Exception as e:
                                logger.error(f"Error upserting stations (pre-price flush): {e}")
                            station_rows.clear()

                        try:
                            await _upsert_prices(session, price_rows)
                            await _insert_price_history(session, history_rows)
                        except Exception as e:
                            logger.error(f"Failed to upsert prices batch; first item={price_rows[0] if price_rows else 'empty'}", exc_info=e)
                        
                        price_rows.clear()
                        history_rows.clear()

        if station_rows:
            try:
                await _upsert_stations(session, station_rows)
            except Exception:
                logger.exception(
                    "Failed to upsert final stations batch; first item=%s",
                    station_rows[0] if station_rows else None,
                )

        if price_rows:
            try:
                await _upsert_prices(session, price_rows)
            except Exception:
                logger.exception(
                    "Failed to upsert final prices batch; first item=%s",
                    price_rows[0] if price_rows else None,
                )
            else:
                try:
                    await _insert_price_history(session, history_rows)
                except Exception:
                    logger.exception(
                        "Failed to insert final price history batch; first item=%s",
                        history_rows[0] if history_rows else None,
                    )

        await session.commit()
        logger.info("Fuel data import completed")
