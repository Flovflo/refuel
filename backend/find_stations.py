#!/usr/bin/env python3
"""
Script pour trouver les stations essence autour d'une ville donnée.
Utilise les données Open Data du gouvernement français.
"""

import xml.etree.ElementTree as ET
import math
from dataclasses import dataclass
from typing import Optional
import requests

@dataclass
class Station:
    id: str
    adresse: str
    ville: str
    cp: str
    latitude: float
    longitude: float
    gazole_prix: Optional[float] = None
    gazole_maj: Optional[str] = None
    distance_km: float = 0.0

def get_city_coordinates(city_name: str) -> tuple[float, float]:
    """Récupère les coordonnées GPS d'une ville via l'API Nominatim."""
    url = f"https://nominatim.openstreetmap.org/search"
    params = {
        "q": f"{city_name}, France",
        "format": "json",
        "limit": 1
    }
    headers = {"User-Agent": "FuelPriceApp/1.0"}
    response = requests.get(url, params=params, headers=headers)
    data = response.json()
    
    if not data:
        raise ValueError(f"Ville '{city_name}' non trouvée")
    
    return float(data[0]["lat"]), float(data[0]["lon"])

def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calcule la distance en km entre deux points GPS (formule de Haversine)."""
    R = 6371  # Rayon de la Terre en km
    
    lat1_rad = math.radians(lat1)
    lat2_rad = math.radians(lat2)
    delta_lat = math.radians(lat2 - lat1)
    delta_lon = math.radians(lon2 - lon1)
    
    a = math.sin(delta_lat/2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(delta_lon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    
    return R * c

def parse_stations(xml_file: str, target_lat: float, target_lon: float, radius_km: float = 5.0) -> list[Station]:
    """Parse le fichier XML et retourne les stations dans le rayon spécifié."""
    tree = ET.parse(xml_file)
    root = tree.getroot()
    
    stations = []
    
    for pdv in root.findall('.//pdv'):
        try:
            # Extraire les coordonnées (divisées par 100000 pour convertir en WGS84)
            lat = float(pdv.get('latitude', 0)) / 100000
            lon = float(pdv.get('longitude', 0)) / 100000
            
            if lat == 0 or lon == 0:
                continue
            
            # Calculer la distance
            distance = haversine_distance(target_lat, target_lon, lat, lon)
            
            if distance > radius_km:
                continue
            
            # Chercher le prix du Gazole
            gazole_prix = None
            gazole_maj = None
            for prix in pdv.findall('.//prix'):
                if prix.get('nom') == 'Gazole':
                    gazole_prix = float(prix.get('valeur', 0))  # Déjà en €/L
                    gazole_maj = prix.get('maj', '')
                    break
            
            # Si pas de Gazole, ignorer cette station
            if gazole_prix is None:
                continue
            
            station = Station(
                id=pdv.get('id', ''),
                adresse=pdv.find('adresse').text if pdv.find('adresse') is not None else '',
                ville=pdv.find('ville').text if pdv.find('ville') is not None else '',
                cp=pdv.get('cp', ''),
                latitude=lat,
                longitude=lon,
                gazole_prix=gazole_prix,
                gazole_maj=gazole_maj,
                distance_km=round(distance, 2)
            )
            stations.append(station)
            
        except Exception as e:
            continue
    
    # Trier par prix croissant
    stations.sort(key=lambda s: s.gazole_prix)
    
    return stations

def main():
    city = "Racquinghem"
    radius_km = 5.0
    
    print(f"🔍 Recherche des coordonnées de {city}...")
    lat, lon = get_city_coordinates(city)
    print(f"📍 Coordonnées: {lat:.5f}, {lon:.5f}")
    
    print(f"\n🛢️ Recherche des stations dans un rayon de {radius_km}km...")
    stations = parse_stations("PrixCarburants_instantane.xml", lat, lon, radius_km)
    
    print(f"\n✅ {len(stations)} stations trouvées avec du Gazole\n")
    print("=" * 80)
    print(f"{'Rang':<5} {'Prix €/L':<10} {'Distance':<10} {'Ville':<20} {'Adresse'}")
    print("=" * 80)
    
    for i, station in enumerate(stations, 1):
        print(f"{i:<5} {station.gazole_prix:<10.3f} {station.distance_km:<10.2f} {station.ville[:20]:<20} {station.adresse[:40]}")
    
    print("=" * 80)
    
    if stations:
        best = stations[0]
        print(f"\n🏆 STATION LA MOINS CHÈRE:")
        print(f"   💰 Prix: {best.gazole_prix:.3f} €/L")
        print(f"   📍 {best.adresse}, {best.cp} {best.ville}")
        print(f"   📏 Distance: {best.distance_km} km")
        print(f"   🕐 Mise à jour: {best.gazole_maj}")

if __name__ == "__main__":
    main()
