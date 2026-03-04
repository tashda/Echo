#if os(macOS)
import SwiftUI
import AppKit
import Combine

extension QueryResultsTableView {
    @MainActor
    final class Coordinator: NSObject {
        var parent: QueryResultsTableView
        let clipboardHistory: ClipboardHistoryStore
        weak var tableView: NSTableView?
        weak var scrollView: NSScrollView?
        weak var observedContentView: NSView?
        let headerMenu = NSMenu()
        let cellMenu = NSMenu()
        var menuColumnIndex: Int?
        var cachedColumnIDs: [String] = []
        var cachedColumnKinds: [ResultGridValueKind] = []
        var cachedRowOrder: [Int] = []
        var cachedSort: SortCriteria?
        var lastRowCount: Int = 0
        var lastResultTokenSnapshot: UInt64 = 0
        var persistedState: QueryResultsGridState?
        var selectionRegion: SelectedRegion?
        var selectionAnchor: QueryResultsTableView.SelectedCell?
        var isDraggingCellSelection = false
        var selectionFocus: QueryResultsTableView.SelectedCell?
        var columnSelectionAnchor: Int?
        var contextMenuCell: QueryResultsTableView.SelectedCell?
        weak var activeSelectableField: NSTextField?
        var cachedPaletteSignature: String?
        var cachedFontStyles: [SQLEditorTokenPalette.ResultGridStyle: NSFont] = [:]
        let cellBaseFont = NSFont.systemFont(ofSize: 12)
        var lastForeignKeySelection: QueryResultsTableView.ForeignKeySelection?
        var lastForeignKeyDisplayMode: ForeignKeyDisplayMode?
        var lastForeignKeyInspectorBehavior: ForeignKeyInspectorBehavior?
        var lastJsonSelection: QueryResultsTableView.JsonSelection?
        var cachedViewportSize: CGSize = .zero
        var pendingPaginationEvaluation = false
        var pendingTableSizeAdjustment = false
        var lastParentIsResizing = false
        var requestedForeignKeyColumns: Set<Int> = []
        var lastSelectionHighlightStyle: NSTableView.SelectionHighlightStyle?
        var cachedDisplayedRows: [Int: [String?]] = [:]
        var cachedResultGridStyles: [ResultGridValueKind: SQLEditorTokenPalette.ResultGridStyle] = [:]
        var cachedTextColors: [ResultGridValueKind: NSColor] = [:]
        var autoscrollTimer: Timer?
        var autoscrollVelocity: CGPoint = .zero
        var lastDragLocationInWindow: NSPoint = .zero
        let autoscrollPadding: CGFloat = 28
        let autoscrollMaxSpeed: CGFloat = 900
        let defaultAutoscrollInterval: TimeInterval = 1.0 / 60.0
        var autoscrollTimerInterval: TimeInterval = 1.0 / 60.0
        var pendingReloadWorkItems: [DispatchWorkItem] = []
        var pendingRowCountCorrection = false
        nonisolated(unsafe) var rowCountObserver: NSObjectProtocol?
        var isPerformingUpdatePass = false
        nonisolated(unsafe) var rowCountUpdateWorkItem: DispatchWorkItem?
        static let isGridDiagnosticsEnabled: Bool = {
            ProcessInfo.processInfo.environment["ECHO_GRID_DEBUG"] == "1"
        }()

        init(_ parent: QueryResultsTableView, clipboardHistory: ClipboardHistoryStore, persistedState: QueryResultsGridState?) {
            self.parent = parent
            self.clipboardHistory = clipboardHistory
            self.persistedState = persistedState
            if let state = persistedState {
                self.cachedColumnIDs = state.cachedColumnIDs
                self.cachedRowOrder = state.cachedRowOrder
                self.cachedSort = state.cachedSort
                self.lastRowCount = state.lastRowCount
                self.lastResultTokenSnapshot = state.lastResultToken
            }
            super.init()
            headerMenu.delegate = self
            cellMenu.delegate = self
        }

        deinit {
            if let observer = rowCountObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            NotificationCenter.default.removeObserver(self)
            rowCountUpdateWorkItem?.cancel()
        }

        func configure(tableView: NSTableView, scrollView: NSScrollView) {
            self.tableView = tableView
            self.scrollView = scrollView
            registerScrollObservation(for: scrollView)
            tableView.delegate = self
            tableView.dataSource = self
            tableView.menu = cellMenu
            tableView.headerView?.menu = headerMenu
            tableView.headerView?.frame.size.height = max(tableView.headerView?.frame.size.height ?? 0, 28)
            tableView.headerView?.isHidden = false
            tableView.selectionHighlightStyle = .regular
            tableView.usesAlternatingRowBackgroundColors = false
            _ = reloadColumns()
            applyHeaderStyle(to: tableView)
            refreshVisibleRowBackgrounds(tableView)
            cachedPaletteSignature = paletteSignature()

            adjustTableSize()
            lastForeignKeyDisplayMode = parent.foreignKeyDisplayMode
            lastForeignKeyInspectorBehavior = parent.foreignKeyInspectorBehavior
        }

        func updatePersistedState(_ state: QueryResultsGridState?) {
            guard persistedState !== state else { return }
            persistedState = state
            installRowCountObserver(for: state)
            if let state {
                cachedColumnIDs = state.cachedColumnIDs
                cachedRowOrder = state.cachedRowOrder
                cachedSort = state.cachedSort
                lastRowCount = state.lastRowCount
                lastResultTokenSnapshot = state.lastResultToken
            }
        }

        func update(parent: QueryResultsTableView, tableView: NSTableView) {
            self.parent = parent
            if self.tableView == nil {
                self.tableView = tableView
            }
            if scrollView == nil {
                scrollView = tableView.enclosingScrollView
            }
            if let scrollView {
                registerScrollObservation(for: scrollView)
            }
            if pendingRowCountCorrection, rowCountUpdateWorkItem == nil {
                scheduleRowCountUpdate(for: tableView)
            }
            tableView.headerView?.menu = headerMenu
            tableView.headerView?.frame.size.height = max(tableView.headerView?.frame.size.height ?? 0, 28)
            tableView.headerView?.isHidden = false
            isPerformingUpdatePass = true
            defer {
                isPerformingUpdatePass = false
            }

            let currentRowOrder = parent.rowOrder
            let currentRowCount = currentRowOrder.isEmpty ? parent.query.displayedRowCount : currentRowOrder.count
            let wasResizing = lastParentIsResizing
            cachedDisplayedRows.removeAll(keepingCapacity: true)
            defer {
                let endedResize = wasResizing && !parent.isResizing
                lastParentIsResizing = parent.isResizing
                if endedResize {
                    requestTableSizeAdjustment(rowCount: currentRowCount)
                    requestPaginationEvaluation()
                }
            }
            let columnsChanged = reloadColumns()
            let sortChanged = parent.activeSort != cachedSort
            let rowOrderChanged = currentRowOrder != cachedRowOrder
            let currentPaletteSignature = paletteSignature()
            let paletteChanged = currentPaletteSignature != cachedPaletteSignature
            cachedPaletteSignature = currentPaletteSignature
            let dirtyToken = parent.query.resultChangeToken
            let tokenChanged = dirtyToken != lastResultTokenSnapshot
            let pendingRowReloadIndexes = parent.query.consumePendingVisibleRowReloadIndexes()
            let rowCountDecreased = currentRowCount < lastRowCount
            let rowCountIncreased = currentRowCount > lastRowCount
            let currentViewportSize = scrollView?.contentView.bounds.size ?? .zero
            let viewportChanged = abs(currentViewportSize.width - cachedViewportSize.width) > 0.5
                || abs(currentViewportSize.height - cachedViewportSize.height) > 0.5
            if viewportChanged {
                cachedViewportSize = currentViewportSize
            }
            let hasPendingRowReloads = pendingRowReloadIndexes?.isEmpty == false
            let foreignKeyModeChanged = lastForeignKeyDisplayMode != parent.foreignKeyDisplayMode
                || lastForeignKeyInspectorBehavior != parent.foreignKeyInspectorBehavior
            let resizing = parent.isResizing
            let viewportContribution = !resizing && viewportChanged
            let requiresUpdate = columnsChanged
                || sortChanged
                || rowOrderChanged
                || rowCountIncreased
                || rowCountDecreased
                || tokenChanged
                || hasPendingRowReloads
                || paletteChanged
                || viewportContribution
                || foreignKeyModeChanged
            if columnsChanged || tokenChanged || rowCountDecreased {
                requestedForeignKeyColumns.removeAll()
            }
            if !requiresUpdate {
                cachedSort = parent.activeSort
                cachedRowOrder = currentRowOrder
                lastRowCount = currentRowCount
                lastResultTokenSnapshot = dirtyToken
                if let state = persistedState {
                    state.cachedColumnIDs = cachedColumnIDs
                    state.cachedRowOrder = cachedRowOrder
                    state.cachedSort = cachedSort
                    state.lastRowCount = lastRowCount
                    state.lastResultToken = dirtyToken
                }
                return
            }

            var performedFullReload = false
            var reloadWorkItem: DispatchWorkItem?

            if columnsChanged || sortChanged || rowOrderChanged || rowCountDecreased {
                performedFullReload = true
                reloadWorkItem = DispatchWorkItem { [weak tableView] in
                    guard let tableView else { return }
                    tableView.reloadData()
                }
            } else if rowCountIncreased {
                scheduleRowCountUpdate(for: tableView)
            } else if tokenChanged {
                let visibleRows = tableView.rows(in: tableView.visibleRect)
                if reloadWorkItem == nil, !tableView.tableColumns.isEmpty {
                    let rowIndexes: IndexSet
                    if var pendingRows = pendingRowReloadIndexes, !pendingRows.isEmpty {
                        let clampedVisible = IndexSet(integersIn: 0..<tableView.numberOfRows)
                        pendingRows = pendingRows.intersection(clampedVisible)
                        rowIndexes = pendingRows
                    } else if visibleRows.length > 0 {
                        let lower = max(visibleRows.location, 0)
                        let upper = min(tableView.numberOfRows, lower + visibleRows.length)
                        if upper <= lower {
                            rowIndexes = IndexSet()
                        } else {
                            rowIndexes = IndexSet(integersIn: lower..<upper)
                        }
                    } else {
                        rowIndexes = IndexSet()
                    }

                    if !rowIndexes.isEmpty {
                        let columnIndexes = IndexSet(0..<tableView.tableColumns.count)
                        reloadWorkItem = DispatchWorkItem { [weak tableView] in
                            guard let tableView else { return }
                            tableView.reloadData(forRowIndexes: rowIndexes, columnIndexes: columnIndexes)
                        }
                    }
                }
            }

            if columnsChanged {
                setSelectionRegion(nil, tableView: tableView)
                applyHeaderStyle(to: tableView)
                refreshVisibleRowBackgrounds(tableView)
            }

            cachedSort = parent.activeSort
            cachedRowOrder = currentRowOrder
            lastRowCount = currentRowCount
            lastResultTokenSnapshot = dirtyToken

            if rowOrderChanged {
                setSelectionRegion(nil, tableView: tableView)
            }

            if let region = selectionRegion {
                let maxRow = tableView.numberOfRows
                let maxColumn = parent.query.displayedColumns.count
                if maxRow == 0 || maxColumn == 0 || region.normalizedRowRange.upperBound >= maxRow || region.normalizedColumnRange.upperBound >= maxColumn {
                    setSelectionRegion(nil, tableView: tableView)
                }
            }

            if parent.query.isExecuting && parent.query.displayedRowCount == 0 {
                setSelectionRegion(nil, tableView: tableView)
            }

            updateHeaderIndicators()
            let needsSizeAdjustment = viewportContribution
                || columnsChanged
                || sortChanged
                || rowOrderChanged
                || rowCountIncreased
                || rowCountDecreased
            if needsSizeAdjustment {
                requestTableSizeAdjustment(rowCount: currentRowCount)
            }

            if lastForeignKeyDisplayMode != parent.foreignKeyDisplayMode || lastForeignKeyInspectorBehavior != parent.foreignKeyInspectorBehavior {
                lastForeignKeyDisplayMode = parent.foreignKeyDisplayMode
                lastForeignKeyInspectorBehavior = parent.foreignKeyInspectorBehavior
                if reloadWorkItem == nil {
                    performedFullReload = true
                    reloadWorkItem = DispatchWorkItem { [weak tableView] in
                        guard let tableView else { return }
                        tableView.reloadData()
                    }
                } else {
                    performedFullReload = true
                }
                notifyForeignKeySelection(selectionRegion)
            }

            if paletteChanged {
                deactivateActiveSelectableField(in: tableView)
                cachedFontStyles.removeAll(keepingCapacity: true)
                cachedResultGridStyles.removeAll(keepingCapacity: true)
                cachedTextColors.removeAll(keepingCapacity: true)
                applyHeaderStyle(to: tableView)
                refreshVisibleRowBackgrounds(tableView)
                refreshVisibleCellsAppearance(tableView)
            }

            if performedFullReload || rowCountIncreased {
                parent.query.recordTableViewUpdate(
                    visibleRowCount: currentRowCount,
                    totalAvailableRowCount: parent.query.totalAvailableRowCount
                )
            }

            if let state = persistedState {
                state.cachedColumnIDs = cachedColumnIDs
                state.cachedRowOrder = cachedRowOrder
                state.cachedSort = cachedSort
                state.lastRowCount = lastRowCount
                state.lastResultToken = dirtyToken
            }

            if let reloadWorkItem {
                enqueueReloadWorkItem(reloadWorkItem)
            }

            if !resizing && (performedFullReload || rowCountIncreased || rowCountDecreased || viewportChanged) {
                requestPaginationEvaluation()
            }
        }

        // Helper methods
        func resolvedFont(for style: SQLEditorTokenPalette.ResultGridStyle) -> NSFont {
            if let cached = cachedFontStyles[style] {
                return cached
            }
            var traits: NSFontTraitMask = []
            if style.isBold { traits.insert(.boldFontMask) }
            if style.isItalic { traits.insert(.italicFontMask) }
            let font: NSFont
            if traits.isEmpty {
                font = cellBaseFont
            } else {
                font = NSFontManager.shared.convert(cellBaseFont, toHaveTrait: traits)
            }
            cachedFontStyles[style] = font
            return font
        }

        func paletteSignature() -> String {
            return [
                "true",
                "false",
                colorSignature(NSColor(ColorTokens.Background.tertiary)),
                colorSignature(NSColor(ColorTokens.Background.tertiary)),
                colorSignature(NSColor(ColorTokens.Text.primary)),
                colorSignature(NSColor(ColorTokens.Background.secondary)),
                colorSignature(NSColor(ColorTokens.Text.primary))
            ].joined(separator: "|")
        }

        func colorSignature(_ color: NSColor) -> String {
            guard let converted = color.usingColorSpace(.extendedSRGB) else { return color.description }
            func fmt(_ value: CGFloat) -> String { String(format: "%.4f", value) }
            return [converted.redComponent, converted.greenComponent, converted.blueComponent, converted.alphaComponent].map(fmt).joined(separator: ",")
        }

        func debugLog(_ message: String) {
            guard Coordinator.isGridDiagnosticsEnabled else { return }
            print("[GridDebug] \(message)")
        }
    }
}
#endif
