//
//  ContentView.swift
//  refuel
//
//  Created by Florian Taffin on 17/01/2026.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showOnboarding = false
    @State private var hasCheckedProfile = false
    
    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView()
            } else {
                mainTabView
            }
        }
        .task {
            // Check profile in background, don't block UI
            if !hasCheckedProfile {
                hasCheckedProfile = true
                let profiles = try? modelContext.fetch(FetchDescriptor<UserProfile>())
                if profiles?.isEmpty ?? true {
                    showOnboarding = true
                }
            }
        }
    }
    
    private var mainTabView: some View {
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
