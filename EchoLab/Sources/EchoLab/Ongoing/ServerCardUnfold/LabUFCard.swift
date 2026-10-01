import SwiftUI

/// A server card that opens, closes and switches sections, laid out from Echo's fixed slots
/// (a 49pt header, a 37pt dock, 29pt rows and 4pt below), with the header's wash (HD4) in the
/// server's colour. Click the header to open or close it, a dock icon to switch section. Opening
/// and closing follow round 46's choices (LabUFCard+Choreography); a section switch is always
/// Echo's (round 19, S3): the veil in, the edge settling, the veil out.
struct LabUFCard: View {
    let look: LabUFLook
    var title = "dkloosql10-p"
    var product = "SQL Server 2017"
    var tint: Color = ColorTokens.Status.error
    var startsOpen = true
    /// Changing these replays a close and open, or switches to the next section.
    var pulse: String = ""
    var switchPulse: String = ""

    @Environment(\.echoMotion) var motion
    @Environment(\.workspaceCardCornerRadius) private var cornerRadius
    @State var section: LabUFSection = .databases
    @State var cardOpen = true
    @State var dockShown = true
    @State var iconsShown = true
    @State var rowsShown = true
    @State var veil: Double = 0
    @State var generation = 0
    @State private var isHovering = false

    static let headerHeight = SpacingTokens.lg + SpacingTokens.xxs1 + SpacingTokens.xs + SpacingTokens.sm
    static let dockHeight = SpacingTokens.lg + SpacingTokens.xxs1 + SpacingTokens.xs
    static let rowHeight = SpacingTokens.lg + SpacingTokens.xxs1
    static let bottomPadding = SpacingTokens.xxs

    private var rowsHeight: CGFloat { CGFloat(section.rows.count) * Self.rowHeight }
    private var height: CGFloat {
        Self.headerHeight + (cardOpen ? Self.dockHeight + rowsHeight : SpacingTokens.none) + Self.bottomPadding
    }
    /// Echo today draws the rows over the canvas while the edge moves; every proposal cuts them.
    private var clipsContent: Bool { look.rows != .atOnce }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack(alignment: .top) {
            shape.fill(ColorTokens.Workspace.card)
                .shadow(ShadowTokens.workspaceCard)
                .overlay { shape.strokeBorder(ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity), lineWidth: LayoutTokens.Workspace.cardEdgeWidth) }
                .frame(height: height)
            LinearGradient(colors: [tint.opacity(0.2), tint.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: cardOpen ? Self.headerHeight + Self.dockHeight : height)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: cornerRadius, bottomLeadingRadius: cardOpen ? 0 : cornerRadius,
                                                  bottomTrailingRadius: cardOpen ? 0 : cornerRadius, topTrailingRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: SpacingTokens.none) {
                header.frame(height: Self.headerHeight)
                dock.frame(height: Self.dockHeight)
                rows
            }
            .frame(height: clipsContent ? height : nil, alignment: .top)
            .clipShape(clipsContent ? AnyShape(shape) : AnyShape(Rectangle().inset(by: -SpacingTokens.xxxl * 4)))
        }
        .frame(height: height, alignment: .top)
        .onHover { isHovering = $0 }
        .onAppear { if !startsOpen { setClosedAtOnce() } }
        .onChange(of: pulse) { _, _ in replay() }
        .onChange(of: switchPulse) { _, _ in switchSection(to: LabUFSection(rawValue: (section.rawValue + 1) % LabUFSection.allCases.count) ?? .databases) }
    }

    private var header: some View {
        Button { toggle() } label: {
            HStack(alignment: .center, spacing: SidebarRowConstants.iconTextSpacing) {
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(title).font(SidebarRowConstants.serverHeaderFont).foregroundStyle(ColorTokens.Text.primary).lineLimit(1)
                    Text("\(product) · \(section.title)").font(SidebarRowConstants.trailingFont).foregroundStyle(ColorTokens.Text.tertiary).lineLimit(1)
                }
                Spacer(minLength: SpacingTokens.xxs)
                Image(systemName: "chevron.right")
                    .font(SidebarRowConstants.sectionChevronFont)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .rotationEffect(.degrees(cardOpen ? 90 : 0))
                    .opacity(isHovering || !cardOpen ? 1 : 0)
            }
            .padding(.horizontal, SpacingTokens.sm)
            // Open, the lines sit 12pt down; closed, they are centred in the card (round 30.2).
            .padding(.top, cardOpen ? SpacingTokens.sm : Self.bottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: cardOpen ? .topLeading : .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var dock: some View {
        HStack(spacing: SpacingTokens.none) {
            ForEach(Array(LabUFSection.allCases.enumerated()), id: \.offset) { index, item in
                Button { switchSection(to: item) } label: {
                    Image(systemName: item.symbol)
                        .font(TypographyTokens.prominent.weight(.medium))
                        .foregroundStyle(item == section ? AnyShapeStyle(tint) : AnyShapeStyle(ColorTokens.Sidebar.symbol))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(iconsShown ? 1 : 0)
                .animation(look.dock == .unfold ? iconAnimation(index) : nil, value: iconsShown)
            }
        }
        .padding(.horizontal, SpacingTokens.xxs2)
        .frame(height: SpacingTokens.lg + SpacingTokens.xxs)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
        .modifier(LabUFDockArrival(style: look.dock, isShown: dockShown))
    }

    private var rows: some View {
        VStack(spacing: SpacingTokens.none) {
            ForEach(Array(section.rows.enumerated()), id: \.offset) { index, row in
                LabSHRow(title: row.title, isSelected: false, symbol: row.symbol, tint: ColorTokens.Status.info)
                    .frame(height: Self.rowHeight)
                    .opacity(rowsShown ? 1 : 0)
                    .offset(y: look.rows == .cascade && !rowsShown ? -SpacingTokens.xxs : SpacingTokens.none)
                    .animation(look.rows == .cascade ? rowAnimation(index) : nil, value: rowsShown)
            }
        }
        .overlay { ColorTokens.Workspace.card.opacity(veil).allowsHitTesting(false) }
    }
}

/// How the capsule looks before it has arrived, for each dock choice.
private struct LabUFDockArrival: ViewModifier {
    let style: LabUFDock
    let isShown: Bool

    func body(content: Content) -> some View {
        switch style {
        case .atOnce, .fade:
            content.opacity(isShown ? 1 : 0)
        case .grow:
            // No fade: the glass keeps its blur from the first frame and the card's edge uncovers
            // it (the owner's note when accepting round 46).
            content
                .scaleEffect(isShown ? 1 : 0.92, anchor: .top)
                .blur(radius: isShown ? 0 : SpacingTokens.xxxs)
        case .slide:
            content.opacity(isShown ? 1 : 0)
                .offset(y: isShown ? 0 : -SpacingTokens.xs2)
        case .unfold:
            content.opacity(isShown ? 1 : 0)
                .scaleEffect(x: isShown ? 1 : 0.2, y: 1, anchor: .center)
        }
    }
}
