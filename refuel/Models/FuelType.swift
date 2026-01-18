//
//  FuelType.swift
//  refuel
//
//  Created by Codex on 2026-01-18.
//

import SwiftUI

enum FuelType: String, CaseIterable, Codable, Identifiable {
    case gazole = "Gazole"
    case sp95 = "SP95"
    case sp98 = "SP98"
    case e10 = "E10"
    case e85 = "E85"
    case gplc = "GPLc"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .gazole: return "fuelpump.fill"
        case .e85: return "leaf.fill"
        case .gplc: return "bolt.fill"
        default: return "fuelpump"
        }
    }
    
    var color: Color {
        switch self {
        case .gazole: return .yellow
        case .e85: return .green
        case .gplc: return .purple
        case .sp95, .sp98, .e10: return .blue
        }
    }
}
