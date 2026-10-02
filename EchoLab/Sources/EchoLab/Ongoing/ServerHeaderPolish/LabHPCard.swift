import SwiftUI

/// A server card with one of round 50's headers, the dock and the Databases rows.
struct LabHPCard: View {
    let server: LabSHServer
    let look: LabHPLook
    /// How many rows to draw; nil draws all of the server's databases.
    var rowLimit: Int?
    var selectedRow: String? = "ccsLDK10"
    @Environment(\.workspaceCardCornerRadius) private var cornerRadius
    @State private var isHovering = false

    private var palette: LabHPPalette { LabHPPalette(tint: server.color, strength: look.strength) }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            top
            VStack(spacing: SpacingTokens.none) {
                ForEach(rows, id: \.self) { LabSHRow(title: $0, isSelected: $0 == selectedRow) }
            }
            .padding(.bottom, SpacingTokens.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            if look.design == .spine {
                palette.ink.frame(width: SpacingTokens.xxs).allowsHitTesting(false)
            }
        }
        .workspaceCard()
        .onHover { isHovering = $0 }
    }

    /// The header and the dock; the colour is behind both, or behind the header only.
    @ViewBuilder
    private var top: some View {
        let header = LabHPHeader(server: server, look: look, showsChevron: isHovering)
        let dock = LabHPDockBar(look: look, palette: palette)
        if look.coversDock {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs2) { header; dock }
                .padding(.bottom, look.design == .wash || look.design == .aurora ? SpacingTokens.xxs2 : SpacingTokens.xxs2)
                .background { LabHPBackdrop(design: look.design, palette: palette).allowsHitTesting(false) }
        } else {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                header.background { LabHPBackdrop(design: look.design, palette: palette).allowsHitTesting(false) }
                dock
            }
        }
    }

    private var rows: [String] { rowLimit.map { Array(server.rows.prefix($0)) } ?? server.rows }
}

/// The tree's column with the cards stacked, as Echo lays them out.
struct LabHPColumn<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: SpacingTokens.xs) { content }
            .padding(SpacingTokens.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(ColorTokens.Workspace.canvas)
    }
}

/// Every design on the chosen server, a family at a time.
struct LabHPGallery: View {
    let look: LabHPLook
    let server: LabSHServer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                ForEach(LabHPFamily.allCases, id: \.self) { family in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        Text(family.title).font(TypographyTokens.standard.weight(.semibold)).foregroundStyle(ColorTokens.Text.primary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sm, alignment: .top), count: 2),
                                  alignment: .leading, spacing: SpacingTokens.sm) {
                            ForEach(family.designs, id: \.self) { design in
                                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                                    Text(design.rawValue).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                                    LabHPCard(server: server, look: look.with(design), rowLimit: 1, selectedRow: nil)
                                }
                            }
                        }
                    }
                }
            }
            .padding(SpacingTokens.sm)
        }
        .labScrollSizing()
        .background(ColorTokens.Workspace.canvas)
    }
}

/// The same header in every typeface, on the chosen design.
struct LabHPTypefaces: View {
    let look: LabHPLook
    let server: LabSHServer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                ForEach(LabHPFace.allCases, id: \.self) { face in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        Text(face.rawValue).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                        LabHPCard(server: server, look: look.with(face), rowLimit: 0, selectedRow: nil)
                    }
                }
            }
            .padding(SpacingTokens.sm)
        }
        .labScrollSizing()
        .background(ColorTokens.Workspace.canvas)
    }
}
