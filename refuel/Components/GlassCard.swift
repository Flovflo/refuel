//
//  GlassCard.swift
//  refuel
//
//  Created by Codex on 2026-01-18.
//

import SwiftUI

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 22
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.45),
                                        .white.opacity(0.15),
                                        .white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.cyan.opacity(0.35), .orange.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
        GlassCard {
            Text("Glass Card Preview")
                .foregroundStyle(.primary)
        }
    }
}
