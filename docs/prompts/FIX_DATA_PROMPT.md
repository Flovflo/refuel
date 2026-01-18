# Codex Fix Prompt: ZIP Decompression

**Context**: 
The app returns "No Results" even though search logic works.
**Root Cause**: The API (`https://donnees.roulez-eco.fr/opendata/instantane`) returns a **ZIP archive**, but `FuelDataService.swift` tries to parse it directly as XML.
The comment `// TODO: Handle Unzip` was never implemented.

**Objective**:
Implement ZIP decompression in `FuelDataService` using native APIs (e.g., `AppleArchive`, `Compression`, or simple `file` based unzip if easier) so the app can parse the real data.

**Tasks**:

1.  **Implement Unzip Logic (`FuelDataService.swift`)**:
    -   When `fetchStations` receives data, detect if it is a ZIP.
    -   Decompress it to get the XML data.
    -   *Constraint*: Use **Native Swift/iOS APIs** (e.g., `AppleArchive`, `compression_decode_buffer`, or writing to extensive temporary file and using `FileManager` if needed). Avoid external dependencies like `ZIPFoundation` unless you can easily add them via SPM (prefer native `ArchiveByteStream` or similar if you know how, or a simple helper).
    -   *Hint*: The simplest reliable way on iOS without external deps is often writing `Data` to a temporary file, then unzip using `Archive` or a focused helper.

2.  **Verify with Integration Test (`ServicesTests.swift`)**:
    -   Add `testRealNetworkFetch()` which calls `fetchStations()` (enable it only for local testing or check internet).
    -   Assert that `stations.count > 0` (The real API returns thousands of stations).
    -   This ensures we are correctly unzipping and parsing the REAL format.
    -   *Note*: The current `testXMLParsing` likely uses clean XML strings, which is why it passed. We need a test against the **ZIP** format.

3.  **Run Tests**:
    -   `xcodebuild test`
