# CODEX PROMPT: UI Polish & Price History Graph

## Main Goal 🎯
**Guide the user to save money on fuel.** Every design decision should focus on making it easy for users to find the cheapest fuel.

---

## Task 1: Price History Graph in Station Detail

When user taps a station, show a simple, easy-to-read price history chart.

### Requirements
- Use Swift Charts framework (`import Charts`)
- Show last 30 days of price data
- Simple line chart with minimal decorations
- Highlight current price vs average
- Color code: Green when below average, Red when above

### Implementation

```swift
// In StationDetailView.swift, add a chart section:

import Charts

struct PriceHistoryChart: View {
    let history: [PriceHistoryPoint]  // Date + Price pairs
    let currentPrice: Double
    let avgPrice: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Historique 30 jours")
                .font(.headline)
            
            Chart(history) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Prix", point.price)
                )
                .foregroundStyle(Color.blue.gradient)
                
                RuleMark(y: .value("Moyenne", avgPrice))
                    .foregroundStyle(.orange.opacity(0.5))
                    .lineStyle(StrokeStyle(dash: [5]))
            }
            .frame(height: 150)
            .chartYScale(domain: .automatic(includesZero: false))
            
            // Legend
            HStack {
                Circle().fill(.blue).frame(width: 8)
                Text("Prix")
                Spacer()
                Rectangle().fill(.orange.opacity(0.5)).frame(width: 20, height: 2)
                Text("Moyenne")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
```

### Backend Endpoint Needed
Add `GET /stations/{id}/price-history` that returns:
```json
{
  "station_id": "12345",
  "fuel_type": "Gazole",
  "history": [
    {"date": "2026-01-01", "price": 1.52},
    {"date": "2026-01-02", "price": 1.54},
    ...
  ]
}
```

---

## Task 2: Coherent Design System

### GlassCard Component (Use Everywhere)
```swift
struct GlassCard<Content: View>: View {
    let content: () -> Content
    
    var body: some View {
        content()
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
```

### Color Palette
- **Primary**: System Blue
- **Success/Low Price**: `Color(red: 0.2, green: 0.78, blue: 0.35)` (Green)
- **Warning/Average**: `Color(red: 1.0, green: 0.58, blue: 0.0)` (Orange)
- **Danger/High Price**: `Color(red: 1.0, green: 0.23, blue: 0.19)` (Red)
- **Background**: System background with glassmorphism

### Typography
- **Title**: `.title.bold()`
- **Headline**: `.headline`
- **Body**: `.body`
- **Caption**: `.caption.foregroundStyle(.secondary)`

---

## Task 3: Improve List View - Be the User's Guide

### New List Structure
The first tab should be a "smart" list that guides the user:

```swift
struct StationListView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 🔥 TOP RECOMMENDATION
                if let cheapest = viewModel.cheapestStation {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Meilleure offre", systemImage: "star.fill")
                            .font(.headline)
                            .foregroundStyle(.yellow)
                        
                        StationCard(station: cheapest, isHighlighted: true)
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.green.opacity(0.2), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                // 💰 SAVINGS SUMMARY
                if let savings = viewModel.potentialSavings {
                    HStack {
                        Image(systemName: "eurosign.circle.fill")
                            .font(.title)
                            .foregroundStyle(.green)
                        VStack(alignment: .leading) {
                            Text("Économie potentielle")
                                .font(.caption)
                            Text("\(savings, specifier: "%.2f")€ / plein")
                                .font(.title2.bold())
                        }
                        Spacer()
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                
                // 📍 NEARBY STATIONS
                Section {
                    ForEach(viewModel.stations) { station in
                        StationRowView(station: station)
                    }
                } header: {
                    HStack {
                        Text("Stations à proximité")
                            .font(.headline)
                        Spacer()
                        Text("\(viewModel.stations.count) trouvées")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
    }
}
```

---

## Task 4: Remove Separate Compare Tab

Integrate comparison INTO the list view instead of a separate tab:

### In StationListView, add comparison cards:
```swift
// Home vs Work comparison (if both are set)
if let home = viewModel.bestDealNearHome,
   let work = viewModel.bestDealNearWork {
    VStack(alignment: .leading, spacing: 12) {
        Text("Où faire le plein?")
            .font(.headline)
        
        HStack(spacing: 12) {
            // Home Card
            VStack {
                Image(systemName: "house.fill")
                    .font(.title2)
                Text("Maison")
                    .font(.caption)
                Text("\(homePrice, specifier: "%.3f")€")
                    .font(.title3.bold())
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(homePrice < workPrice ? .green.opacity(0.2) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Work Card  
            VStack {
                Image(systemName: "briefcase.fill")
                    .font(.title2)
                Text("Travail")
                    .font(.caption)
                Text("\(workPrice, specifier: "%.3f")€")
                    .font(.title3.bold())
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(workPrice < homePrice ? .green.opacity(0.2) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        
        // Recommendation
        let betterLocation = homePrice < workPrice ? "maison" : "travail"
        let savings = abs(homePrice - workPrice) * 50 // 50L tank
        Text("💡 Faites le plein près de \(betterLocation) pour économiser \(savings, specifier: "%.2f")€")
            .font(.subheadline)
            .foregroundStyle(.green)
    }
    .padding()
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
}
```

---

## Task 5: Polish Profile/Settings View

Make it match the app's design language:

```swift
struct SettingsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Vehicle Section
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Mon véhicule", systemImage: "car.fill")
                            .font(.headline)
                        
                        SettingsRow(icon: "fuelpump", title: "Carburant", value: fuelType.rawValue)
                        SettingsRow(icon: "gauge", title: "Consommation", value: "\(consumption) L/100km")
                        SettingsRow(icon: "drop.fill", title: "Réservoir", value: "\(tankSize) L")
                    }
                }
                
                // Locations Section
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Mes lieux", systemImage: "location.fill")
                            .font(.headline)
                        
                        LocationRow(icon: "house", title: "Maison", address: homeAddress)
                        LocationRow(icon: "briefcase", title: "Travail", address: workAddress)
                    }
                }
                
                // Search Radius
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Rayon de recherche", systemImage: "circle.dashed")
                            .font(.headline)
                        
                        Slider(value: $radius, in: 5...50, step: 5)
                        Text("\(Int(radius)) km")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Paramètres")
    }
}
```

---

## Files to Modify

1. **StationDetailView.swift** - Add PriceHistoryChart
2. **StationListView.swift** - Restructure with recommendations + comparison
3. **SettingsView.swift** - Polish design with GlassCard
4. **ContentView.swift** - Remove Compare tab if separate
5. **Components/GlassCard.swift** - Ensure consistent component exists
6. **backend/app/routers/stations.py** - Add price-history endpoint

---

## Design Principles to Follow

1. **Less is More**: Don't overwhelm with data
2. **Highlight Savings**: Green = Good = Save Money
3. **One Clear Action**: Each screen has ONE primary action
4. **Consistent Cards**: Use GlassCard everywhere
5. **Guide the User**: "Meilleure offre" at top, always visible

---

## Testing Checklist

- [ ] Price history chart renders with mock data
- [ ] Cheapest station highlighted at top
- [ ] Home/Work comparison shows when both set
- [ ] Settings view looks polished
- [ ] All cards use consistent glassmorphism
- [ ] Colors are coherent throughout

Good luck! 🚀
