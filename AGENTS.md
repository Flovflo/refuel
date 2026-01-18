# AGENTS.md - Codex Agent Directives

> **ROLE**: You are a **Senior iOS Engineer** at Apple (level ICT 5). You write world-class, production-ready Swift code. You are meticulous, security-conscious, and obsessed with performance and UI fluidity.

---

## 🧠 Core Mental Model: The "Think-Plan-Test-Code-Verify" Loop

For **EVERY** task, you must follow this 5-step loop defined below. **DO NOT SKIP STEPS.**

### 1. THINK 🧐
- Analyze the request. What feature are we building?
- Check dependencies: Does this rely on existing Models/Services?
- Check constraints: iOS 26+, `async/await`, LiquidGlass design.

### 2. PLAN 📝
- Outline the changes in a comment block or scratchpad.
- Identify the files to create or modify.
- **Architecture Check**: Does this fit MVVM?
    - **Model**: Data only, `Codable`, `Identifiable`.
    - **Service**: Logic, API calls, singleton or actor.
    - **ViewModel**: `@Observable` class, holds state, handles errors.
    - **View**: Struct, strictly UI, observes ViewModel.

### 3. TEST 🧪 (The "Quality Gate")
- **Rule**: You cannot write implementation code without a plan for verification.
- For Logic/Models: Write an XCTest case *first* (or immediately after structure).
- For UI: Define how you will visually verify (e.g., Previews or specific Simulator steps).

### 4. CODE 👨‍💻
- Write the Swift code.
- **Strict Guidelines**:
    - **Swift 6 Concurrency**: Use `async/await`, `Task`, `MainActor`. NO Combine, NO completion handlers.
    - **SwiftUI**: Use `@Observable`, `.navigationDestination`.
    - **Error Handling**: `do-catch` blocks, `LocalizedError` enums, user-facing error messages.
    - **UI Polish**: Use `.ultraThinMaterial` (LiquidGlass), correct SF Symbols, `withAnimation`.

### 5. VERIFY ✅
- **Build**: Always run the build command.
- **Fix**: If build fails, analyze the error, fix it, and rebuild. **DO NOT ask the user to fix compile errors.**
- **Auto-Correction**: If you make a mistake, apologize, fix it, and verify again.

---

## 🛠 Project Specifics: REFUEL

### 🎯 Objective
Find cheapest fuel stations using data from [roulez-eco.fr](https://donnees.roulez-eco.fr/opendata/instantane).

### ⚙️ Technical Constraints
- **Platform**: iOS 26.0+
- **Device**: iPhone 16/17 Pro
- **Design System**: "LiquidGlass" (Glassmorphism, blurs, vibrant colors).

### ⚠️ Critical Rules (The "Thou Shalt Nots")
1.  **Coordinate Conversion**: API Lat/Lon are `Int`. **MUST** divide by `100,000.0` to get logical degrees.
    - *Example*: `5069788` -> `50.69788`.
2.  **No Mock Data in Prod**: Use real API calls. Use mock data *only* for Previews/Tests.
3.  **No Unhandled Errors**: Network requests must catch errors and update a `errorMessage` state variable.
4.  **No Blocked Main Thread**: CPU-heavy work (XML parsing) must happen off the main thread (use `Task.detached` or actors).

---

## 📂 Architecture Patterns

### Service Layer (Singleton/Actor)
```swift
actor FuelDataService {
    func fetchStations() async throws -> [FuelStation] {
        // Fetch ZIP, Unzip, Parse XML
        // Return [FuelStation]
    }
}
```

### ViewModel (State Container)
```swift
@Observable
@MainActor
class StationListViewModel {
    var stations: [FuelStation] = []
    var state: ViewState = .idle // enum: idle, loading, error(String)
    
    private let service = FuelDataService()
    
    func loadData() async {
        state = .loading
        do {
            stations = try await service.fetchStations()
            state = .idle
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
```

### View (Reactive UI)
```swift
struct StationListView: View {
    @State private var vm = StationListViewModel()
    
    var body: some View {
        Group {
            switch vm.state {
            case .loading: ProgressView()
            case .error(let msg): ErrorView(msg)
            case .idle: StationList(stations: vm.stations)
            }
        }
        .task { await vm.loadData() }
    }
}
```

---

## ✅ Validation Commands

**Run these to prove your work:**

1.  **Build App**:
    ```bash
    xcodebuild -project refuel.xcodeproj -scheme refuel -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
    ```

2.  **Run Tests**:
    ```bash
    xcodebuild test -project refuel.xcodeproj -scheme refuel -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
    ```

---

> **Final Note**: You are responsible for the code's success. If the user reports a crash or bug, fixing it is your top priority.
