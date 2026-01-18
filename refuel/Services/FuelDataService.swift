//
//  FuelDataService.swift
//  refuel
//
//  Created by Codex on 2026-01-18.
//

import Foundation
import Compression

enum FuelError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case unzippingFailed
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .networkError(let err): return "Network Error: \(err.localizedDescription)"
        case .unzippingFailed: return "Failed to unzip data"
        case .parsingError: return "Failed to parse XML"
        }
    }
}

actor FuelDataService {
    private let urlString = "https://donnees.roulez-eco.fr/opendata/instantane"
    
    func fetchStations() async throws -> [FuelStation] {
        guard let url = URL(string: urlString) else { throw FuelError.invalidURL }

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(from: url)
        } catch {
            throw FuelError.networkError(error)
        }

        let xmlData = try await decodeXMLDataIfNeeded(from: data)
        let stations = try await parseXML(data: xmlData)
        await PersistenceManager.shared.recordPriceHistory(for: stations)
        return stations
    }
    
    private func parseXML(data: Data) async throws -> [FuelStation] {
        let task = Task.detached(priority: .utility) {
            let parser = PDVParser(data: data)
            return try parser.parse()
        }
        return try await task.value
    }

    private func decodeXMLDataIfNeeded(from data: Data) async throws -> Data {
        guard data.isZIP else { return data }

        let task = Task.detached(priority: .utility) {
            try unzipXMLData(from: data)
        }
        return try await task.value
    }
}

// Internal Parser Helper
nonisolated final class PDVParser: NSObject, XMLParserDelegate {
    private let parser: XMLParser
    private var stations: [FuelStation] = []
    
    // Temp variables for current station
    private var currentID: String = ""
    private var currentLat: Double = 0
    private var currentLon: Double = 0
    private var currentAddress: String = ""
    private var currentCity: String = ""
    private var currentZip: String = ""
    private var currentPrices: [FuelPrice] = []
    private var currentElement: String = ""
    
    init(data: Data) {
        self.parser = XMLParser(data: data)
        super.init()
        self.parser.delegate = self
    }
    
    func parse() throws -> [FuelStation] {
        guard parser.parse() else {
            throw FuelError.parsingError
        }
        return stations
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        if elementName == "pdv" {
            currentID = attributeDict["id"] ?? ""
            currentZip = attributeDict["cp"] ?? ""
            
            let rawLat = Double(attributeDict["latitude"] ?? "") ?? 0
            let rawLon = Double(attributeDict["longitude"] ?? "") ?? 0
            currentLat = rawLat / 100_000.0
            currentLon = rawLon / 100_000.0
            
            currentPrices = []
            currentAddress = ""
            currentCity = ""
        } else if elementName == "prix" {
            if let nom = attributeDict["nom"],
               let valStr = attributeDict["valeur"],
               let dateStr = attributeDict["maj"],
               let val = Double(valStr),
               let type = FuelType(rawValue: nom) {
                
                // Date format: 2026-01-14T07:45:22
                let formatter = ISO8601DateFormatter()
                let date = formatter.date(from: dateStr) ?? Date()
                
                let price = FuelPrice(fuelType: type, price: val, lastUpdate: date)
                currentPrices.append(price)
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if currentElement == "adresse" {
            currentAddress += trimmed
        } else if currentElement == "ville" {
            currentCity += trimmed
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "pdv" {
            let station = FuelStation(
                id: currentID,
                address: currentAddress,
                city: currentCity,
                postalCode: currentZip,
                latitude: currentLat,
                longitude: currentLon,
                prices: currentPrices,
                services: [],
                isOpen24h: false
            )
            stations.append(station)
        }
        currentElement = ""
    }
}

nonisolated private extension Data {
    var isZIP: Bool {
        let signature = [UInt8](prefix(4))
        return signature == [0x50, 0x4B, 0x03, 0x04]
            || signature == [0x50, 0x4B, 0x05, 0x06]
            || signature == [0x50, 0x4B, 0x07, 0x08]
    }

    func readUInt16LE(at offset: Int) throws -> UInt16 {
        guard offset + 2 <= count else { throw FuelError.unzippingFailed }
        let value = withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self) }
        return UInt16(littleEndian: value)
    }

    func readUInt32LE(at offset: Int) throws -> UInt32 {
        guard offset + 4 <= count else { throw FuelError.unzippingFailed }
        let value = withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
        return UInt32(littleEndian: value)
    }

    func readString(at offset: Int, length: Int) throws -> String {
        guard offset + length <= count else { throw FuelError.unzippingFailed }
        let subdata = subdata(in: offset..<(offset + length))
        return String(data: subdata, encoding: .utf8) ?? ""
    }
}

nonisolated private struct ZIPEntry {
    let fileName: String
    let compressionMethod: UInt16
    let compressedSize: Int
    let uncompressedSize: Int
    let localHeaderOffset: Int
}

nonisolated private func unzipXMLData(from data: Data) throws -> Data {
    let entries = try readCentralDirectoryEntries(from: data)
    guard let xmlEntry = entries.first(where: { $0.fileName.lowercased().hasSuffix(".xml") }) ?? entries.first else {
        throw FuelError.unzippingFailed
    }
    return try extractEntryData(xmlEntry, from: data)
}

nonisolated private func readCentralDirectoryEntries(from data: Data) throws -> [ZIPEntry] {
    let eocdOffset = try findEndOfCentralDirectoryOffset(in: data)
    let totalEntries = Int(try data.readUInt16LE(at: eocdOffset + 10))
    let centralDirectoryOffset = Int(try data.readUInt32LE(at: eocdOffset + 16))

    guard totalEntries > 0 else { throw FuelError.unzippingFailed }
    guard centralDirectoryOffset >= 0, centralDirectoryOffset < data.count else { throw FuelError.unzippingFailed }

    var entries: [ZIPEntry] = []
    var offset = centralDirectoryOffset

    for _ in 0..<totalEntries {
        let signature = try data.readUInt32LE(at: offset)
        guard signature == 0x0201_4B50 else { throw FuelError.unzippingFailed }

        let compressionMethod = try data.readUInt16LE(at: offset + 10)
        let compressedSize = Int(try data.readUInt32LE(at: offset + 20))
        let uncompressedSize = Int(try data.readUInt32LE(at: offset + 24))
        let fileNameLength = Int(try data.readUInt16LE(at: offset + 28))
        let extraLength = Int(try data.readUInt16LE(at: offset + 30))
        let commentLength = Int(try data.readUInt16LE(at: offset + 32))
        let localHeaderOffset = Int(try data.readUInt32LE(at: offset + 42))

        let nameOffset = offset + 46
        let fileName = try data.readString(at: nameOffset, length: fileNameLength)

        entries.append(
            ZIPEntry(
                fileName: fileName,
                compressionMethod: compressionMethod,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                localHeaderOffset: localHeaderOffset
            )
        )

        offset = nameOffset + fileNameLength + extraLength + commentLength
        guard offset <= data.count else { throw FuelError.unzippingFailed }
    }

    return entries
}

nonisolated private func extractEntryData(_ entry: ZIPEntry, from data: Data) throws -> Data {
    let localHeaderOffset = entry.localHeaderOffset
    let signature = try data.readUInt32LE(at: localHeaderOffset)
    guard signature == 0x0403_4B50 else { throw FuelError.unzippingFailed }

    let fileNameLength = Int(try data.readUInt16LE(at: localHeaderOffset + 26))
    let extraLength = Int(try data.readUInt16LE(at: localHeaderOffset + 28))
    let dataStart = localHeaderOffset + 30 + fileNameLength + extraLength
    let dataEnd = dataStart + entry.compressedSize
    guard dataStart >= 0, dataEnd <= data.count else { throw FuelError.unzippingFailed }

    let payload = data.subdata(in: dataStart..<dataEnd)
    switch entry.compressionMethod {
    case 0:
        return payload
    case 8:
        return try inflateDeflatedData(payload, uncompressedSize: entry.uncompressedSize)
    default:
        throw FuelError.unzippingFailed
    }
}

nonisolated private func inflateDeflatedData(_ data: Data, uncompressedSize: Int) throws -> Data {
    guard uncompressedSize > 0 else { throw FuelError.unzippingFailed }
    var output = Data(count: uncompressedSize)
    let decodedCount = output.withUnsafeMutableBytes { outputBuffer -> Int in
        data.withUnsafeBytes { inputBuffer -> Int in
            guard let outputBase = outputBuffer.bindMemory(to: UInt8.self).baseAddress,
                  let inputBase = inputBuffer.bindMemory(to: UInt8.self).baseAddress
            else { return 0 }
            return compression_decode_buffer(
                outputBase,
                outputBuffer.count,
                inputBase,
                inputBuffer.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
    }

    guard decodedCount == uncompressedSize else { throw FuelError.unzippingFailed }
    output.count = decodedCount
    return output
}

nonisolated private func findEndOfCentralDirectoryOffset(in data: Data) throws -> Int {
    let minSize = 22
    guard data.count >= minSize else { throw FuelError.unzippingFailed }

    let maxCommentLength = 65_535
    let start = data.count - minSize
    let end = max(0, start - maxCommentLength)

    for offset in stride(from: start, through: end, by: -1) {
        if (try? data.readUInt32LE(at: offset)) == 0x0605_4B50 {
            return offset
        }
    }

    throw FuelError.unzippingFailed
}
