import SwiftUI

/// A server card in one of round 50's forms: the header, the icon menu and the Databases rows.
/// Click an icon to switch section: the header's right side and eyebrow follow.
struct LabHRCard: View {
    let server: LabSHServer
    let look: LabHRLook
    /// How many rows to draw; nil draws all of the server's databases.
    var rowLimit: Int?
    var selectedRow: String? = "ccsLDK10"
    @State private var section = LabHRSection.databases
    @State private var isHovering = false
    @Environment(\.workspaceCardCornerRadius) private var cornerRadius
    @Environment(\.colorScheme) private var scheme

    private var palette: LabHRPalette { LabHRPalette(tint: look.tint(for: server, scheme: scheme), tone: look.tone) }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            top.zIndex(1)
            VStack(spacing: SpacingTokens.none) {
                ForEach(rows, id: \.self) { LabSHRow(title: $0, isSelected: $0 == selectedRow) }
            }
            .padding(.bottom, SpacingTokens.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .workspaceCard()
        .onHover { isHovering = $0 }
    }

    private var rows: [String] { rowLimit.map { Array(server.rows.prefix($0)) } ?? server.rows }

    private var header: LabHRHeader { LabHRHeader(server: server, look: look, section: section, showsChevron: isHovering) }

    private var dock: LabHRDockBar {
        LabHRDockBar(treatment: look.dock, iconStyle: look.icon, pillShape: look.pill, tint: palette.ink, onColour: look.dockOnColour, surface: palette.fill, selected: $section)
    }

    private var panelRadius: CGFloat { max(cornerRadius - SpacingTokens.xxs1, SpacingTokens.xxs2) }

    /// The header and the dock; the colour is behind both, or behind the header only.
    @ViewBuilder
    private var top: some View {
        switch look.form.surface {
        case .none:
            VStack(alignment: .leading, spacing: SpacingTokens.xxs2) { header; dock }
        case .banner, .wash:
            if look.reach == .dock {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs2) { header; dock }
                    .padding(.bottom, SpacingTokens.xxs2 + look.edge.extraBottom)
                    .background { LabHRBackdrop(form: look.form, palette: palette, edge: look.edge).allowsHitTesting(false) }
            } else {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                    header.background { LabHRBackdrop(form: look.form, palette: palette, edge: look.edge).allowsHitTesting(false) }
                    dock
                }
            }
        case .inset:
            if look.reach == .dock {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs2) { header; dock }
                    .padding(.bottom, SpacingTokens.xxs2)
                    .background(palette.banner, in: RoundedRectangle(cornerRadius: panelRadius, style: .continuous))
                    .padding(.horizontal, SpacingTokens.xxs1).padding(.top, SpacingTokens.xxs1)
            } else {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                    header
                        .background(palette.banner, in: RoundedRectangle(cornerRadius: panelRadius, style: .continuous))
                        .padding(.horizontal, SpacingTokens.xxs1).padding(.top, SpacingTokens.xxs1)
                    dock
                }
            }
        }
    }
}

/// The tree's column with the cards stacked, as Echo lays them out.
struct LabHRColumn<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: SpacingTokens.xs) { content }
            .padding(SpacingTokens.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(ColorTokens.Workspace.canvas)
    }
}

/// Every form on the chosen server, two to a row.
struct LabHRFormGallery: View {
    let look: LabHRLook
    let server: LabSHServer

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sm, alignment: .top), count: 2),
                      alignment: .leading, spacing: SpacingTokens.md) {
                ForEach(LabHRForm.allCases, id: \.self) { form in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        Text(form.rawValue).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        LabHRCard(server: server, look: look.with(form: form), rowLimit: 1, selectedRow: nil)
                    }
                }
            }
            .padding(SpacingTokens.sm)
        }
        .labScrollSizing()
        .background(ColorTokens.Workspace.canvas)
    }
}

/// The chosen form with each icon menu treatment, two to a row.
struct LabHRDockGallery: View {
    let look: LabHRLook
    let server: LabSHServer

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sm, alignment: .top), count: 2),
                      alignment: .leading, spacing: SpacingTokens.md) {
                ForEach(LabHRDock.allCases, id: \.self) { dock in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        Text(dock.rawValue).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        LabHRCard(server: server, look: look.with(dock: dock), rowLimit: 0, selectedRow: nil)
                    }
                }
            }
            .padding(SpacingTokens.sm)
        }
        .labScrollSizing()
        .background(ColorTokens.Workspace.canvas)
    }
}


/// Every colour a user could pick, as the chosen header, in this appearance. Switch light and dark
/// in the toolbar to judge each.
struct LabHRColourGallery: View {
    let look: LabHRLook
    let server: LabSHServer

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sm, alignment: .top), count: 3),
                      alignment: .leading, spacing: SpacingTokens.md) {
                ForEach(LabHRColour.palette, id: \.self) { colour in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        Text(colour.rawValue).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                        LabHRCard(server: server, look: look.with(colour: colour), rowLimit: 0, selectedRow: nil)
                    }
                }
            }
            .padding(SpacingTokens.sm)
        }
        .labScrollSizing()
        .background(ColorTokens.Workspace.canvas)
    }
}

/// Every colour in light and dark side by side, whatever the lab's own appearance is.
struct LabHRColourPairs: View {
    let look: LabHRLook
    let server: LabSHServer

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SpacingTokens.sm) {
                ForEach(LabHRColour.palette, id: \.self) { colour in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        Text(colour.rawValue).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                        HStack(spacing: SpacingTokens.sm) {
                            pane(colour, .light)
                            pane(colour, .dark)
                        }
                    }
                }
            }
            .padding(SpacingTokens.sm)
        }
        .labScrollSizing()
        .background(ColorTokens.Workspace.canvas)
    }

    private func pane(_ colour: LabHRColour, _ scheme: ColorScheme) -> some View {
        LabHRCard(server: server, look: look.with(colour: colour), rowLimit: 0, selectedRow: nil)
            .padding(SpacingTokens.xs)
            .background(ColorTokens.Workspace.canvas)
            .environment(\.colorScheme, scheme)
    }
}


/// The proposal with one setting varied, a card per choice: the edges, the typefaces, the icons.
struct LabHRVariantGallery: View {
    let variants: [(title: String, look: LabHRLook)]
    let server: LabSHServer
    var columns = 2

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sm, alignment: .top), count: columns),
                      alignment: .leading, spacing: SpacingTokens.md) {
                ForEach(Array(variants.enumerated()), id: \.offset) { _, variant in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        Text(variant.title).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        LabHRCard(server: server, look: variant.look, rowLimit: 1, selectedRow: nil)
                    }
                }
            }
            .padding(SpacingTokens.sm)
        }
        .labScrollSizing()
        .background(ColorTokens.Workspace.canvas)
    }
}
