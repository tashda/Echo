import SwiftUI

/// The Explorer tree, in SwiftUI (Design/05-components.md › Explorer tree, Design/swiftui-tree.md).
///
/// Rows are a flat, lazy list with a fixed height per row kind, so every row's position is known
/// from `ExplorerTreeLayout` without measuring. Behind the list, one card per server is drawn with
/// the editor card's own modifier, cut to the visible area with rounded corners where the tree's
/// edge cuts it (round 7, F2). The list itself is clipped to the same rounded shape.
///
/// Scrolling touches only the small cards layer (through `ExplorerTreeScrollState`), never the
/// rows, and reports the server and database at the top to the rail.
struct ObjectBrowserOutlineView: View {
    let roots: [ObjectBrowserNode]
    let expandedNodeIDs: Set<String>
    let selectedNodeID: String?
    let density: SidebarDensity
    let topScrollerInset: CGFloat
    /// Corner radius of the server cards, from the Card Corners setting.
    var cornerRadius: CGFloat = LayoutTokens.Workspace.cardCornerRadius
    let rowContent: (ObjectBrowserNode, Bool, Int, CGFloat, @escaping () -> Void) -> AnyView
    let onExpansionChanged: (ObjectBrowserNode, Bool) -> Void
    let onActivation: (ObjectBrowserNode) -> Void
    let onSelectionChanged: (ObjectBrowserNode?) -> Void
    let revealNodeID: String?
    let revealRequestID: Int
    /// Called when the row at the top changes, with its server's connection (for the dock).
    var onTopRowChanged: ((String?, UUID?) -> Void)? = nil
    /// Called when the server or database at the top of the visible area changes, e.g. while scrolling.
    var onTopVisibleContextChanged: ((ObjectBrowserTopVisibleContext) -> Void)? = nil
    /// Round 9, SB3: no scroll bar unless Settings › Sidebar › Show scroll bar is on.
    var showsScrollBar = false

    /// Row height per density. Inner padding lives inside `SidebarRow`; this is the slot each
    /// row gets, tuned so its content centres without clipping:
    /// - compact: 12pt icon + 2×3 padding ≈ 18pt → 21pt slot
    /// - small:   14pt icon + 2×4 padding ≈ 22pt → 25pt slot
    /// - medium:  16pt icon + 2×6 padding = 28pt → 29pt slot
    /// - large:   18pt icon + 2×7 padding = 32pt → 35pt slot
    static func baseRowHeight(for density: SidebarDensity) -> CGFloat {
        switch density {
        case .compact: return 21
        case .small: return 25
        case .medium: return 29
        case .large: return 35
        }
    }

    @Environment(\.echoMotion) private var motion
    @State private var scroll = ExplorerTreeScrollState()
    @State private var position = ScrollPosition(edge: .top)
    @State private var handledRevealRequestID = 0

    var body: some View {
        let baseRowHeight = Self.baseRowHeight(for: density)
        let layout = ExplorerTreeLayout(roots: roots, expandedNodeIDs: expandedNodeIDs, baseRowHeight: baseRowHeight)
        let rowIDs = layout.rows.map(\.id)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ScrollView(.vertical) {
            // A server with a dock pins its name and dock while its rows scroll (TC1).
            LazyVStack(spacing: SpacingTokens.none, pinnedViews: [.sectionHeaders]) {
                ForEach(layout.groups) { group in
                    if group.header.isEmpty {
                        rows(group.rows)
                    } else {
                        Section {
                            rows(group.rows)
                        } header: {
                            VStack(spacing: SpacingTokens.none) { rows(group.header) }
                                .background { ExplorerPinnedHeaderBlur(restingMinY: group.header[0].minY, scroll: scroll) }
                        }
                    }
                }
            }
            .padding(.bottom, LayoutTokens.Workspace.treeCardBottomPadding)
            .animation(motion.expand, value: rowIDs)
        }
        .scrollPosition($position)
        .scrollIndicators(showsScrollBar ? .automatic : .never)
        // The thin scroller stays inside the cards' rounded corners.
        .contentMargins(.top, max(topScrollerInset, cornerRadius), for: .scrollIndicators)
        .contentMargins(.bottom, cornerRadius, for: .scrollIndicators)
        // Rows never show outside a card's corners; a card cut by the tree's edge ends rounded.
        .clipShape(shape)
        .onScrollGeometryChange(for: ExplorerTreeScrollMetrics.self) { geometry in
            ExplorerTreeScrollMetrics(
                offset: geometry.contentOffset.y + geometry.contentInsets.top,
                viewportHeight: geometry.containerSize.height,
                contentWidth: geometry.contentSize.width
            )
        } action: { _, metrics in
            scroll.offset = metrics.offset
            scroll.viewportHeight = metrics.viewportHeight
            scroll.contentWidth = metrics.contentWidth
            reportTopVisibleContext(in: layout, baseRowHeight: baseRowHeight)
            reportTopRow(in: layout, baseRowHeight: baseRowHeight)
        }
        // A background never sizes its view, so the cards can't make the tree (or the
        // window) taller than its space.
        .background(alignment: .top) {
            ExplorerTreeCardsLayer(cards: layout.cards, scroll: scroll)
                .animation(motion.expand, value: rowIDs)
        }
        .frame(minHeight: SpacingTokens.none)
        .onChange(of: rowIDs) { _, _ in
            reportTopVisibleContext(in: layout, baseRowHeight: baseRowHeight)
        }
        .onChange(of: revealRequestID) { _, _ in
            reveal(in: layout)
        }
        .onAppear {
            reveal(in: layout)
            reportTopVisibleContext(in: layout, baseRowHeight: baseRowHeight)
        }
    }

    private func rows(_ rows: [ExplorerTreeLayout.Row]) -> some View {
        ForEach(rows) { row in
            let node = row.node
            rowContent(node, expandedNodeIDs.contains(node.id), row.depth, 0, { activate(node) })
                .frame(maxWidth: .infinity)
                .frame(height: row.height)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func reportTopRow(in layout: ExplorerTreeLayout, baseRowHeight: CGFloat) {
        guard let onTopRowChanged else { return }
        let top = layout.topRow(atOffset: scroll.offset, baseRowHeight: baseRowHeight)
        guard top?.id != scroll.lastReportedTopRowID else { return }
        scroll.lastReportedTopRowID = top?.id
        onTopRowChanged(top?.id, top?.connectionID)
    }

    // MARK: - Actions

    private func activate(_ node: ObjectBrowserNode) {
        if !node.children.isEmpty {
            onExpansionChanged(node, !expandedNodeIDs.contains(node.id))
        }
        onSelectionChanged(node)
        onActivation(node)
    }

    /// Glides so the requested row (or the gap above its card) lands at the top.
    private func reveal(in layout: ExplorerTreeLayout) {
        guard revealRequestID != handledRevealRequestID,
              let revealNodeID,
              let target = layout.revealOffset(for: revealNodeID)
        else { return }
        handledRevealRequestID = revealRequestID

        let maxOffset = max(0, layout.contentHeight - scroll.viewportHeight)
        let y = min(max(0, target), maxOffset)
        withAnimation(motion.reveal) {
            position.scrollTo(y: y)
        }
    }

    /// Reports only when the server or database at the top changes, and after the current
    /// update, so scrolling never mutates shared state mid-render.
    private func reportTopVisibleContext(in layout: ExplorerTreeLayout, baseRowHeight: CGFloat) {
        guard let onTopVisibleContextChanged,
              let context = layout.topVisibleContext(atOffset: scroll.offset, baseRowHeight: baseRowHeight),
              context != scroll.lastReportedContext
        else { return }
        scroll.lastReportedContext = context
        Task { @MainActor in
            onTopVisibleContextChanged(context)
        }
    }
}

/// Scroll position and viewport size, read only by the cards layer so scrolling never
/// re-renders the rows.
@Observable @MainActor
final class ExplorerTreeScrollState {
    var offset: CGFloat = 0
    var viewportHeight: CGFloat = 0
    /// Width of the rows, which is narrower than the tree when scroll bars are always shown.
    var contentWidth: CGFloat = 0
    @ObservationIgnored var lastReportedContext: ObjectBrowserTopVisibleContext?
    @ObservationIgnored var lastReportedTopRowID: String?
}

struct ExplorerTreeScrollMetrics: Equatable {
    var offset: CGFloat
    var viewportHeight: CGFloat
    var contentWidth: CGFloat
}

/// One card per server behind the rows, each cut to the visible part of the tree. The cards use
/// the editor card's modifier, so they match it exactly (tokens, corners setting, shadow, edge).
struct ExplorerTreeCardsLayer: View {
    let cards: [ExplorerTreeLayout.Card]
    let scroll: ExplorerTreeScrollState

    var body: some View {
        let offset = scroll.offset
        let viewport = scroll.viewportHeight

        ZStack(alignment: .top) {
            ForEach(cards) { card in
                let top = max(card.minY - offset, 0)
                let bottom = min(card.minY + card.height - offset, viewport)
                if bottom - top > SpacingTokens.micro {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: bottom - top)
                        .workspaceCard()
                        .offset(y: top)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
