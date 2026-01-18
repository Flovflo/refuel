//
//  ContentView.swift
//  refuel
//
//  Created by Florian Taffin on 17/01/2026.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            StationListView()
                .tabItem {
                    Label("Liste", systemImage: "list.bullet")
                }

            MapView()
                .tabItem {
                    Label("Carte", systemImage: "map")
                }
        }
        .tint(.orange)
    }
}

#Preview {
    ContentView()
        .modelContainer(PersistenceManager(inMemory: true).container)
}
