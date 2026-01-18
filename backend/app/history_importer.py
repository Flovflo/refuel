
import asyncio
import io
import logging
import zipfile
from datetime import datetime
from typing import Any

import requests
from geoalchemy2.elements import WKTElement
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert

# Use absolute imports assuming running as module "app.history_importer"
from app.database import async_session, init_db
from app.models import FuelStation, FuelType, PriceHistory

try:
    from lxml import etree as ET
except ImportError:
    import xml.etree.ElementTree as ET

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

BATCH_SIZE = 1000

async def download_and_extract(year: int) -> bytes | None:
    url = f"https://donnees.roulez-eco.fr/opendata/annee/{year}"
    logger.info(f"Downloading data for {year} from {url}...")
    try:
        response = requests.get(url, timeout=60)
        response.raise_for_status()
    except Exception as e:
        logger.error(f"Failed to download {year}: {e}")
        return None

    logger.info(f"Downloaded {len(response.content)} bytes. Extracting...")
    try:
        with zipfile.ZipFile(io.BytesIO(response.content)) as z:
            # Usually one XML file inside
            filename = z.namelist()[0]
            logger.info(f"Extracting {filename}...")
            return z.read(filename)
    except Exception as e:
        logger.error(f"Failed to extract zip for {year}: {e}")
        return None

def _parse_timestamp(val: str | None) -> datetime | None:
    if not val:
        return None
    # Format usually "2025-01-01T12:00:00" or similar
    # Sometimes it has different formats, but assuming standard
    try:
        if len(val) == 10: # YYYY-MM-DD
             return datetime.strptime(val, "%Y-%m-%d")
        return datetime.fromisoformat(val)
    except ValueError:
        try:
             # Fallback for manual parsing if isoformat fails (rare in this dataset)
             return datetime.strptime(val, "%Y-%m-%dT%H:%M:%S")
        except:
             return None

async def process_xml_content(xml_content: bytes):
    logger.info("Starting XML parsing...")
    
    # Use BytesIO for iterative parsing
    context = ET.iterparse(io.BytesIO(xml_content), events=("end",), tag="pdv")
    
    station_rows = []
    history_rows = []
    
    count = 0
    
    for event, elem in context:
        try:
                pdv_id = elem.get("id")
                lat_str = elem.get("latitude")
                lon_str = elem.get("longitude")
                cp = elem.get("cp")
                pop = elem.get("pop") # Point de Vente type (R = Road, A = Highway)
                
                # Address
                addr_elem = elem.find("adresse")
                address = addr_elem.text if addr_elem is not None else None
                
                city_elem = elem.find("ville")
                city = city_elem.text if city_elem is not None else None
                
                # Check coords
                if not pdv_id or not lat_str or not lon_str:
                    continue

                try:
                    lat = float(lat_str) / 100000.0
                    lon = float(lon_str) / 100000.0
                except (ValueError, TypeError):
                    continue
                    
                # Create Station Dict
                # Use WKT for geometry
                wkt = f"POINT({lon} {lat})"
                
                station_data = {
                    "id": pdv_id,
                    "location": WKTElement(wkt, srid=4326),
                    "address": address,
                    "city": city,
                    "cp": cp
                }
                station_rows.append(station_data)
                
                # Parse Prices
                for price_elem in elem.findall("prix"):
                    nom = price_elem.get("nom") # Gazole, etc.
                    val_str = price_elem.get("valeur")
                    maj_str = price_elem.get("maj")
                    
                    if not nom or not val_str or not maj_str:
                        continue
                        
                    # Normalize FuelType
                    # Existing importer logic:
                    # FuelType enum is string based.
                    # e.g. "Gazole", "SP95", "E10"
                    # We accept as is if it matches our Enum?
                    # Or map it? In previous importer we mapped it roughly or trusted it.
                    # Models.py: E10="E10", GAZOLE="Gazole", etc.
                    # The XML usually matches "Gazole", "SP95", "E10", "E85", "GPLc", "SP98"
                    
                    try:
                        price_val = float(val_str)
                        update_date = _parse_timestamp(maj_str)
                    except ValueError:
                        continue
                        
                    if update_date:
                        history_rows.append({
                            "station_id": pdv_id,
                            "fuel_type": nom,
                            "price": price_val,
                            "update_date": update_date
                        })
                
                # Batch processing
                if len(station_rows) >= BATCH_SIZE:
                     await _flush_stations(station_rows)
                     station_rows.clear()
                     
                if len(history_rows) >= BATCH_SIZE * 5: 
                     # Must flush stations first!
                     if station_rows:
                         await _flush_stations(station_rows)
                         station_rows.clear()
                     await _flush_history(history_rows)
                     history_rows.clear()
                
                count += 1
                if count % 1000 == 0:
                    logger.info(f"Processed {count} stations...")
                    
                # Clear memory
                elem.clear()
                while elem.getprevious() is not None:
                    del elem.getparent()[0]
                    
            except Exception as e:
                logger.error(f"Error processing station element: {e}")
                continue
                
        # Flush remaining
        if station_rows:
            await _flush_stations(station_rows)
        if history_rows:
            await _flush_history(history_rows)
            
    logger.info(f"XML Parsing complete. Total stations: {count}")

async def _flush_stations(rows):
    if not rows:
        return
    async with async_session() as session:
        stmt = insert(FuelStation).values(rows)
        stmt = stmt.on_conflict_do_update(
            index_elements=["id"],
            set_={
                "address": stmt.excluded.address,
                "city": stmt.excluded.city,
                "cp": stmt.excluded.cp,
                "location": stmt.excluded.location
            }
        )
        await session.execute(stmt)
        await session.commit()

async def _flush_history(rows):
    if not rows:
        return
    async with async_session() as session:
        stmt = insert(PriceHistory).values(rows)
        stmt = stmt.on_conflict_do_nothing(
            constraint="uq_price_history_entry" 
        )
        await session.execute(stmt)
        await session.commit()

async def import_history(years: list[int]):
    await init_db()
    for year in years:
        logger.info(f"--- Starting Import for {year} ---")
        xml_bytes = await download_and_extract(year)
        if xml_bytes:
             await process_xml_content(xml_bytes)
        logger.info(f"--- Finished Import for {year} ---")

if __name__ == "__main__":
    import sys
    # Default to 2025, 2026
    years = [2025, 2026]
    try:
        asyncio.run(import_history(years))
    except Exception as e:
        logger.exception("Fatal error in history import")
