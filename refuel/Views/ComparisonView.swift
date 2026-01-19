//
//  ComparisonView.swift
//  refuel
//
//  Created by Codex on 2026-01-21.
//

import SwiftUI

struct ComparisonView: View {
    @State private var viewModel: ComparisonViewModel

    @MainActor
    init(viewModel: ComparisonViewModel? = nil) {
        if let viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            _viewModel = State(initialValue: ComparisonViewModel())
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView

                VStack(spacing: 20) {
                    header

                    if viewModel.isLoading {
                        ProgressView("Analyse des prix...")
                    } else {
                        comparisonGrid
                    }

                    if let recommendation = viewModel.recommendation {
                        GlassCard {
                            Text(recommendation)
                                .font(.headline)
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 16)
                    }

                    if let error = viewModel.errorMessage {
                        ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle.fill", description: Text(error))
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("Comparaison Prix")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.loadComparison() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                if !isPreview {
                    await viewModel.loadComparison()
                }
            }
        }
    }

    private var header: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Comparaison Maison / Travail")
                    .font(.title2.weight(.bold))
                Text(String(format: "Meilleurs prix dans un rayon de %.0f km pour votre carburant.", viewModel.comparisonRadius))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
    }

    private var comparisonGrid: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 12) {
                Label("Maison", systemImage: "house.fill")
                    .font(.headline)
                if let best = viewModel.bestNearHome {
                    StationMiniCard(station: best, fuelType: viewModel.fuelType)
                } else {
                    emptyCard(text: "Aucun lieu domicile")
                }
            }

            Divider()
                .frame(height: 180)

            VStack(spacing: 12) {
                Label("Travail", systemImage: "briefcase.fill")
                    .font(.headline)
                if let best = viewModel.bestNearWork {
                    StationMiniCard(station: best, fuelType: viewModel.fuelType)
                } else {
                    emptyCard(text: "Aucun lieu travail")
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func emptyCard(text: String) -> some View {
        GlassCard(cornerRadius: 16) {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color.green.opacity(0.12),
                Color.orange.opacity(0.12),
                Color.blue.opacity(0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

#Preview {
    ComparisonView(viewModel: ComparisonViewModel())
}
