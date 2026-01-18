#!/usr/bin/env python3
"""
Script pour analyser l'historique des prix carburant.
"""

import xml.etree.ElementTree as ET
import math
import os
from datetime import datetime, timedelta
from dataclasses import dataclass
from typing import Optional
import requests

@dataclass
class PrixJour:
    date: str
    prix: float
    maj: str

def get_city_coordinates(city_name: str) -> tuple[float, float]:
    url = f"https://nominatim.openstreetmap.org/search"
    params = {"q": f"{city_name}, France", "format": "json", "limit": 1}
    headers = {"User-Agent": "FuelPriceApp/1.0"}
    response = requests.get(url, params=params, headers=headers)
    data = response.json()
    if not data:
        raise ValueError(f"Ville '{city_name}' non trouvée")
    return float(data[0]["lat"]), float(data[0]["lon"])

def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371
    lat1_rad, lat2_rad = math.radians(lat1), math.radians(lat2)
    delta_lat, delta_lon = math.radians(lat2 - lat1), math.radians(lon2 - lon1)
    a = math.sin(delta_lat/2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(delta_lon/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

def get_station_price(xml_file: str, station_id: str, carburant_nom: str = "Gazole") -> Optional[tuple[float, str]]:
    """Récupère le prix d'un carburant pour une station donnée."""
    try:
        tree = ET.parse(xml_file)
        root = tree.getroot()
        for pdv in root.findall('.//pdv'):
            if pdv.get('id') == station_id:
                for prix in pdv.findall('.//prix'):
                    if prix.get('nom') == carburant_nom:
                        return float(prix.get('valeur', 0)), prix.get('maj', '')
    except:
        pass
    return None

def find_stations_near(xml_file: str, target_lat: float, target_lon: float, radius_km: float = 5.0) -> list[dict]:
    """Trouve les stations dans un rayon donné."""
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
            
            has_gazole = any(prix.get('nom') == 'Gazole' for prix in pdv.findall('.//prix'))
            if not has_gazole:
                continue
            
            stations.append({
                'id': pdv.get('id'),
                'ville': pdv.find('ville').text if pdv.find('ville') is not None else '',
                'adresse': pdv.find('adresse').text if pdv.find('adresse') is not None else '',
                'distance': round(distance, 2)
            })
        except:
            continue
    
    return stations

def main():
    city = "Racquinghem"
    radius_km = 5.0
    carburant = "Gazole"
    
    print(f"🔍 Recherche des coordonnées de {city}...")
    lat, lon = get_city_coordinates(city)
    
    # Trouver les stations dans le fichier instantané
    print(f"\n🛢️ Recherche des stations dans un rayon de {radius_km}km...")
    stations = find_stations_near("PrixCarburants_instantane.xml", lat, lon, radius_km)
    
    print(f"✅ {len(stations)} stations trouvées")
    
    # Répertoire historique
    hist_dir = "historique"
    dates = []
    for d in sorted(os.listdir(hist_dir)):
        if d.startswith("jour_") and os.path.isdir(os.path.join(hist_dir, d)):
            dates.append(d.replace("jour_", ""))
    
    dates.sort()
    
    print(f"\n📅 Historique disponible: {len(dates)} jours")
    print(f"   Du {dates[0]} au {dates[-1]}")
    
    # Pour chaque station, récupérer l'historique
    for station in stations:
        print(f"\n{'='*80}")
        print(f"📍 {station['ville']} - {station['adresse']}")
        print(f"   ID: {station['id']} | Distance: {station['distance']} km")
        print(f"{'='*80}")
        
        historique = []
        
        for date_str in dates:
            xml_dir = os.path.join(hist_dir, f"jour_{date_str}")
            xml_files = [f for f in os.listdir(xml_dir) if f.endswith('.xml')]
            if xml_files:
                xml_path = os.path.join(xml_dir, xml_files[0])
                result = get_station_price(xml_path, station['id'], carburant)
                if result:
                    prix, maj = result
                    date_formatted = f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:]}"
                    historique.append({
                        'date': date_formatted,
                        'prix': prix,
                        'maj': maj
                    })
        
        # Aussi ajouter le prix actuel (instantané)
        result_now = get_station_price("PrixCarburants_instantane.xml", station['id'], carburant)
        if result_now:
            prix_now, maj_now = result_now
            historique.append({
                'date': datetime.now().strftime('%Y-%m-%d'),
                'prix': prix_now,
                'maj': maj_now
            })
        
        if not historique:
            print("   ❌ Aucun historique disponible")
            continue
        
        # Afficher l'historique
        print(f"\n📊 HISTORIQUE {carburant} (7 derniers jours)")
        print(f"   {'Date':<12} {'Prix €/L':<10} {'Variation':<12} {'Dernière MAJ'}")
        print(f"   {'-'*60}")
        
        prev_prix = None
        prix_min = min(h['prix'] for h in historique)
        prix_max = max(h['prix'] for h in historique)
        
        for h in historique:
            variation = ""
            if prev_prix is not None:
                diff = h['prix'] - prev_prix
                if diff > 0:
                    variation = f"📈 +{diff:.3f}"
                elif diff < 0:
                    variation = f"📉 {diff:.3f}"
                else:
                    variation = "➡️  0.000"
            
            marker = ""
            if h['prix'] == prix_min:
                marker = " ⭐ MIN"
            elif h['prix'] == prix_max:
                marker = " ⚠️  MAX"
            
            print(f"   {h['date']:<12} {h['prix']:<10.3f} {variation:<12} {h['maj'][:16]}{marker}")
            prev_prix = h['prix']
        
        # Statistiques
        print(f"\n📈 STATISTIQUES")
        print(f"   Prix minimum     : {prix_min:.3f} €/L")
        print(f"   Prix maximum     : {prix_max:.3f} €/L")
        print(f"   Écart            : {prix_max - prix_min:.3f} €/L")
        
        first_prix = historique[0]['prix']
        last_prix = historique[-1]['prix']
        tendance = last_prix - first_prix
        
        if tendance > 0:
            print(f"   📈 Tendance semaine: +{tendance:.3f} €/L (HAUSSE)")
        elif tendance < 0:
            print(f"   📉 Tendance semaine: {tendance:.3f} €/L (BAISSE)")
        else:
            print(f"   ➡️  Tendance semaine: STABLE")
        
        # Graphique ASCII simple
        print(f"\n📊 GRAPHIQUE (échelle: {prix_min:.3f} - {prix_max:.3f})")
        range_prix = prix_max - prix_min if prix_max != prix_min else 0.01
        
        for h in historique:
            bar_length = int((h['prix'] - prix_min) / range_prix * 30) + 1
            bar = "█" * bar_length
            print(f"   {h['date'][5:]}: {bar} {h['prix']:.3f}")

if __name__ == "__main__":
    main()
