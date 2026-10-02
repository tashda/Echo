import SwiftUI

/// The Explorer tree, in SwiftUI (Design/05-components.md › Explorer tree, Design/swiftui-tree.md).
///
/// Rows have a fixed height per row kind, so every row's position is known from
/// `ObjectBrowserTreeLayout` without measuring, and the tree places them there itself
/// (`ExplorerTreeCanvasLayout`), building only the rows near the view (ObjectBrowserOutlineView+Rows).
/// Behind the rows, one card per server is drawn with
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
    /// What the server headers need beyond an ordinary row's slot (the title banner, round 53).
    var serverHeaderExtraHeight: CGFloat = 0
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
    /// Servers whose cards are folding or opening (round 30.2): the edge glides and the rows fade
    /// and are cut by it (ObjectBrowserOutlineView+Fold).
    var foldingConnectionIDs: Set<UUID> = []
    /// A card about to close: the view is brought to its header first (ObjectBrowserOutlineView+Fold).
    var foldAnchor: ExplorerFoldAnchor?
    /// A row's context menu; the tree has one menu host for all rows (ExplorerTreeContextMenuHost).
    var contextMenu: (ObjectBrowserNode) -> NSMenu? = { _ in nil }
    /// What a double-click on a row does (round 42.4: a table or view opens its data).
    var doubleClick: (ObjectBrowserNode) -> (() -> Void)? = { _ in nil }
    /// The menu for the empty space around and below the cards (round 42.6).
    var emptySpaceMenu: () -> NSMenu? = { nil }
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

    @Environment(\.echoMotion) var motion
    @State var scroll = ExplorerTreeScrollState()
    @State var position = ScrollPosition(edge: .top)
    @State private var handledRevealRequestID = 0
    /// How far the view was scrolled into a server's card when it left a section, by
    /// "connection|section".
    @State private var dockPlaces: [String: CGFloat] = [:]
    /// The row whose context menu is open, drawn with the context highlight.
    @State private var contextMenuNodeID: String?
    /// Each card's top before the last change, so rows arriving with a card that moved start
    /// where the card was (ObjectBrowserOutlineView+Rows).
    @State var previousCardTops: [String: CGFloat] = [:]

    var body: some View {
        let baseRowHeight = Self.baseRowHeight(for: density)
        let layout = ObjectBrowserTreeLayout(roots: roots, expandedNodeIDs: expandedNodeIDs, baseRowHeight: baseRowHeight,
                                           serverHeaderExtraHeight: serverHeaderExtraHeight)
        let rowIDs = layout.rows.map(\.id)
        let dockSelections = layout.dockSelections
        // Opening or closing a docked server adds or removes its dock, which changes the
        // selections too; that is a fold, not a switch, so it keeps its animation (round 46).
        let dockSwitchKey = foldingConnectionIDs.isEmpty ? dockSelections : [:]
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ScrollView(.vertical) {
            VStack(spacing: SpacingTokens.none) {
                rowsCanvas(layout)
                // A dock switch lays the rows out at once, under the veil: nothing inside the
                // scroll view changes size frame by frame (which made AppKit recheck the window's
                // regions every frame). Only the card's background and veil move its edge. This is
                // the inner modifier, so it wins over `expand` when both change.
                .animation(nil, value: dockSwitchKey)
                .animation(motion.expand, value: rowIDs)
                ExplorerTreeHoldSpacer(scroll: scroll)
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
                // In a fold the veil grows and shrinks with the card's edge (round 46).
                .animation(foldingConnectionIDs.isEmpty ? motion.dockEdge : motion.expand, value: dockSelections)
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
        } action: { old, metrics in
            // Rows scrolling in and out made AppKit recheck the window's drag regions every
            // frame (a sixth of the main thread, traced 2026-10-01).
            if old.offset != metrics.offset { WindowDragPause.pauseWorkspace(for: 0.3) }
            scroll.offset = metrics.offset
            let window = ExplorerTreeWindow.around(offset: metrics.offset, viewport: metrics.viewportHeight)
            if scroll.window != window { scroll.window = window }
            scroll.viewportHeight = metrics.viewportHeight
            scroll.contentWidth = metrics.contentWidth
            scroll.totalHeight = metrics.totalHeight
            scroll.updateHold(contentHeight: layout.contentHeight)
            reportTopVisibleContext(in: layout, baseRowHeight: baseRowHeight)
        }
        // A background never sizes its view, so the cards can't make the tree (or the
        // window) taller than its space.
        .background(alignment: .top) {
            ExplorerTreeCardsLayer(cards: layout.cards, scroll: scroll,
                                   switchingCardIDs: switchingCardIDs(in: layout), edgeAnimation: motion.dockEdge,
                                   foldingCardIDs: foldingCardIDs(in: layout), foldAnimation: motion.expand) {
                // The editor card's modifier, so the tree's cards match it exactly.
                Color.clear.workspaceCard()
            }
                .animation(nil, value: dockSwitchKey)
                .animation(motion.expand, value: rowIDs)
        }
        .frame(minHeight: SpacingTokens.none)
        // The rows changed height: hold the room below before AppKit can move the view (N2).
        .onChange(of: layout.contentHeight) { _, height in
            scroll.updateHold(contentHeight: height)
        }
        .onChange(of: rowIDs) { _, _ in
            previousCardTops = Self.cardTops(layout)
            settleAfterFold(in: layout)
            reportTopVisibleContext(in: layout, baseRowHeight: baseRowHeight)
        }
        .onChange(of: foldAnchor) { _, anchor in
            if let anchor { anchorClosingCard(anchor.connectionID, in: layout) }
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
            previousCardTops = Self.cardTops(layout)
            reveal(in: layout)
            reportTopVisibleContext(in: layout, baseRowHeight: baseRowHeight)
        }
    }

    /// One row in its slot. Arriving rows fade in with the list's animation while their
    /// neighbours move; leaving rows fade out quickly, so they never sit under rows moving over
    /// them. A card mid-switch swaps its rows with no transitions at all: the whole card fades.
    func rowSlot(_ row: ObjectBrowserTreeLayout.Row, underHeaderOf headerHeight: CGFloat = 0, isSwitching: Bool = false,
                 fold: ExplorerTreeFold? = nil, arrivingFrom shift: CGFloat = 0) -> some View {
        let node = row.node
        let isExpanded = expandedNodeIDs.contains(node.id)
        let hasContextMenu = contextMenuNodeID == node.id
        // Nodes are rebuilt whenever anything they show changes, so the node itself, with what this
        // view adds, says whether the row has to be drawn again.
        let key = RowKey(node: ObjectIdentifier(node), isExpanded: isExpanded, depth: row.depth, height: row.height,
                         headerHeight: headerHeight, hasContextMenu: hasContextMenu)
        return ExplorerTreeRowSlot(height: row.height) {
            ExplorerTreeRowHost(key: key) {
                rowContent(node, isExpanded, row.depth, 0, { activate(node) })
                    .modifier(ExplorerRowEdgeBlur(headerHeight: headerHeight))
                    .environment(\.sidebarContextMenuActive, hasContextMenu)
            }
            .equatable()
        }
        .transition(isSwitching ? .identity : rowTransition(for: row, fold: fold, arrivingFrom: shift))
    }

    /// What decides whether a row is drawn again (`ExplorerTreeRowHost`).
    struct RowKey: Equatable, Sendable {
        let node: ObjectIdentifier
        let isExpanded: Bool
        let depth: Int
        let height: CGFloat
        let headerHeight: CGFloat
        let hasContextMenu: Bool
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
    private func saveDockPlaces(of connectionIDs: Set<UUID>, in layout: ObjectBrowserTreeLayout) {
        let selections = layout.dockSelections
        for connectionID in connectionIDs {
            guard let section = selections[connectionID], let top = layout.serverTop(connectionID) else { continue }
            dockPlaces["\(connectionID)|\(section)"] = scroll.offset - top
        }
    }

    /// The new section is in: if you had scrolled into the card in that section, jump back there,
    /// instantly (the rows are faded). Otherwise the view doesn't move.
    private func returnToDockPlaces(changedFrom old: [UUID: String], to new: [UUID: String], in layout: ObjectBrowserTreeLayout) {
        for (connectionID, section) in new where old[connectionID] != nil && old[connectionID] != section {
            guard let place = dockPlaces["\(connectionID)|\(section)"], place > 0,
                  let top = layout.serverTop(connectionID) else { continue }
            let maxOffset = max(0, layout.contentHeight - scroll.viewportHeight)
            var transaction = Transaction()
            transaction.disablesAnimations = true
            let y = min(top + place, maxOffset)
            prepareWindow(for: y)
            withTransaction(transaction) { position.scrollTo(y: y) }
        }
    }

    /// The row under a point in the tree's view (a pinned header covers the top), unless it is
    /// the dock, whose icons have menus of their own.
    private func contextTarget(at point: CGPoint, in layout: ObjectBrowserTreeLayout) -> ExplorerTreeContextTarget? {
        guard let row = row(at: point.y, in: layout) else {
            return ExplorerTreeContextTarget(nodeID: "", menu: emptySpaceMenu)
        }
        switch row.node.row {
        case .dock, .topSpacer: return nil
        default: break
        }
        let node = row.node
        return ExplorerTreeContextTarget(nodeID: node.id, menu: { contextMenu(node) }, doubleClick: doubleClick(node))
    }

    private func row(at y: CGFloat, in layout: ObjectBrowserTreeLayout) -> ObjectBrowserTreeLayout.Row? {
        let offset = scroll.offset
        for group in layout.groups where !group.header.isEmpty {
            guard let card = layout.cards.first(where: { $0.id == group.header[0].id }) else { continue }
            let headerHeight = group.header.reduce(SpacingTokens.none) { $0 + $1.height }
            let cardBottom = card.minY + card.height
            guard group.header[0].minY < offset, offset < cardBottom else { continue }
            // Pinned, or being pushed up by the card's last row (ExplorerTreePinnedHeader).
            var top = min(SpacingTokens.none, cardBottom - LayoutTokens.Workspace.treeCardBottomPadding - offset - headerHeight)
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
    private func switchingCardIDs(in layout: ObjectBrowserTreeLayout) -> Set<String> {
        Set(layout.groups.compactMap { group in
            guard let server = group.header.first, let id = server.node.row.connectionID, switchingConnectionIDs.contains(id) else { return nil }
            return server.id
        })
    }

    func hidesRows(_ group: ObjectBrowserTreeLayout.Group) -> Bool {
        guard let connectionID = group.header.first?.node.row.connectionID else { return false }
        return hiddenRowsConnectionIDs.contains(connectionID)
    }

    func isSwitching(_ group: ObjectBrowserTreeLayout.Group) -> Bool {
        guard let connectionID = group.header.first?.node.row.connectionID else { return false }
        return switchingConnectionIDs.contains(connectionID)
    }

    private func reveal(in layout: ObjectBrowserTreeLayout) {
        guard revealRequestID != handledRevealRequestID,
              let revealNodeID,
              let target = layout.revealOffset(for: revealNodeID)
        else { return }
        handledRevealRequestID = revealRequestID

        let maxOffset = max(0, layout.contentHeight - scroll.viewportHeight)
        let y = min(max(0, target), maxOffset)
        prepareWindow(for: y)
        withAnimation(revealAnimated ? motion.reveal : nil) {
            position.scrollTo(y: y)
        }
    }

    /// Reports only when the server or database at the top changes, and after the current
    /// update, so scrolling never mutates shared state mid-render.
    private func reportTopVisibleContext(in layout: ObjectBrowserTreeLayout, baseRowHeight: CGFloat) {
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
