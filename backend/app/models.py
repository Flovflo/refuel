from __future__ import annotations

from enum import Enum as PyEnum

from geoalchemy2 import Geometry
from sqlalchemy import Column, DateTime, Enum, Float, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import relationship

from app.database import Base


class FuelType(str, PyEnum):
    E10 = "E10"
    E85 = "E85"
    GPLC = "GPLc"
    GAZOLE = "Gazole"
    SP95 = "SP95"
    SP98 = "SP98"


class FuelStation(Base):
    __tablename__ = "fuel_stations"

    id = Column(String, primary_key=True)
    location = Column(Geometry(geometry_type="POINT", srid=4326))
    address = Column(String)
    city = Column(String)
    cp = Column(String)

    prices = relationship("Price", back_populates="station")
    price_history = relationship("PriceHistory", back_populates="station")


class Price(Base):
    __tablename__ = "prices"
    __table_args__ = (UniqueConstraint("station_id", "fuel_type", name="uq_price_station_fuel"),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    station_id = Column(String, ForeignKey("fuel_stations.id"), nullable=False)
    fuel_type = Column(String, nullable=False)
    price = Column(Float, nullable=False)
    update_date = Column(DateTime, nullable=False)

    station = relationship("FuelStation", back_populates="prices")


class PriceHistory(Base):
    __tablename__ = "price_history"

    id = Column(Integer, primary_key=True, autoincrement=True)
    station_id = Column(String, ForeignKey("fuel_stations.id"), nullable=False)
    fuel_type = Column(String, nullable=False)
    price = Column(Float, nullable=False)
    update_date = Column(DateTime, nullable=False)

    station = relationship("FuelStation", back_populates="price_history")
