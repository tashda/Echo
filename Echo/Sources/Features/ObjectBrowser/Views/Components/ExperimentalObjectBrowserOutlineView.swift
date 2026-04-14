import AppKit
import SwiftUI

struct ExperimentalObjectBrowserOutlineView: NSViewRepresentable {
    let roots: [ExperimentalObjectBrowserNode]
    let expandedNodeIDs: Set<String>
    let selectedNodeID: String?
    let rowContent: (ExperimentalObjectBrowserNode, Bool, Int, CGFloat, @escaping () -> Void) -> AnyView
    let onExpansionChanged: (ExperimentalObjectBrowserNode, Bool) -> Void
    let onActivation: (ExperimentalObjectBrowserNode) -> Void
    let onSelectionChanged: (ExperimentalObjectBrowserNode?) -> Void
    let revealNodeID: String?
    let revealRequestID: Int

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
        scrollView.contentInsets = NSEdgeInsets(
            top: 0,
            left: 0,
            bottom: ExplorerSidebarConstants.scrollBottomPadding + SpacingTokens.md2,
            right: 0
        )

        scrollView.documentView = context.coordinator.tableView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.rowContent = rowContent
        context.coordinator.onExpansionChanged = onExpansionChanged
        context.coordinator.onActivation = onActivation
        context.coordinator.onSelectionChanged = onSelectionChanged
        context.coordinator.update(
            roots: roots,
            expandedNodeIDs: expandedNodeIDs,
            selectedNodeID: selectedNodeID,
            revealNodeID: revealNodeID,
            revealRequestID: revealRequestID
        )
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        struct VisibleRow {
            let node: ExperimentalObjectBrowserNode
            let depth: Int
        }

        let tableView: NSTableView
        var rowContent: (ExperimentalObjectBrowserNode, Bool, Int, CGFloat, @escaping () -> Void) -> AnyView
        var onExpansionChanged: (ExperimentalObjectBrowserNode, Bool) -> Void
        var onActivation: (ExperimentalObjectBrowserNode) -> Void
        var onSelectionChanged: (ExperimentalObjectBrowserNode?) -> Void

        private var roots: [ExperimentalObjectBrowserNode] = []
        private var expandedNodeIDs: Set<String> = []
        private var selectedNodeID: String?
        private var visibleRows: [VisibleRow] = []
        private var lastVisibleSignature: [String] = []
        private var lastRevealRequestID = 0

        init(
            rowContent: @escaping (ExperimentalObjectBrowserNode, Bool, Int, CGFloat, @escaping () -> Void) -> AnyView,
            onExpansionChanged: @escaping (ExperimentalObjectBrowserNode, Bool) -> Void,
            onActivation: @escaping (ExperimentalObjectBrowserNode) -> Void,
            onSelectionChanged: @escaping (ExperimentalObjectBrowserNode?) -> Void
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
            roots: [ExperimentalObjectBrowserNode],
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
            let newVisibleRows = flattenVisibleRows(from: roots, expandedNodeIDs: expandedNodeIDs)
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

            tableView.deselectAll(nil)

            if let preservedScrollY {
                restoreScrollPosition(y: preservedScrollY)
            }

            if shouldReveal, let revealNodeID {
                reveal(nodeID: revealNodeID)
                lastRevealRequestID = revealRequestID
            }
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            visibleRows.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard visibleRows.indices.contains(row) else { return nil }

            let visibleRow = visibleRows[row]
            let node = visibleRow.node
            let identifier = NSUserInterfaceItemIdentifier("ExperimentalOutlineCell")
            let cell = (tableView.makeView(withIdentifier: identifier, owner: nil) as? ExperimentalTableCellView)
                ?? ExperimentalTableCellView(identifier: identifier)

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
            ExperimentalClearRowView()
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            guard visibleRows.indices.contains(row) else { return 25 }
            if case .topSpacer(let height) = visibleRows[row].node.row {
                return height
            }
            return 25
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
                      let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? ExperimentalTableCellView
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
                context.duration = 0.12
                tableView.beginUpdates()
                if !removed.isEmpty {
                    tableView.removeRows(at: removed, withAnimation: [.slideUp])
                }
                if !inserted.isEmpty {
                    tableView.insertRows(at: inserted, withAnimation: [.slideDown])
                }
                tableView.endUpdates()
            }
            refreshVisibleRows()
        }

        private func flattenVisibleRows(
            from roots: [ExperimentalObjectBrowserNode],
            expandedNodeIDs: Set<String>
        ) -> [VisibleRow] {
            var rows: [VisibleRow] = []

            func append(nodes: [ExperimentalObjectBrowserNode], depth: Int) {
                for node in nodes {
                    rows.append(VisibleRow(node: node, depth: depth))
                    guard expandedNodeIDs.contains(node.id) else { continue }
                    append(nodes: node.children, depth: childDepth(for: node, currentDepth: depth))
                }
            }

            append(nodes: roots, depth: 0)
            return rows
        }

        private func childDepth(for node: ExperimentalObjectBrowserNode, currentDepth: Int) -> Int {
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
                    .securityLogin, .securityServerRole, .securityCredential, .databaseNamedItem:
                currentDepth + 1
            }
        }

        private func findNode(
            id: String,
            in nodes: [ExperimentalObjectBrowserNode]
        ) -> ExperimentalObjectBrowserNode? {
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
final class ExperimentalTableCellView: NSTableCellView {
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
final class ExperimentalClearRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {}
    override func drawBackground(in dirtyRect: NSRect) {}
}
