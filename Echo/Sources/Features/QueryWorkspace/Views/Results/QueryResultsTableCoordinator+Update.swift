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

        cachedSort = parent.activeSort
        cachedRowOrder = currentRowOrder
        lastRowCount = currentRowCount
        lastResultTokenSnapshot = dirtyToken

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
