import SwiftUI

/// The fills a mini window is drawn with, so a round can change the canvas, the cards and their
/// edges and judge the whole window. `.echo` is what Echo uses today (ColorTokens.Workspace).
struct LabWKSurfaces {
    var canvas: Color = ColorTokens.Workspace.canvas
    /// The editor and results cards.
    var card: Color = ColorTokens.Workspace.card
    /// The tree and inspector cards (today the same as `card`).
    var sideCard: Color = ColorTokens.Workspace.card
    var edge: Color = ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity)
    var edgeWidth: CGFloat = LayoutTokens.Workspace.cardEdgeWidth
    /// A light line along the top inside edge, as a lit edge.
    var topHighlight: Color?
    var shadowOpacity: Double = 0.12
    var shadowRadius: CGFloat = 10

    static let echo = LabWKSurfaces()
}

/// A card with explicit surfaces, for rounds that judge the surfaces themselves.
struct LabWKCard: ViewModifier {
    var fill: Color
    var surfaces: LabWKSurfaces
    @Environment(\.workspaceCardCornerRadius) private var cornerRadius

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .clipShape(shape)
            .background {
                shape.fill(fill).shadow(color: .black.opacity(surfaces.shadowOpacity), radius: surfaces.shadowRadius, y: 4)
            }
            .overlay {
                shape.strokeBorder(surfaces.edge, lineWidth: surfaces.edgeWidth).allowsHitTesting(false)
            }
            .overlay {
                if let highlight = surfaces.topHighlight {
                    shape.strokeBorder(LinearGradient(colors: [highlight, .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
                        .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    func labWKCard(_ fill: Color, _ surfaces: LabWKSurfaces) -> some View { modifier(LabWKCard(fill: fill, surfaces: surfaces)) }
}

/// A whole Echo window in miniature: toolbar, the rail with its tool pill, the tree card, the tab
/// strip, a tab's content and the inspector. Each part can be hidden or replaced.
struct LabWKWindow<Content: View>: View {
    var surfaces = LabWKSurfaces.echo
    var showsTree = true
    var showsInspector = true
    var tabs = ["Query 1", "Query 2"]
    var activeTab = 0
    var toolbarTrailing: AnyView?
    var railTools: AnyView?
    var tree: AnyView?
    var inspector: AnyView?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            toolbar
            HStack(alignment: .top, spacing: SpacingTokens.xs) {
                rail
                if showsTree {
                    (tree ?? AnyView(LabSHCard(server: .production, look: .today, rowLimit: 6)))
                        .frame(width: SpacingTokens.xxxl * 3)
                }
                VStack(spacing: SpacingTokens.xs) {
                    LabWKTabStrip(tabs: tabs, active: activeTab)
                    content
                }
                if showsInspector {
                    (inspector ?? AnyView(LabWKNoSelection()))
                        .frame(width: SpacingTokens.xxxl * 2 + SpacingTokens.xl, alignment: .topLeading)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .labWKCard(surfaces.sideCard, surfaces)
                }
            }
        }
        .padding(SpacingTokens.xs)
        .background(surfaces.canvas)
    }

    private var toolbar: some View {
        HStack(spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.xxs2) {
                ForEach([ColorTokens.Status.error, ColorTokens.Status.warning, ColorTokens.Status.success], id: \.self) {
                    Circle().fill($0).frame(width: SpacingTokens.sm, height: SpacingTokens.sm)
                }
            }
            LabWKToolbarGroup(symbols: ["sidebar.left"])
            LabWKToolbarGroup(symbols: ["shippingbox.fill", "clock", "bolt.fill"])
            Spacer()
            toolbarTrailing ?? AnyView(LabWKToolbarGroup(symbols: ["square.grid.2x2", "arrow.clockwise", "bell", "sidebar.right"]))
        }
        .padding(.horizontal, SpacingTokens.xxs)
        .frame(height: SpacingTokens.xl)
    }

    private var rail: some View {
        VStack {
            VStack(spacing: SpacingTokens.xs) {
                Text("DP").font(TypographyTokens.caption2.weight(.bold)).foregroundStyle(ColorTokens.accent)
                    .frame(width: SpacingTokens.lg2, height: SpacingTokens.lg2)
                    .background(ColorTokens.Workspace.railSelection, in: Circle())
                Image(systemName: "plus").font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                    .frame(height: SpacingTokens.lg)
            }
            .padding(SpacingTokens.xxs)
            .glassEffect(.regular, in: .capsule)
            Spacer()
            railTools ?? AnyView(LabWKRailTools())
        }
        .frame(width: SpacingTokens.xl2)
    }
}

/// The rail's bottom pill as built: Bookmarks, Snippets, History and Clipboard.
struct LabWKRailTools: View {
    var selected: Int?
    var body: some View {
        VStack(spacing: SpacingTokens.xxs) {
            ForEach(Array(["bookmark", "curlybraces", "clock", "list.clipboard"].enumerated()), id: \.offset) { index, symbol in
                Image(systemName: symbol).font(TypographyTokens.standard)
                    .foregroundStyle(selected == index ? ColorTokens.accent : ColorTokens.Text.secondary)
                    .frame(width: SpacingTokens.lg2, height: SpacingTokens.lg2)
            }
        }
        .padding(SpacingTokens.xxs)
        .glassEffect(.regular, in: .capsule)
    }
}

/// A toolbar group: glass capsule with symbols.
struct LabWKToolbarGroup: View {
    let symbols: [String]
    var tints: [Int: Color] = [:]
    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { index, symbol in
                Image(systemName: symbol).font(TypographyTokens.standard)
                    .foregroundStyle(tints[index] ?? ColorTokens.Text.primary)
                    .frame(width: SpacingTokens.md2)
            }
        }
        .padding(.horizontal, SpacingTokens.xs2)
        .frame(height: SpacingTokens.lg2 - SpacingTokens.xxxs)
        .glassEffect(.regular, in: .capsule)
    }
}

/// The tab strip: a grey plate with the active tab raised, and the + button.
struct LabWKTabStrip: View {
    var tabs: [String]
    var active = 0
    var symbol = "tablecells"
    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.none) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                    Label(title, systemImage: index == 0 || tabs.count == 2 ? symbol : "gearshape")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(index == active ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                        .frame(maxWidth: .infinity).frame(height: SpacingTokens.lg)
                        .background { if index == active { Capsule().fill(ColorTokens.Workspace.card).shadow(ShadowTokens.railSelection) } }
                }
            }
            .padding(SpacingTokens.xxxs)
            .background(ColorTokens.Sidebar.hoverFill, in: Capsule())
            Image(systemName: "plus").font(TypographyTokens.standard)
                .frame(width: SpacingTokens.lg2 - SpacingTokens.xxxs, height: SpacingTokens.lg2 - SpacingTokens.xxxs)
                .glassEffect(.regular, in: Circle())
        }
    }
}

/// The inspector's empty state, as built: "No Selection" and a line of help.
struct LabWKNoSelection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text("No Selection").font(TypographyTokens.standard.weight(.semibold))
            Text("Select an object, a cell or a row to inspect its details.")
                .font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
