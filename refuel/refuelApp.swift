//
//  refuelApp.swift
//  refuel
//
//  Created by Florian Taffin on 17/01/2026.
//

import SwiftData
import SwiftUI

@main
struct refuelApp: App {
    private let persistenceManager = PersistenceManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(persistenceManager.container)
        }
    }
}
