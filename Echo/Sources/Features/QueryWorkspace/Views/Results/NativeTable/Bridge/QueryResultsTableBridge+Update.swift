#if os(macOS)
import SwiftUI
import AppKit
import Combine

extension QueryResultsTableView.Coordinator {
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

        // Detect new query execution — schedule an immediate full reload so the
        // table visually clears before streaming data arrives. Uses
        // DispatchQueue.main.async (not Task) to avoid "modifying state during
        // view update" and to run before streaming callbacks.
        let isExecuting = parent.query.isExecuting
        let executionJustStarted = isExecuting && !lastSeenExecuting
        lastSeenExecuting = isExecuting
        if executionJustStarted {
            suppressRowsDuringClear = true
            cachedDisplayedRows.clear()
            requestedForeignKeyColumns.removeAll()
            lastRowCount = 0
            lastResultTokenSnapshot = 0
            DispatchQueue.main.async { [weak tableView] in
                tableView?.reloadData()
            }
        }

        let currentRowOrder = parent.rowOrder
        let currentRowCount = currentRowOrder.isEmpty ? parent.query.displayedRowCount : currentRowOrder.count
        let wasResizing = lastParentIsResizing
        defer {
            let endedResize = wasResizing && !isSplitResizing
            lastParentIsResizing = isSplitResizing
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
        let resizing = isSplitResizing || isResizingColumn
        let viewportContribution = !resizing && viewportChanged
        if suppressRowsDuringClear, currentRowCount > 0 || tokenChanged || columnsChanged || sortChanged || rowOrderChanged || !isExecuting {
            suppressRowsDuringClear = false
        }
        // Palette changes are handled by a debounced task in applyPostUpdateActions,
        // so they don't need to trigger the main update/reload path.
        let requiresUpdate = columnsChanged
            || sortChanged
            || rowOrderChanged
            || rowCountIncreased
            || rowCountDecreased
            || tokenChanged
            || hasPendingRowReloads
            || viewportContribution
        if columnsChanged || tokenChanged || rowCountDecreased {
            requestedForeignKeyColumns.removeAll()
            cachedDisplayedRows.clear()
        } else if rowOrderChanged || rowCountIncreased {
            cachedDisplayedRows.clear()
        }
        if !requiresUpdate {
            // Handle palette-only changes via the debounced refresh path
            if paletteChanged {
                applyPostUpdateActions(
                    columnsChanged: false, sortChanged: false, rowOrderChanged: false,
                    rowCountIncreased: false, rowCountDecreased: false,
                    viewportContribution: false, paletteChanged: true,
                    performedFullReload: false, currentRowCount: currentRowCount,
                    dirtyToken: dirtyToken, tableView: tableView
                )
            }
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

        cachedSort = parent.activeSort
        cachedRowOrder = currentRowOrder
        lastRowCount = currentRowCount
        lastResultTokenSnapshot = dirtyToken

        applyPostUpdateActions(
            columnsChanged: columnsChanged,
            sortChanged: sortChanged,
            rowOrderChanged: rowOrderChanged,
            rowCountIncreased: rowCountIncreased,
            rowCountDecreased: rowCountDecreased,
            viewportContribution: viewportContribution,
            paletteChanged: paletteChanged,
            performedFullReload: performedFullReload,
            currentRowCount: currentRowCount,
            dirtyToken: dirtyToken,
            tableView: tableView
        )

        if let reloadWorkItem {
            enqueueReloadWorkItem(reloadWorkItem)
        }

        if !resizing && (performedFullReload || rowCountIncreased || rowCountDecreased || viewportChanged) {
            requestPaginationEvaluation()
        }
    }
}
#endif
