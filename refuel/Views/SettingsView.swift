//
//  SettingsView.swift
//  refuel
//
//  Created by Codex on 2026-01-21.
//

import MapKit
import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel

    @MainActor
    init(viewModel: SettingsViewModel? = nil) {
        if let viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            _viewModel = State(initialValue: SettingsViewModel())
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView

                ScrollView {
                    VStack(spacing: 20) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Lieux favoris", systemImage: "mappin.and.ellipse")
                                    .font(.headline)
                                Text("Definissez votre domicile et votre travail pour comparer les prix.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        addressSection(
                            title: "Domicile",
                            placeholder: "Adresse ou ville",
                            text: Binding(
                                get: { viewModel.homeQuery },
                                set: { viewModel.updateHomeQuery($0) }
                            ),
                            completions: viewModel.homeCompletions,
                            onSelect: viewModel.selectHomeCompletion,
                            onClear: viewModel.clearHome
                        )

                        addressSection(
                            title: "Travail",
                            placeholder: "Adresse ou ville",
                            text: Binding(
                                get: { viewModel.workQuery },
                                set: { viewModel.updateWorkQuery($0) }
                            ),
                            completions: viewModel.workCompletions,
                            onSelect: viewModel.selectWorkCompletion,
                            onClear: viewModel.clearWork
                        )

                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Rayon comparaison", systemImage: "scope")
                                    .font(.headline)
                                Slider(value: $viewModel.comparisonRadius, in: 5...25, step: 1)
                                Text(String(format: "%.0f km", viewModel.comparisonRadius))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let error = viewModel.errorMessage {
                            ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle.fill", description: Text(error))
                        }

                        Button {
                            Task { await viewModel.save() }
                        } label: {
                            if viewModel.isSaving {
                                ProgressView()
                            } else {
                                Text("Sauvegarder")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                }
            }
            .navigationTitle("Profil")
        }
    }

    private func addressSection(
        title: String,
        placeholder: String,
        text: Binding<String>,
        completions: [MKLocalSearchCompletion],
        onSelect: @escaping (MKLocalSearchCompletion) -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Button("Effacer") { onClear() }
                        .font(.caption)
                }

                TextField(placeholder, text: text)
                    .textInputAutocapitalization(.words)

                if !completions.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(completions, id: \.fullText) { completion in
                            Button {
                                onSelect(completion)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(completion.title)
                                        .font(.subheadline)
                                    if !completion.subtitle.isEmpty {
                                        Text(completion.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color.blue.opacity(0.12),
                Color.orange.opacity(0.12),
                Color.cyan.opacity(0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel())
}
