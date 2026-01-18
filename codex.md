# codex.md - Quick Context

> **NOTE**: For architectural rules and workflow, SEE `AGENTS.md`.

## 📍 Project Info
- **App**: REFUEL
- **Min iOS**: 26.0
- **Frameworks**: SwiftUI, MapKit, CoreLocation, SwiftData

## 🔗 API Endpoint
- **URL**: `https://donnees.roulez-eco.fr/opendata/instantane`
- **Format**: ZIP -> XML

## 🧮 Critical Formulas

### Coordinate Conversion
```swift
// API returns INT s (e.g. 5069788). Must divide by 100,000.
let realLat = Double(xmlLat) / 100_000.0
```

### Haversine Distance (Backup if CoreLocation unavailable)
```swift
func distanceKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
    let R = 6371.0
    let dLat = (lat2 - lat1) * .pi / 180
    let dLon = (lon2 - lon1) * .pi / 180
    let a = sin(dLat/2) * sin(dLat/2) +
            cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
            sin(dLon/2) * sin(dLon/2)
    return R * 2 * atan2(sqrt(a), sqrt(1-a))
}
```

## 🛠 Build & Test

```bash
# BUILD
xcodebuild -project refuel.xcodeproj -scheme refuel -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# TEST
xcodebuild test -project refuel.xcodeproj -scheme refuel -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```
