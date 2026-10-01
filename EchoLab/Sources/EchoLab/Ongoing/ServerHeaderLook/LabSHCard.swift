import SwiftUI

/// A server card as the tree draws it: the header in one of round 30.1's looks (colour that reaches
/// past the header behind the header and dock together, a top line on the card's edge), the dock and the
/// Databases section's rows (S4 Quiet: a blue cylinder and the name, 29pt slots at the default size).
struct LabSHCard: View {
    let server: LabSHServer
    let look: LabSHLook
    /// How many rows to draw; nil draws all of the server's databases.
    var rowLimit: Int?
    var selectedRow: String? = "ccsLDK10"
    /// Explicit surfaces (round 32); nil draws Echo's workspace card.
    var surfaces: LabWKSurfaces?
    @Environment(\.workspaceCardCornerRadius) private var cornerRadius
    @State private var isHovering = false

    var body: some View {
        let tint = look.color(for: server)
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                LabSHHeader(server: server, look: look, showsChevron: isHovering)
                LabSHDock(tint: look.dockColor(for: server))
            }
            // A cap or a fading banner ends a little below the dock, not on its edge.
            .padding(.bottom, look.style == .cap || look.style == .fadingBanner ? SpacingTokens.xxs2 : SpacingTokens.none)
            .background { LabSHTopBackdrop(look: look, tint: tint).allowsHitTesting(false) }
            VStack(spacing: SpacingTokens.none) {
                ForEach(rows, id: \.self) { LabSHRow(title: $0, isSelected: $0 == selectedRow) }
            }
            .padding(.bottom, SpacingTokens.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay { LabSHCardEdge(look: look, tint: tint).allowsHitTesting(false) }
        .modifier(LabSHCardSurface(surfaces: surfaces))
        .onHover { isHovering = $0 }
    }

    private var rows: [String] { rowLimit.map { Array(server.rows.prefix($0)) } ?? server.rows }
}

/// One database row: the duotone cylinder and the name; the selection is the system's grey fill.
struct LabSHRow: View {
    let title: String
    var isSelected = false
    var symbol = "cylinder"
    var tint: Color = ColorTokens.Status.info
    var indent: CGFloat = 0
    var trailing: String?
    var isDimmed = false

    var body: some View {
        HStack(spacing: SidebarRowConstants.iconTextSpacing) {
            Image(systemName: symbol)
                .font(SidebarRowConstants.iconFont)
                .foregroundStyle(tint)
                .frame(width: SidebarRowConstants.iconFrameWidth, height: SidebarRowConstants.iconFrameHeight)
            Text(title).font(TypographyTokens.standard).lineLimit(1)
                .foregroundStyle(isDimmed ? ColorTokens.Text.tertiary : ColorTokens.Text.primary)
            Spacer(minLength: SpacingTokens.xxs)
            if let trailing {
                Text(trailing).font(SidebarRowConstants.trailingFont).foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
        .padding(.leading, SidebarRowConstants.rowLeadingPadding + indent)
        .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
        .frame(height: SpacingTokens.lg + SpacingTokens.xxs1)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous)
                    .fill(ColorTokens.Sidebar.selectedFill)
            }
        }
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
    }
}

/// The tree's column: the canvas with the cards stacked, as Echo lays them out.
struct LabSHColumn<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: SpacingTokens.xs) { content }
            .padding(SpacingTokens.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(ColorTokens.Workspace.canvas)
    }
}

/// Echo's workspace card, or the card with a round's own surfaces.
private struct LabSHCardSurface: ViewModifier {
    let surfaces: LabWKSurfaces?
    func body(content: Content) -> some View {
        if let surfaces { content.labWKCard(surfaces.sideCard, surfaces) } else { content.workspaceCard() }
    }
}
