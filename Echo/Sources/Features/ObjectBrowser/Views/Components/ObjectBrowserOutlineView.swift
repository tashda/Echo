import AppKit
import SwiftUI

struct ObjectBrowserOutlineView: NSViewRepresentable {
    let roots: [ObjectBrowserNode]
    let expandedNodeIDs: Set<String>
    let selectedNodeID: String?
    let density: SidebarDensity
    let topScrollerInset: CGFloat
    let rowContent: (ObjectBrowserNode, Bool, Int, CGFloat, @escaping () -> Void) -> AnyView
    let onExpansionChanged: (ObjectBrowserNode, Bool) -> Void
    let onActivation: (ObjectBrowserNode) -> Void
    let onSelectionChanged: (ObjectBrowserNode?) -> Void
    let revealNodeID: String?
    let revealRequestID: Int
    /// Called when the connection owning the topmost visible row changes, e.g. while scrolling.
    var onTopVisibleConnectionChanged: ((UUID?) -> Void)? = nil

    /// Base row height per density. Inner padding lives inside `SidebarRow`;
    /// this is the slot the table allocates. Values tuned to match
    /// SidebarRow's per-density vertical padding + icon frame (so content
    /// vertically centers without clipping):
    /// - compact: 12pt icon + 2×2 padding ≈ 18pt → 18
    /// - small:   14pt icon + 2×3 padding ≈ 20pt → 20
    /// - medium:  16pt icon + 2×4 padding ≈ 24pt → 24 (Apple Finder default)
    /// - large:   18pt icon + 2×6 padding ≈ 30pt → 30
    static func baseRowHeight(for density: SidebarDensity) -> CGFloat {
        switch density {
        case .compact: return 18
        case .small: return 20
        case .medium: return 24
        case .large: return 30
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            rowContent: rowContent,
            onExpansionChanged: onExpansionChanged,
            onActivation: onActivation,
            onSelectionChanged: onSelectionChanged
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .none
        scrollView.scrollerInsets = NSEdgeInsets(
            top: max(topScrollerInset, SpacingTokens.none),
            left: 0,
            bottom: 0,
            right: 0
        )
        scrollView.contentInsets = NSEdgeInsets(
            top: 0,
            left: 0,
            bottom: ExplorerSidebarConstants.scrollBottomPadding + SpacingTokens.md2,
            right: 0
        )

        scrollView.documentView = context.coordinator.tableView
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.clipViewBoundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        nsView.scrollerInsets = NSEdgeInsets(
            top: max(topScrollerInset, SpacingTokens.none),
            left: 0,
            bottom: 0,
            right: 0
        )
        context.coordinator.rowContent = rowContent
        context.coordinator.onExpansionChanged = onExpansionChanged
        context.coordinator.onActivation = onActivation
        context.coordinator.onSelectionChanged = onSelectionChanged
        context.coordinator.onTopVisibleConnectionChanged = onTopVisibleConnectionChanged
        let densityChanged = context.coordinator.baseRowHeight != Self.baseRowHeight(for: density)
        context.coordinator.baseRowHeight = Self.baseRowHeight(for: density)
        context.coordinator.update(
            roots: roots,
            expandedNodeIDs: expandedNodeIDs,
            selectedNodeID: selectedNodeID,
            revealNodeID: revealNodeID,
            revealRequestID: revealRequestID
        )
        if densityChanged {
            context.coordinator.tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0 ..< context.coordinator.tableView.numberOfRows))
        }
        context.coordinator.reportTopVisibleConnection()
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        struct VisibleRow {
            let node: ObjectBrowserNode
            let depth: Int
        }

        let tableView: NSTableView
        var rowContent: (ObjectBrowserNode, Bool, Int, CGFloat, @escaping () -> Void) -> AnyView
        var onExpansionChanged: (ObjectBrowserNode, Bool) -> Void
        var onActivation: (ObjectBrowserNode) -> Void
        var onSelectionChanged: (ObjectBrowserNode?) -> Void
        var onTopVisibleConnectionChanged: ((UUID?) -> Void)?
        var baseRowHeight: CGFloat = ObjectBrowserOutlineView.baseRowHeight(for: .medium)

        private var roots: [ObjectBrowserNode] = []
        private var expandedNodeIDs: Set<String> = []
        private var selectedNodeID: String?
        private var visibleRows: [VisibleRow] = []
        private var lastVisibleSignature: [String] = []
        private var lastRevealRequestID = 0
        private var lastTopVisibleConnectionID: UUID?

        init(
            rowContent: @escaping (ObjectBrowserNode, Bool, Int, CGFloat, @escaping () -> Void) -> AnyView,
            onExpansionChanged: @escaping (ObjectBrowserNode, Bool) -> Void,
            onActivation: @escaping (ObjectBrowserNode) -> Void,
            onSelectionChanged: @escaping (ObjectBrowserNode?) -> Void
        ) {
            self.rowContent = rowContent
            self.onExpansionChanged = onExpansionChanged
            self.onActivation = onActivation
            self.onSelectionChanged = onSelectionChanged

            let tableView = NSTableView(frame: .zero)
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("explorer-lab"))
            column.resizingMask = .autoresizingMask
            tableView.addTableColumn(column)
            tableView.headerView = nil
            tableView.rowSizeStyle = .default
            tableView.selectionHighlightStyle = .none
            tableView.focusRingType = .none
            tableView.backgroundColor = .clear
            tableView.enclosingScrollView?.drawsBackground = false
            tableView.intercellSpacing = .zero
            tableView.usesAutomaticRowHeights = false
            tableView.rowHeight = 25
            tableView.allowsEmptySelection = true
            tableView.allowsMultipleSelection = false

            self.tableView = tableView
            super.init()
            tableView.delegate = self
            tableView.dataSource = self
        }

        func update(
            roots: [ObjectBrowserNode],
            expandedNodeIDs: Set<String>,
            selectedNodeID: String?,
            revealNodeID: String?,
            revealRequestID: Int
        ) {
            self.roots = roots
            self.expandedNodeIDs = expandedNodeIDs
            self.selectedNodeID = selectedNodeID
            let shouldReveal = revealRequestID != lastRevealRequestID && revealNodeID != nil
            let preservedScrollY = shouldReveal ? nil : currentScrollY()

            let oldSignature = lastVisibleSignature
            let oldTopSpacerHeight = topSpacerHeight(in: visibleRows)
            let newVisibleRows = flattenVisibleRows(from: roots, expandedNodeIDs: expandedNodeIDs)
            let newTopSpacerHeight = topSpacerHeight(in: newVisibleRows)
            let newSignature = newVisibleRows.map(\.node.id)
            let structureChanged = newSignature != lastVisibleSignature

            visibleRows = newVisibleRows

            if structureChanged {
                if !oldSignature.isEmpty,
                   let animations = rowAnimations(from: oldSignature, to: newSignature),
                   (!animations.removed.isEmpty || !animations.inserted.isEmpty) {
                    applyRowAnimations(removed: animations.removed, inserted: animations.inserted)
                } else {
                    tableView.reloadData()
                }
                lastVisibleSignature = newSignature
            } else {
                refreshVisibleRows()
            }

            if oldTopSpacerHeight != newTopSpacerHeight, tableView.numberOfRows > 0 {
                tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: 0))
            }

            tableView.deselectAll(nil)

            if let preservedScrollY {
                restoreScrollPosition(
                    y: adjustedScrollPosition(
                        preservedScrollY,
                        oldTopSpacerHeight: oldTopSpacerHeight,
                        newTopSpacerHeight: newTopSpacerHeight
                    )
                )
            }

            if shouldReveal, let revealNodeID {
                reveal(nodeID: revealNodeID)
                lastRevealRequestID = revealRequestID
            }
        }

        @objc func clipViewBoundsDidChange(_ notification: Notification) {
            reportTopVisibleConnection()
        }

        /// Reports the connection that owns the row at the top of the visible area. Only fires
        /// when that connection changes, so scrolling within one server costs nothing.
        func reportTopVisibleConnection() {
            guard onTopVisibleConnectionChanged != nil,
                  let clipView = tableView.enclosingScrollView?.contentView,
                  !visibleRows.isEmpty
            else { return }

            let probe = NSPoint(x: tableView.bounds.midX, y: clipView.bounds.minY + baseRowHeight / 2)
            let row = max(tableView.row(at: probe), 0)
            let ownerID = connectionID(nearRow: min(row, visibleRows.count - 1))
            guard ownerID != lastTopVisibleConnectionID else { return }
            lastTopVisibleConnectionID = ownerID

            // Deferred so a report made from updateNSView never mutates state mid-update.
            DispatchQueue.main.async { [weak self] in
                self?.onTopVisibleConnectionChanged?(ownerID)
            }
        }

        /// Rows without a connection (spacers, columns, messages) take the nearest owner above,
        /// falling back to the first owner below.
        private func connectionID(nearRow row: Int) -> UUID? {
            for index in stride(from: row, through: 0, by: -1) {
                if let id = visibleRows[index].node.row.connectionID { return id }
            }
            for index in row ..< visibleRows.count {
                if let id = visibleRows[index].node.row.connectionID { return id }
            }
            return nil
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            visibleRows.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard visibleRows.indices.contains(row) else { return nil }

            let visibleRow = visibleRows[row]
            let node = visibleRow.node
            let identifier = NSUserInterfaceItemIdentifier("ObjectBrowserOutlineCell")
            let cell = (tableView.makeView(withIdentifier: identifier, owner: nil) as? ObjectBrowserOutlineCellView)
                ?? ObjectBrowserOutlineCellView(identifier: identifier)

            cell.configure(rootView: rowContent(
                node,
                expandedNodeIDs.contains(node.id),
                visibleRow.depth,
                0,
                { [weak self] in self?.activate(nodeID: node.id) }
            ))
            return cell
        }

        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            ObjectBrowserClearRowView()
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            guard visibleRows.indices.contains(row) else { return baseRowHeight }
            let node = visibleRows[row].node
            if case .topSpacer(let height) = node.row {
                // NSTableView raises an internal inconsistency exception when a
                // variable row-height delegate returns zero. A measured overlay
                // can briefly report zero during its first layout pass.
                return max(height, SpacingTokens.micro)
            }
            return baseRowHeight + node.row.groupTopPadding + node.row.extraSlotHeight
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            tableView.deselectAll(nil)
        }

        private func activate(nodeID: String) {
            guard let node = findNode(id: nodeID, in: roots) else { return }

            if !node.children.isEmpty {
                let shouldExpand = !expandedNodeIDs.contains(node.id)
                onExpansionChanged(node, shouldExpand)
            }

            onSelectionChanged(node)
            onActivation(node)
        }

        private func refreshVisibleRows() {
            let visibleRange = tableView.rows(in: tableView.visibleRect)
            guard visibleRange.length > 0 else { return }

            for row in visibleRange.location ..< (visibleRange.location + visibleRange.length) {
                guard visibleRows.indices.contains(row),
                      let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? ObjectBrowserOutlineCellView
                else { continue }

                let visibleRow = visibleRows[row]
                let node = visibleRow.node
                cell.configure(rootView: rowContent(
                    node,
                    expandedNodeIDs.contains(node.id),
                    visibleRow.depth,
                    0,
                    { [weak self] in self?.activate(nodeID: node.id) }
                ))
            }
        }

        private func rowAnimations(
            from oldSignature: [String],
            to newSignature: [String]
        ) -> (removed: IndexSet, inserted: IndexSet)? {
            let oldSet = Set(oldSignature)
            let newSet = Set(newSignature)

            if oldSet.count != oldSignature.count || newSet.count != newSignature.count {
                return nil
            }

            let removed = IndexSet(oldSignature.enumerated().compactMap { index, id in
                newSet.contains(id) ? nil : index
            })
            let inserted = IndexSet(newSignature.enumerated().compactMap { index, id in
                oldSet.contains(id) ? nil : index
            })

            return (removed, inserted)
        }

        private func applyRowAnimations(removed: IndexSet, inserted: IndexSet) {
            NSAnimationContext.runAnimationGroup { context in
                // Close to NSOutlineView's own disclosure timing; the fade keeps rows from
                // appearing to pop in.
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                tableView.beginUpdates()
                if !removed.isEmpty {
                    tableView.removeRows(at: removed, withAnimation: [.effectFade, .slideUp])
                }
                if !inserted.isEmpty {
                    tableView.insertRows(at: inserted, withAnimation: [.effectFade, .slideDown])
                }
                tableView.endUpdates()
            }
            refreshVisibleRows()
        }

        private func flattenVisibleRows(
            from roots: [ObjectBrowserNode],
            expandedNodeIDs: Set<String>
        ) -> [VisibleRow] {
            var rows: [VisibleRow] = []

            func append(nodes: [ObjectBrowserNode], depth: Int) {
                for node in nodes {
                    rows.append(VisibleRow(node: node, depth: depth))
                    guard expandedNodeIDs.contains(node.id) else { continue }
                    append(nodes: node.children, depth: childDepth(for: node, currentDepth: depth))
                }
            }

            append(nodes: roots, depth: 0)
            return rows
        }

        private func childDepth(for node: ObjectBrowserNode, currentDepth: Int) -> Int {
            switch node.row {
            case .topSpacer:
                currentDepth
            case .pendingConnection:
                currentDepth
            case .server:
                currentDepth
            case .databasesFolder, .serverFolder, .databaseFolder, .databaseSubfolder, .securitySection:
                currentDepth + 1
            case .database, .objectGroup, .action, .infoLeaf, .loading, .message, .object,
                    .agentJob, .databaseSnapshot, .linkedServer, .ssisFolder, .serverTrigger,
                    .securityLogin, .securityServerRole, .securityCredential, .databaseNamedItem,
                    .column:
                currentDepth + 1
            }
        }

        private func findNode(
            id: String,
            in nodes: [ObjectBrowserNode]
        ) -> ObjectBrowserNode? {
            for node in nodes {
                if node.id == id {
                    return node
                }
                if let child = findNode(id: id, in: node.children) {
                    return child
                }
            }
            return nil
        }

        private func reveal(nodeID: String) {
            guard let row = visibleRows.firstIndex(where: { $0.node.id == nodeID }) else { return }
            let targetRow = preferredRevealRow(for: row)
            scrollRowToTop(targetRow)
        }

        private func preferredRevealRow(for row: Int) -> Int {
            guard row > 0 else { return row }
            if case .topSpacer = visibleRows[row - 1].node.row {
                return row - 1
            }
            return row
        }

        private func currentScrollY() -> CGFloat? {
            tableView.enclosingScrollView?.contentView.bounds.origin.y
        }

        private func topSpacerHeight(in rows: [VisibleRow]) -> CGFloat? {
            guard let firstRow = rows.first,
                  case .topSpacer(let height) = firstRow.node.row
            else { return nil }
            return max(height, SpacingTokens.micro)
        }

        private func adjustedScrollPosition(
            _ scrollY: CGFloat,
            oldTopSpacerHeight: CGFloat?,
            newTopSpacerHeight: CGFloat?
        ) -> CGFloat {
            guard let oldTopSpacerHeight,
                  let newTopSpacerHeight,
                  scrollY > oldTopSpacerHeight
            else { return scrollY }

            return scrollY + newTopSpacerHeight - oldTopSpacerHeight
        }

        private func restoreScrollPosition(y: CGFloat) {
            guard let scrollView = tableView.enclosingScrollView else { return }
            let clipView = scrollView.contentView
            let maxY = max(0, tableView.bounds.height - clipView.bounds.height)
            let clampedY = min(max(0, y), maxY)
            clipView.scroll(to: NSPoint(x: 0, y: clampedY))
            scrollView.reflectScrolledClipView(clipView)
        }

        private func scrollRowToTop(_ row: Int) {
            guard let scrollView = tableView.enclosingScrollView, row >= 0, row < tableView.numberOfRows else {
                return
            }
            let clipView = scrollView.contentView
            let rowRect = tableView.rect(ofRow: row)
            let maxY = max(0, tableView.bounds.height - clipView.bounds.height)
            let targetY = min(max(0, rowRect.minY), maxY)
            clipView.scroll(to: NSPoint(x: 0, y: targetY))
            scrollView.reflectScrolledClipView(clipView)
        }
    }
}

@MainActor
final class ObjectBrowserOutlineCellView: NSTableCellView {
    private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    func configure(rootView: AnyView) {
        hostingView.rootView = rootView
    }
}

@MainActor
final class ObjectBrowserClearRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {}
    override func drawBackground(in dirtyRect: NSRect) {}
}
