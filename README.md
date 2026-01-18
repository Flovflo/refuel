# ⛽️ REFUEL - Smart Fuel Intelligence

![Platform](https://img.shields.io/badge/Platform-iOS%2018-black) ![Stack](https://img.shields.io/badge/Tech-SwiftUI%20%7C%20FastAPI%20%7C%20PostGIS-orange)

**REFUEL** is a next-generation fuel station finder that combines a high-performance **SwiftUI** frontend with a custom **Python/PostGIS** backend. It replaces legacy XML parsing with a geospatial API to deliver instant results without UI freezes.

---

## 🏗 System Architecture

The project is split into two robust components:

### 1. 📱 iOS Frontend (`refuel/`)
- **Frameworks**: SwiftUI, MapKit, CoreLocation, Charts.
- **Design System**: "LiquidGlass" (iOS 26 Concept) - translucent materials, floating cards.
- **Networking**: Lightweight JSON consumption via `URLSession`.
- **Performance**: 0ms UI blocking. All heavy lifting is offloaded.

### 2. 🚀 Backend API (`backend/`)
- **Core**: Python 3.11 + FastAPI.
- **Database**: PostgreSQL + **PostGIS** for geospatial queries.
- **Data Source**: Automatic daily sync with the French Government Open Data (`PrixCarburants_quotidien`).
- **Importer**: Streaming XML parser (lxml) that populates `FuelStation` and `Price` tables.

---

## 🛠️ Quick Start

### Prerequisites
- **Xcode 16+** (for iOS 18+ SDK)
- **Docker Desktop** (for Backend)

### Step 1: Launch the Backend 🐳
The backend is dockerized for one-command startup.

```bash
cd backend
docker compose up -d --build
```
*This will:*
- Start PostgreSQL/PostGIS.
- Start FastAPI Service on port `8000`.
- Automatically download and import the latest Fuel Data (~10MB/day).

### Step 2: Configure iOS App 📱
1. Open `refuel.xcodeproj` in Xcode.
2. Navigate to `refuel/Services/FuelDataService.swift`.
3. Update `baseURLString` with your Mac's Local IP:
   ```swift
   private let baseURLString = "http://192.168.0.201:8000/stations" // Replace with your IP
   ```
4. Select your generic iOS Device or Simulator.
5. **Run (Cmd+R)**.

---

## 🔌 API Endpoints

The iOS app consumes the following endpoints:

- **`GET /stations`**
  - **Query**: `lat`, `lon`, `radius` (km), `fuel_type` (optional).
  - **Response**: JSON array of stations sorted by price (or distance).
  - **Logic**: Uses `ST_DWithin` and `ST_DistanceSphere` for meter-perfect accuracy.

---

## 📦 Project Structure

```
REFUEL/
├── refuel/                 # iOS Application Source
│   ├── Services/           # Logic (FuelDataService, etc.)
│   ├── Models/             # Swift Models (Codable)
│   └── Views/              # SwiftUI Components
├── backend/                # Python Backend Source
│   ├── app/                # FastAPI Application
│   │   ├── services/       # Import Logic
│   │   └── routers/        # API Routes
│   ├── docker-compose.yml  # Container Orchestration
│   └── Dockerfile          # Python Environment
└── REFUEL.xcodeproj        # Xcode Project
```

---

## 📝 Troubleshooting

- **App Crashes on Launch?**
  - Ensure Docker is running.
  - Verify your IP address matches `FuelDataService.swift`.
  - Check Backend logs: `docker logs api-api-1`.

- **No Stations Found?**
  - Confirm the database is populated (`docker exec -it api-db-1 psql -U user refuel_db`).
  - Check the search radius (default 5km).

---

Currently Maintained by **Florian**.
Merged to `main` on Jan 2026.
