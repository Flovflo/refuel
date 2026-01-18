//
//  FuelStation.swift
//  refuel
//
//  Created by Codex on 2026-01-18.
//

import Foundation
import CoreLocation

struct FuelStation: Identifiable, Codable, Hashable {
    let id: String
    let address: String?
    let city: String?
    let postalCode: String?
    let latitude: Double
    let longitude: Double
    var prices: [FuelPrice]
    var services: [String]
    var isOpen24h: Bool
    
    // Distance from user (calculated at runtime)
    var distanceKm: Double?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var cheapestPrice: Double? {
        prices.map(\.price).min()
    }
    
    var cheapestGazole: Double? {
        prices.first(where: { $0.fuelType == .gazole })?.price
    }
}

extension FuelStation {
    enum CodingKeys: String, CodingKey {
        case id
        case address
        case city
        case postalCode = "cp"
        case latitude
        case longitude
        case prices
        case services
        case isOpen24h
        case distanceKm = "distance"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        postalCode = try container.decodeIfPresent(String.self, forKey: .postalCode)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude) ?? 0
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude) ?? 0
        prices = try container.decodeIfPresent([FuelPrice].self, forKey: .prices) ?? []
        services = try container.decodeIfPresent([String].self, forKey: .services) ?? []
        isOpen24h = try container.decodeIfPresent(Bool.self, forKey: .isOpen24h) ?? false
        distanceKm = try container.decodeIfPresent(Double.self, forKey: .distanceKm)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(city, forKey: .city)
        try container.encodeIfPresent(postalCode, forKey: .postalCode)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(prices, forKey: .prices)
        try container.encode(services, forKey: .services)
        try container.encode(isOpen24h, forKey: .isOpen24h)
        try container.encodeIfPresent(distanceKm, forKey: .distanceKm)
    }

    static func == (lhs: FuelStation, rhs: FuelStation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
