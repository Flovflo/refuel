//
//  FuelDataService.swift
//  refuel
//
//  Created by Codex on 2026-01-18.
//

import Foundation
import OSLog

enum FuelError: LocalizedError {
    case invalidURL
    case missingLocation
    case networkError(Error)
    case invalidResponse(Int)
    case decodingError(Error)
    case analysisUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .missingLocation:
            return "Unable to determine your location."
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)"
        case .invalidResponse(let statusCode):
            return "Unexpected server response (\(statusCode))"
        case .decodingError(let error):
            return "Failed to decode stations: \(error.localizedDescription)"
        case .analysisUnavailable:
            return "Price analysis unavailable."
        }
    }
}

actor FuelDataService {
    private let baseURLString = "http://192.168.0.201:8000/stations"
    private static let stationDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    func fetchStations(latitude: Double, longitude: Double, radius: Double) async throws -> [FuelStation] {
        guard var components = URLComponents(string: baseURLString) else {
            throw FuelError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.6f", latitude)),
            URLQueryItem(name: "lon", value: String(format: "%.6f", longitude)),
            URLQueryItem(name: "radius", value: String(format: "%.2f", radius))
        ]

        guard let url = components.url else {
            throw FuelError.invalidURL
        }

        Logger.network.info("Fetching stations: \(url.absoluteString, privacy: .public)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw FuelError.networkError(error)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw FuelError.invalidResponse(httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(Self.stationDateFormatter)
            let stations = try decoder.decode([FuelStation].self, from: data)
            Logger.network.info("Fetch complete, found \(stations.count, privacy: .public) stations")
            Task.detached(priority: .background) {
                await PersistenceManager.shared.recordPriceHistory(for: stations)
            }
            return stations
        } catch {
            throw FuelError.decodingError(error)
        }
    }

    func fetchPriceAnalysis(stationId: String, fuelType: FuelType) async throws -> PriceAnalysis? {
        let endpoint = "\(baseURLString)/\(stationId)/price-analysis"
        guard var components = URLComponents(string: endpoint) else {
            throw FuelError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "fuel_type", value: fuelType.rawValue)
        ]

        guard let url = components.url else {
            throw FuelError.invalidURL
        }

        Logger.network.info("Fetching price analysis: \(url.absoluteString, privacy: .public)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw FuelError.networkError(error)
        }

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 404 {
                return nil
            }
            if !(200...299).contains(httpResponse.statusCode) {
                throw FuelError.invalidResponse(httpResponse.statusCode)
            }
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(PriceAnalysis.self, from: data)
        } catch {
            if let errorResponse = try? JSONDecoder().decode(PriceAnalysisErrorResponse.self, from: data),
               !errorResponse.error.isEmpty {
                return nil
            }
            throw FuelError.decodingError(error)
        }
    }
}

private struct PriceAnalysisErrorResponse: Codable {
    let error: String
}
