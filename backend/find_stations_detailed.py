#!/usr/bin/env python3
"""
Script détaillé pour trouver les stations essence avec toutes les infos.
"""

import xml.etree.ElementTree as ET
import math
from dataclasses import dataclass, field
from typing import Optional
import requests

@dataclass
class Carburant:
    nom: str
    prix: float
    maj: str

@dataclass
class Station:
    id: str
    adresse: str
    ville: str
    cp: str
    latitude: float
    longitude: float
    distance_km: float = 0.0
    carburants: list = field(default_factory=list)
    services: list = field(default_factory=list)
    horaires: dict = field(default_factory=dict)
    automate_24_24: bool = False

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
    """Calcule la distance en km entre deux points GPS."""
    R = 6371
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
            lat = float(pdv.get('latitude', 0)) / 100000
            lon = float(pdv.get('longitude', 0)) / 100000
            
            if lat == 0 or lon == 0:
                continue
            
            distance = haversine_distance(target_lat, target_lon, lat, lon)
            
            if distance > radius_km:
                continue
            
            # Carburants
            carburants = []
            has_gazole = False
            for prix in pdv.findall('.//prix'):
                carburant = Carburant(
                    nom=prix.get('nom', ''),
                    prix=float(prix.get('valeur', 0)),
                    maj=prix.get('maj', '')
                )
                carburants.append(carburant)
                if carburant.nom == 'Gazole':
                    has_gazole = True
            
            if not has_gazole:
                continue
            
            # Services
            services = []
            for service in pdv.findall('.//service'):
                if service.text:
                    services.append(service.text)
            
            # Horaires
            horaires_elem = pdv.find('.//horaires')
            automate_24_24 = False
            horaires = {}
            if horaires_elem is not None:
                automate_24_24 = horaires_elem.get('automate-24-24') == '1'
                for jour in horaires_elem.findall('.//jour'):
                    jour_nom = jour.get('nom', '')
                    ferme = jour.get('ferme') == '1'
                    horaire_elem = jour.find('horaire')
                    if horaire_elem is not None:
                        ouverture = horaire_elem.get('ouverture', '')
                        fermeture = horaire_elem.get('fermeture', '')
                        horaires[jour_nom] = {'ferme': ferme, 'ouverture': ouverture, 'fermeture': fermeture}
                    else:
                        horaires[jour_nom] = {'ferme': ferme, 'ouverture': '', 'fermeture': ''}
            
            station = Station(
                id=pdv.get('id', ''),
                adresse=pdv.find('adresse').text if pdv.find('adresse') is not None else '',
                ville=pdv.find('ville').text if pdv.find('ville') is not None else '',
                cp=pdv.get('cp', ''),
                latitude=lat,
                longitude=lon,
                distance_km=round(distance, 2),
                carburants=carburants,
                services=services,
                horaires=horaires,
                automate_24_24=automate_24_24
            )
            stations.append(station)
            
        except Exception as e:
            continue
    
    # Trier par distance
    stations.sort(key=lambda s: s.distance_km)
    
    return stations

def print_station_details(station: Station, index: int):
    """Affiche tous les détails d'une station."""
    print(f"\n{'='*80}")
    print(f"📍 STATION #{index}: {station.ville}")
    print(f"{'='*80}")
    
    print(f"\n📌 LOCALISATION")
    print(f"   Adresse  : {station.adresse}")
    print(f"   Code postal : {station.cp}")
    print(f"   Ville    : {station.ville}")
    print(f"   Distance : {station.distance_km} km")
    print(f"   GPS      : {station.latitude:.5f}, {station.longitude:.5f}")
    print(f"   🗺️  Google Maps: https://www.google.com/maps?q={station.latitude},{station.longitude}")
    
    print(f"\n⛽ CARBURANTS DISPONIBLES")
    gazole = None
    for c in station.carburants:
        emoji = "🟢" if c.nom == "Gazole" else "🔵"
        print(f"   {emoji} {c.nom:<10} : {c.prix:.3f} €/L  (màj: {c.maj})")
        if c.nom == "Gazole":
            gazole = c
    
    if station.automate_24_24:
        print(f"\n🕐 HORAIRES: Automate 24h/24 ✅")
    elif station.horaires:
        print(f"\n🕐 HORAIRES")
        for jour, h in station.horaires.items():
            if h['ferme']:
                print(f"   {jour}: Fermé")
            elif h['ouverture'] and h['fermeture']:
                print(f"   {jour}: {h['ouverture']} - {h['fermeture']}")
            else:
                print(f"   {jour}: Non renseigné")
    
    if station.services:
        print(f"\n🛠️  SERVICES ({len(station.services)})")
        for s in station.services:
            print(f"   • {s}")
    else:
        print(f"\n🛠️  SERVICES: Aucun renseigné")
    
    # Calcul économies potentielles
    if gazole:
        litres_plein = 50  # Plein moyen
        cout_plein = gazole.prix * litres_plein
        print(f"\n💰 ESTIMATION COÛT PLEIN (50L Gazole)")
        print(f"   Coût    : {cout_plein:.2f} €")
    
    return gazole.prix if gazole else 0

def main():
    city = "Racquinghem"
    radius_km = 5.0
    
    print(f"🔍 Recherche des coordonnées de {city}...")
    lat, lon = get_city_coordinates(city)
    print(f"📍 Centre de recherche: {lat:.5f}, {lon:.5f}")
    
    print(f"\n🛢️ Recherche des stations dans un rayon de {radius_km}km...")
    stations = parse_stations("PrixCarburants_instantane.xml", lat, lon, radius_km)
    
    print(f"\n✅ {len(stations)} stations trouvées avec du Gazole")
    
    prix_list = []
    for i, station in enumerate(stations, 1):
        prix = print_station_details(station, i)
        prix_list.append((station, prix))
    
    # Comparaison finale
    if len(prix_list) >= 2:
        prix_list_sorted = sorted(prix_list, key=lambda x: x[1])
        moins_chere = prix_list_sorted[0]
        plus_chere = prix_list_sorted[-1]
        
        diff_litre = plus_chere[1] - moins_chere[1]
        diff_plein = diff_litre * 50
        
        print(f"\n{'='*80}")
        print(f"📊 COMPARAISON FINALE")
        print(f"{'='*80}")
        print(f"   🥇 Moins chère : {moins_chere[0].ville} - {moins_chere[1]:.3f} €/L")
        print(f"   🥉 Plus chère  : {plus_chere[0].ville} - {plus_chere[1]:.3f} €/L")
        print(f"   💵 Différence  : {diff_litre:.3f} €/L ({diff_plein:.2f} € sur un plein de 50L)")

if __name__ == "__main__":
    main()
