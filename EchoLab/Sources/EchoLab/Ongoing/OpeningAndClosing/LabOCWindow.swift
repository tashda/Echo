import SwiftUI

/// A small Echo window laid out as WorkspaceShell lays it out: the rail always at the leading
/// edge, the tree sliding out from behind it, the canvas page in the rest. With nothing connected
/// the tree has no space; connecting gives it some, and the canvas shrinks by that much, which
/// is what pushes today's welcome to the right.
struct LabOCWindow: View {
    let scene: LabOCScene

    @Environment(\.workspaceCardCornerRadius) private var cornerRadius

    private let gutter = SpacingTokens.sm
    private let treeWidth: CGFloat = 188
    private let itemSize = SpacingTokens.xl + SpacingTokens.micro

    var body: some View {
        HStack(spacing: SpacingTokens.none) {
            rail
                .padding(.leading, gutter)
                .zIndex(2)

            HStack(spacing: SpacingTokens.none) {
                tree
                main
                    .padding(.leading, scene.treeIn ? SpacingTokens.none : gutter)
                    .padding(.trailing, gutter)
            }
        }
        .padding(.vertical, gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Workspace.canvas)
        .overlay(alignment: .bottom) { caption }
        .clipShape(RoundedRectangle(cornerRadius: LayoutTokens.FloatingSurface.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LayoutTokens.FloatingSurface.cornerRadius, style: .continuous)
                .strokeBorder(ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity), lineWidth: LayoutTokens.Workspace.cardEdgeWidth)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Rail

    private var rail: some View {
        VStack {
            VStack(spacing: LayoutTokens.Rail.itemSpacing) {
                if scene.railServer {
                    Text(LabOCSample.recents[0].monogram)
                        .font(TypographyTokens.standard.weight(.bold))
                        .foregroundStyle(LabOCSample.recents[0].color)
                        .frame(width: itemSize, height: itemSize)
                        .background {
                            Circle().fill(ColorTokens.Workspace.railSelection).shadow(ShadowTokens.railSelection)
                                .padding(LayoutTokens.Rail.selectionInset)
                        }
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
                Image(systemName: "plus").font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                    .frame(width: itemSize, height: itemSize)
            }
            .padding(LayoutTokens.Rail.pillPadding)
            .glassEffect(.regular, in: .capsule)
            Spacer(minLength: SpacingTokens.none)
        }
        .frame(width: LayoutTokens.Rail.width(itemSize: itemSize))
    }

    // MARK: - Tree

    /// The tree slides out from behind the rail and fades in, and its space opens (WorkspaceShell.treeArea).
    private var tree: some View {
        HStack(spacing: SpacingTokens.none) {
            LabOCTreeCard()
                .frame(width: treeWidth)
                .padding(.leading, gutter)
            Color.clear.frame(width: gutter)
        }
        .offset(x: scene.treeIn || scene.motion.reduceMotion ? 0 : -(treeWidth + gutter))
        .opacity(scene.treeIn ? 1 : 0)
        .frame(width: scene.treeIn ? treeWidth + gutter * 2 : 0, alignment: .leading)
        .zIndex(1)
    }

    // MARK: - Canvas page

    private var main: some View {
        ZStack {
            LabOCWelcome(scene: scene)
                // LV1: cancel the push. The canvas' centre moves by half the space the tree takes.
                .offset(x: scene.welcomeHoldsPlace && scene.treeIn ? -(treeWidth + gutter) / 2 : 0)
            LabOCServerPage(scene: scene)
            LabOCTabLayer(scene: scene)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var caption: some View {
        Text(scene.caption)
            .font(TypographyTokens.detail.weight(.medium))
            .foregroundStyle(ColorTokens.Text.secondary)
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, SpacingTokens.xxs)
            .glassEffect(.regular, in: .capsule)
            .padding(.bottom, SpacingTokens.xs)
            .opacity(scene.captionShown ? 1 : 0)
    }
}

/// The server's card in the tree, with its dock and a few rows.
struct LabOCTreeCard: View {
    @Environment(\.workspaceCardCornerRadius) private var cornerRadius

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(LabOCSample.serverName).font(SidebarRowConstants.serverHeaderFont).foregroundStyle(ColorTokens.Text.primary)
                Text("\(LabOCSample.serverVersion) · Databases").font(SidebarRowConstants.trailingFont).foregroundStyle(ColorTokens.Text.tertiary)
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.top, SpacingTokens.sm)
            .frame(height: SpacingTokens.lg + SpacingTokens.xxs1 + SpacingTokens.xs + SpacingTokens.sm, alignment: .topLeading)
            ForEach(LabOCSample.databases, id: \.self) { name in
                LabSHRow(title: name, isSelected: false, symbol: "cylinder", tint: ColorTokens.Status.info)
                    .frame(height: SpacingTokens.lg + SpacingTokens.xxs1)
            }
            Spacer(minLength: SpacingTokens.none)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { shape.fill(ColorTokens.Workspace.card).shadow(ShadowTokens.workspaceCard) }
        .overlay { shape.strokeBorder(ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity), lineWidth: LayoutTokens.Workspace.cardEdgeWidth) }
        .clipShape(shape)
    }
}
