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
    /// Called when the server or database at the top of the visible area changes, e.g. while scrolling.
    var onTopVisibleContextChanged: ((ObjectBrowserTopVisibleContext) -> Void)? = nil
    /// Round 9, SB3: no scroll bar unless Settings › Sidebar › Show scroll bar is on.
    var showsScrollBar = false
    /// Servers whose rows are faded out mid-switch (round 19, S3).
    var fadingConnectionIDs: Set<UUID> = []
    /// Servers mid-switch: their rows swap with no transitions (ObjectBrowserSidebarView+Dock).
    var switchingConnectionIDs: Set<UUID> = []
    /// Servers whose new rows wait, invisible under the veil, until the card has reached its
    /// new size, so no row ever shows outside the card while its edge moves.
    var hiddenRowsConnectionIDs: Set<UUID> = []
    /// A row's context menu; the tree has one menu host for all rows (ExplorerTreeContextMenuHost).
    var contextMenu: (ObjectBrowserNode) -> NSMenu? = { _ in nil }
    /// False makes the next reveal a jump, as a dock switch returning to its place (round 19).
    var revealAnimated = true

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
    /// How far the view was scrolled into a server's card when it left a section, by
    /// "connection|section".
    @State private var dockPlaces: [String: CGFloat] = [:]
    /// The row whose context menu is open, drawn with the context highlight.
    @State private var contextMenuNodeID: String?

    var body: some View {
        let baseRowHeight = Self.baseRowHeight(for: density)
        let layout = ExplorerTreeLayout(roots: roots, expandedNodeIDs: expandedNodeIDs, baseRowHeight: baseRowHeight)
        let rowIDs = layout.rows.map(\.id)
        let dockSelections = layout.dockSelections
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ScrollView(.vertical) {
            VStack(spacing: SpacingTokens.none) {
                // A server with a dock pins its name and dock while its rows scroll (TC1).
                LazyVStack(spacing: SpacingTokens.none, pinnedViews: [.sectionHeaders]) {
                    ForEach(layout.groups) { group in
                        if group.header.isEmpty {
                            rows(group.rows)
                        } else {
                            Section {
                                rows(group.rows, underHeaderOf: group.header.reduce(SpacingTokens.none) { $0 + $1.height },
                                     isSwitching: isSwitching(group))
                                    .opacity(hidesRows(group) ? 0 : 1)
                            } header: {
                                VStack(spacing: SpacingTokens.none) { rows(group.header) }
                                    .background { ExplorerPinnedHeaderWash(restingMinY: group.header[0].minY, scroll: scroll) }
                            }
                        }
                    }
                }
                .padding(.bottom, LayoutTokens.Workspace.treeCardBottomPadding)
                // A dock switch lays the rows out at once, under the veil: nothing inside the
                // scroll view changes size frame by frame (which made AppKit recheck the window's
                // regions every frame). Only the card's background and veil move its edge. This is
                // the inner modifier, so it wins over `expand` when both change.
                .animation(nil, value: dockSelections)
                .animation(motion.expand, value: rowIDs)
                ExplorerTreeHoldSpacer(scroll: scroll, contentHeight: layout.contentHeight)
            }
        }
        .scrollPosition($position)
        .scrollIndicators(showsScrollBar ? .automatic : .never)
        // The thin scroller stays inside the cards' rounded corners.
        .contentMargins(.top, max(topScrollerInset, cornerRadius), for: .scrollIndicators)
        .contentMargins(.bottom, cornerRadius, for: .scrollIndicators)
        // Round 19, S3: the veil that fades a switching card's rows (ExplorerTreeVeilLayer).
        .overlay(alignment: .top) {
            ExplorerTreeVeilLayer(veils: layout.veils(switching: switchingConnectionIDs, opaque: fadingConnectionIDs),
                                  scroll: scroll, cornerRadius: cornerRadius)
                .animation(motion.dockEdge, value: dockSelections)
        }
        .overlay {
            ExplorerTreeContextMenuHost(target: { contextTarget(at: $0, in: layout) }, onMenu: { contextMenuNodeID = $0 })
        }
        // Rows never show outside a card's corners; a card cut by the tree's edge ends rounded.
        .clipShape(shape)
        .onScrollGeometryChange(for: ExplorerTreeScrollMetrics.self) { geometry in
            ExplorerTreeScrollMetrics(
                offset: geometry.contentOffset.y + geometry.contentInsets.top,
                viewportHeight: geometry.containerSize.height,
                contentWidth: geometry.contentSize.width,
                totalHeight: geometry.contentSize.height
            )
        } action: { _, metrics in
            scroll.offset = metrics.offset
            scroll.viewportHeight = metrics.viewportHeight
            scroll.contentWidth = metrics.contentWidth
            scroll.totalHeight = metrics.totalHeight
            reportTopVisibleContext(in: layout, baseRowHeight: baseRowHeight)
        }
        // A background never sizes its view, so the cards can't make the tree (or the
        // window) taller than its space.
        .background(alignment: .top) {
            ExplorerTreeCardsLayer(cards: layout.cards, scroll: scroll,
                                   switchingCardIDs: switchingCardIDs(in: layout), edgeAnimation: motion.dockEdge)
                .animation(nil, value: dockSelections)
                .animation(motion.expand, value: rowIDs)
        }
        .frame(minHeight: SpacingTokens.none)
        .onChange(of: rowIDs) { _, _ in
            reportTopVisibleContext(in: layout, baseRowHeight: baseRowHeight)
        }
        .onChange(of: revealRequestID) { _, _ in
            reveal(in: layout)
        }
        // Round 19, jump: each dock section keeps how far the view was scrolled into its card.
        .onChange(of: switchingConnectionIDs) { old, new in
            saveDockPlaces(of: new.subtracting(old), in: layout)
        }
        .onChange(of: dockSelections) { old, new in
            returnToDockPlaces(changedFrom: old, to: new, in: layout)
        }
        .onAppear {
            reveal(in: layout)
            reportTopVisibleContext(in: layout, baseRowHeight: baseRowHeight)
        }
    }

    /// Arriving rows fade in with the list's animation while their neighbours move; leaving rows
    /// fade out quickly, so they never sit under rows moving over them. A card mid-switch swaps
    /// its rows with no transitions at all: the whole card fades instead.
    private func rows(_ rows: [ExplorerTreeLayout.Row], underHeaderOf headerHeight: CGFloat = 0, isSwitching: Bool = false) -> some View {
        ForEach(rows) { row in
            let node = row.node
            rowContent(node, expandedNodeIDs.contains(node.id), row.depth, 0, { activate(node) })
                .frame(maxWidth: .infinity)
                .frame(height: row.height)
                .modifier(ExplorerRowEdgeBlur(headerHeight: headerHeight))
                .environment(\.sidebarContextMenuActive, contextMenuNodeID == node.id)
                .transition(isSwitching ? .identity : Self.rowTransition(motion))
        }
    }

    static func rowTransition(_ motion: EchoMotion) -> AnyTransition {
        .asymmetric(insertion: .opacity, removal: .opacity.animation(motion.rowRemoval))
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
    /// A switch is starting: remember how far each switching server's card was scrolled.
    private func saveDockPlaces(of connectionIDs: Set<UUID>, in layout: ExplorerTreeLayout) {
        let selections = layout.dockSelections
        for connectionID in connectionIDs {
            guard let section = selections[connectionID], let top = layout.serverTop(connectionID) else { continue }
            dockPlaces["\(connectionID)|\(section)"] = scroll.offset - top
        }
    }

    /// The new section is in: if you had scrolled into the card in that section, jump back there,
    /// instantly (the rows are faded). Otherwise the view doesn't move.
    private func returnToDockPlaces(changedFrom old: [UUID: String], to new: [UUID: String], in layout: ExplorerTreeLayout) {
        for (connectionID, section) in new where old[connectionID] != nil && old[connectionID] != section {
            guard let place = dockPlaces["\(connectionID)|\(section)"], place > 0,
                  let top = layout.serverTop(connectionID) else { continue }
            let maxOffset = max(0, layout.contentHeight - scroll.viewportHeight)
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { position.scrollTo(y: min(top + place, maxOffset)) }
        }
    }

    /// The row under a point in the tree's view (a pinned header covers the top), unless it is
    /// the dock, whose icons have menus of their own.
    private func contextTarget(at point: CGPoint, in layout: ExplorerTreeLayout) -> ExplorerTreeContextTarget? {
        guard let row = row(at: point.y, in: layout) else { return nil }
        switch row.node.row {
        case .dock, .topSpacer: return nil
        default: break
        }
        let node = row.node
        return ExplorerTreeContextTarget(nodeID: node.id, menu: { contextMenu(node) })
    }

    private func row(at y: CGFloat, in layout: ExplorerTreeLayout) -> ExplorerTreeLayout.Row? {
        let offset = scroll.offset
        for group in layout.groups where !group.header.isEmpty {
            guard let card = layout.cards.first(where: { $0.id == group.header[0].id }) else { continue }
            let headerHeight = group.header.reduce(SpacingTokens.none) { $0 + $1.height }
            let cardBottom = card.minY + card.height
            guard group.header[0].minY < offset, offset < cardBottom else { continue }
            // Pinned, or being pushed up by the next card.
            var top = min(SpacingTokens.none, cardBottom - offset - headerHeight)
            guard y >= top, y < top + headerHeight else { continue }
            for row in group.header {
                if y < top + row.height { return row }
                top += row.height
            }
        }
        guard let index = layout.rowIndex(at: y + offset) else { return nil }
        let row = layout.rows[index]
        return y + offset < row.minY + row.height ? row : nil
    }

    /// The cards whose edge animates in a dock switch: the switching servers' own.
    private func switchingCardIDs(in layout: ExplorerTreeLayout) -> Set<String> {
        Set(layout.groups.compactMap { group in
            guard let server = group.header.first, let id = server.node.row.connectionID, switchingConnectionIDs.contains(id) else { return nil }
            return server.id
        })
    }

    private func hidesRows(_ group: ExplorerTreeLayout.Group) -> Bool {
        guard let connectionID = group.header.first?.node.row.connectionID else { return false }
        return hiddenRowsConnectionIDs.contains(connectionID)
    }

    private func isSwitching(_ group: ExplorerTreeLayout.Group) -> Bool {
        guard let connectionID = group.header.first?.node.row.connectionID else { return false }
        return switchingConnectionIDs.contains(connectionID)
    }

    private func reveal(in layout: ExplorerTreeLayout) {
        guard revealRequestID != handledRevealRequestID,
              let revealNodeID,
              let target = layout.revealOffset(for: revealNodeID)
        else { return }
        handledRevealRequestID = revealRequestID

        let maxOffset = max(0, layout.contentHeight - scroll.viewportHeight)
        let y = min(max(0, target), maxOffset)
        withAnimation(revealAnimated ? motion.reveal : nil) {
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
