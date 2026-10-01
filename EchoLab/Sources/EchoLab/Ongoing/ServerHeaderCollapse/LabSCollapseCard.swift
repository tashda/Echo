import SwiftUI

/// A server card that opens and closes: click its header (or the chevron). The card's height is
/// laid out from fixed slots, as Echo's tree does, so each motion can move the edge on its own.
struct LabSCollapseCard: View {
    let server: LabSHServer
    let look: LabSCollapseLook
    @Binding var isOpen: Bool
    @Environment(\.echoMotion) private var motion
    @Environment(\.workspaceCardCornerRadius) private var cornerRadius
    @State private var isHovering = false

    private static let headerHeight: CGFloat = SpacingTokens.xxxl - SpacingTokens.xs   // 12 top + two lines + room
    private static let dockHeight: CGFloat = SpacingTokens.lg2 + SpacingTokens.xxs       // 28 capsule + 6 gap
    private static let rowHeight: CGFloat = SpacingTokens.lg + SpacingTokens.xxs1        // 29pt slot

    private var rowsHeight: CGFloat { Self.dockHeight + CGFloat(server.rows.count) * Self.rowHeight + SpacingTokens.xxs }
    private var closedExtra: CGFloat { look.closed == .dock ? Self.dockHeight : 0 }
    private var height: CGFloat { Self.headerHeight + (isOpen ? rowsHeight : closedExtra) }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack(alignment: .top) {
            // The card itself: today it changes size at once; every proposal glides.
            shape.fill(ColorTokens.Workspace.card)
                .shadow(ShadowTokens.workspaceCard)
                .overlay { shape.strokeBorder(ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity), lineWidth: LayoutTokens.Workspace.cardEdgeWidth) }
                .frame(height: height)
                .transaction { if look.motion == .today { $0.animation = nil } }
            VStack(alignment: .leading, spacing: SpacingTokens.none) {
                header.frame(height: Self.headerHeight)
                if isOpen || look.closed == .dock {
                    LabSHDock().frame(height: Self.dockHeight - SpacingTokens.xxs2).padding(.bottom, SpacingTokens.xxs2)
                }
                rows
            }
            .frame(height: height, alignment: .top)
            // Today the rows aren't cut by the card: they fade where they are.
            .clipShape(look.motion == .today ? AnyShape(Rectangle().inset(by: -SpacingTokens.xxxl * 4)) : AnyShape(shape))
            .transaction { if look.motion == .today { $0.animation = nil } }
        }
        .frame(height: height, alignment: .top)
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var rows: some View {
        if look.motion == .today {
            // Rows leave on their own fade while the card has already changed size.
            if isOpen {
                VStack(spacing: SpacingTokens.none) { ForEach(server.rows, id: \.self) { LabSHRow(title: $0) } }
                    .transition(.opacity.animation(motion.expand))
            }
        } else {
            VStack(spacing: SpacingTokens.none) {
                ForEach(Array(server.rows.enumerated()), id: \.offset) { index, title in
                    LabSHRow(title: title)
                        .opacity(isOpen || look.motion == .fold ? 1 : 0)
                        .offset(y: !isOpen && look.motion == .rollUp ? -Self.rowHeight * 0.6 : 0)
                        .animation(rowAnimation(index), value: isOpen)
                }
            }
        }
    }

    private func rowAnimation(_ index: Int) -> Animation? {
        switch look.motion {
        case .fold: return nil
        case .cascade:
            let fromBottom = Double(server.rows.count - 1 - index)
            return motion.expand.delay((isOpen ? Double(index) : fromBottom) * 0.025)
        default: return motion.expand
        }
    }

    /// The accepted proposal (not Echo today) centres a closed card's header in the card.
    private var centresClosed: Bool { !isOpen && look.chevron != .top && look.closed == .header }

    private var header: some View {
        let showsChevron = switch look.shows {
        case .today: isHovering || !isOpen
        case .always: true
        case .hover: isHovering
        }
        let alignment: VerticalAlignment = look.chevron == .top ? .top : .center
        return Button { withAnimation(look.animation(motion)) { isOpen.toggle() } } label: {
            HStack(alignment: alignment, spacing: SpacingTokens.xs) {
                if look.chevron == .leading { chevron(showsChevron) }
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(server.name).font(SidebarRowConstants.serverHeaderFont).foregroundStyle(ColorTokens.Text.primary)
                    Text("\(server.product) · Databases").font(SidebarRowConstants.trailingFont).foregroundStyle(ColorTokens.Text.tertiary)
                }
                Spacer(minLength: SpacingTokens.xxs)
                if look.chevron != .leading { chevron(showsChevron) }
            }
            .padding(.horizontal, SpacingTokens.sm)
            // Accepted with the owner's note: a closed card centres the header and the chevron in itself.
            .padding(.top, centresClosed ? SpacingTokens.none : SpacingTokens.sm)
            .frame(maxHeight: .infinity, alignment: look.chevron == .top ? .top : .center)
            .padding(.top, look.chevron == .top || centresClosed ? 0 : -SpacingTokens.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func chevron(_ visible: Bool) -> some View {
        Image(systemName: "chevron.right")
            .font(look.symbol == .circled ? TypographyTokens.label.weight(.bold) : SidebarRowConstants.sectionChevronFont)
            .foregroundStyle(ColorTokens.Text.tertiary)
            .rotationEffect(.degrees(isOpen ? 90 : 0))
            .frame(width: look.symbol == .circled ? SpacingTokens.md1 : SidebarRowConstants.chevronWidth,
                   height: look.symbol == .circled ? SpacingTokens.md1 : SidebarRowConstants.chevronWidth)
            .background { if look.symbol == .circled { Circle().fill(ColorTokens.Sidebar.hoverFill) } }
            .opacity(visible ? 1 : 0)
            .animation(motion.hover, value: visible)
    }
}
