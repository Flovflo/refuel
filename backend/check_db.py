
import asyncio
from sqlalchemy import func, select
from app.database import async_session
from app.models import FuelStation, Price

async def main():
    async with async_session() as session:
        count_stations = await session.scalar(select(func.count(FuelStation.id)))
        count_prices = await session.scalar(select(func.count(Price.id)))
        print(f"Stations: {count_stations}")
        print(f"Prices: {count_prices}")

if __name__ == "__main__":
    asyncio.run(main())
