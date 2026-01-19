# CODEX PROMPT: Complete REFUEL Implementation

## Objective
Implement the following critical features for the REFUEL iOS app. The backend is already running at `http://192.168.0.201:8000` with historical price data being imported.

---

## Feature 1: Dynamic Map Loading (Priority: HIGH)

### Requirements
When the user pans or zooms the map, dynamically load stations visible in the current map region.

### Implementation Steps

1. **MapView.swift**: Add a `MKMapViewDelegate` method to detect region changes:
   ```swift
   func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
       // Get center coordinates and visible radius
       let center = mapView.centerCoordinate
       let region = mapView.region
       // Calculate radius from span (approximate)
       let radiusKm = region.span.latitudeDelta * 111 / 2 // rough conversion
       // Call ViewModel to load stations for this region
       viewModel.loadStationsForRegion(lat: center.latitude, lon: center.longitude, radius: radiusKm)
   }
   ```

2. **StationsViewModel.swift**: Add a new method `loadStationsForRegion(lat:lon:radius:)` that:
   - Debounces requests (wait 300ms after last pan before fetching)
   - Calls `FuelDataService.fetchStations(latitude:longitude:radius:)`
   - Merges new stations with existing ones (avoid duplicates by station ID)
   - Updates the published `stations` array

3. **FuelDataService.swift**: The `fetchStations` method already accepts `latitude`, `longitude`, and `radius`. Ensure it's being used correctly.

4. **Caching**: Keep a local cache of already-loaded stations to avoid re-fetching when panning back to a previously viewed area.

---

## Feature 2: Price Optimization Indicators (Priority: HIGH)

### Requirements
Use historical data to show users when a station's current price is LOW, AVERAGE, or HIGH compared to its historical prices.

### Backend Endpoint Needed
Create a new endpoint `GET /stations/{station_id}/price-analysis` that returns:
```json
{
  "station_id": "12345678",
  "fuel_type": "Gazole",
  "current_price": 1.459,
  "avg_30_days": 1.512,
  "min_30_days": 1.420,
  "max_30_days": 1.589,
  "percentile": 15,  // Current price is in the 15th percentile (low!)
  "trend": "decreasing"  // or "increasing" or "stable"
}
```

### iOS Implementation

1. **Models/PriceAnalysis.swift** (NEW FILE):
   ```swift
   struct PriceAnalysis: Codable {
       let stationId: String
       let fuelType: String
       let currentPrice: Double
       let avg30Days: Double
       let min30Days: Double
       let max30Days: Double
       let percentile: Int
       let trend: String
       
       var priceLevel: PriceLevel {
           if percentile <= 25 { return .low }
           else if percentile <= 75 { return .average }
           else { return .high }
       }
   }
   
   enum PriceLevel {
       case low, average, high
       
       var color: Color {
           switch self {
           case .low: return .green
           case .average: return .orange
           case .high: return .red
           }
       }
       
       var label: String {
           switch self {
           case .low: return "Prix Bas"
           case .average: return "Prix Moyen"
           case .high: return "Prix Élevé"
           }
       }
   }
   ```

2. **StationDetailView.swift**: Display a price indicator badge:
   - Green badge "Prix Bas 🔥" if percentile <= 25
   - Orange badge "Prix Moyen" if percentile 25-75
   - Red badge "Prix Élevé ⚠️" if percentile > 75
   - Show a mini chart with 30-day trend

3. **StationRowView.swift**: Add a small colored dot next to the price indicating the level.

---

## Feature 3: Work vs Home Price Comparison (Priority: HIGH)

### Requirements
Allow user to set "Home" and "Work" locations. Show a comparison view of the best prices within 10-15km of each location.

### Implementation Steps

1. **UserProfile Model** (already exists, extend it):
   ```swift
   struct UserProfile {
       var homeCoordinate: CLLocationCoordinate2D?
       var workCoordinate: CLLocationCoordinate2D?
       var homeAddress: String?
       var workAddress: String?
       var comparisonRadius: Double = 15.0 // km
   }
   ```

2. **SettingsView.swift**: Add UI to set Home and Work addresses:
   - Use `MKLocalSearchCompleter` for address autocomplete
   - Save to UserDefaults or SwiftData
   - Show current saved addresses with edit/delete options

3. **ComparisonView.swift** (NEW FILE):
   ```swift
   struct ComparisonView: View {
       @StateObject var viewModel = ComparisonViewModel()
       
       var body: some View {
           VStack {
               Text("Comparaison Prix")
                   .font(.title)
               
               HStack(spacing: 20) {
                   // Home Column
                   VStack {
                       Image(systemName: "house.fill")
                       Text("Maison")
                       if let best = viewModel.bestNearHome {
                           StationMiniCard(station: best)
                       }
                   }
                   
                   // Divider
                   Divider()
                   
                   // Work Column
                   VStack {
                       Image(systemName: "briefcase.fill")
                       Text("Travail")
                       if let best = viewModel.bestNearWork {
                           StationMiniCard(station: best)
                       }
                   }
               }
               
               // Recommendation
               if let recommendation = viewModel.recommendation {
                   Text(recommendation)
                       .font(.headline)
                       .foregroundColor(.green)
               }
           }
       }
   }
   ```

4. **ComparisonViewModel.swift** (NEW FILE):
   - Fetch stations near Home (15km radius)
   - Fetch stations near Work (15km radius)
   - Find cheapest station for selected fuel type in each zone
   - Calculate savings: "Vous économisez X€ en faisant le plein près du travail"

5. **Navigation**: Add a tab or button in the main view to access the Comparison view.

---

## Backend Changes Required

### File: `backend/app/routers/stations.py`

Add the price analysis endpoint:

```python
@router.get("/stations/{station_id}/price-analysis")
async def get_price_analysis(
    station_id: str,
    fuel_type: str = "Gazole",
    session: AsyncSession = Depends(get_session)
):
    # Get current price
    current = await session.execute(
        select(Price).where(Price.station_id == station_id, Price.fuel_type == fuel_type)
    )
    current_price = current.scalar_one_or_none()
    
    # Get 30-day history
    thirty_days_ago = datetime.now() - timedelta(days=30)
    history = await session.execute(
        select(PriceHistory)
        .where(
            PriceHistory.station_id == station_id,
            PriceHistory.fuel_type == fuel_type,
            PriceHistory.update_date >= thirty_days_ago
        )
    )
    history_prices = [h.price for h in history.scalars().all()]
    
    if not history_prices:
        return {"error": "No historical data"}
    
    avg = sum(history_prices) / len(history_prices)
    min_p = min(history_prices)
    max_p = max(history_prices)
    
    # Calculate percentile
    sorted_prices = sorted(history_prices)
    percentile = sum(1 for p in sorted_prices if p <= current_price.value) / len(sorted_prices) * 100
    
    return {
        "station_id": station_id,
        "fuel_type": fuel_type,
        "current_price": current_price.value,
        "avg_30_days": round(avg, 3),
        "min_30_days": min_p,
        "max_30_days": max_p,
        "percentile": int(percentile),
        "trend": "stable"  # TODO: calculate trend
    }
```

---

## UI/UX Guidelines

1. **LiquidGlass Design**: Continue using iOS 26's LiquidGlass aesthetic with:
   - Glassmorphism backgrounds
   - Smooth animations
   - Haptic feedback on interactions

2. **Colors**:
   - Low Price: `#34C759` (Green)
   - Average Price: `#FF9500` (Orange)
   - High Price: `#FF3B30` (Red)

3. **Accessibility**: Ensure color-blind users can distinguish price levels (use icons/labels too).

---

## Files to Create/Modify

### New Files:
- `Models/PriceAnalysis.swift`
- `Views/ComparisonView.swift`
- `ViewModels/ComparisonViewModel.swift`
- `Components/StationMiniCard.swift`
- `Components/PriceLevelBadge.swift`

### Modify:
- `Views/MapView.swift` - Add dynamic loading
- `Views/StationDetailView.swift` - Add price analysis display
- `Views/SettingsView.swift` - Add Home/Work setup
- `ViewModels/StationsViewModel.swift` - Add region-based loading
- `Services/FuelDataService.swift` - Add price analysis fetch
- `backend/app/routers/stations.py` - Add price analysis endpoint

---

## Testing Checklist

- [ ] Map loads new stations when panning
- [ ] Price level badges appear correctly
- [ ] Home/Work can be set in Settings
- [ ] Comparison view shows best prices for both locations
- [ ] Price analysis endpoint returns correct percentile
- [ ] App doesn't crash with no historical data

---

## Run Instructions

1. Make sure backend is running: `cd backend && docker compose up -d`
2. Build iOS app in Xcode
3. Test on simulator or device

Good luck! 🚀
