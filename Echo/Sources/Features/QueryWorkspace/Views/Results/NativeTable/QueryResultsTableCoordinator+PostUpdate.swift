#if os(macOS)
import SwiftUI
import AppKit

extension QueryResultsTableView.Coordinator {
    func applyPostUpdateActions(
        columnsChanged: Bool,
        sortChanged: Bool,
        rowOrderChanged: Bool,
        rowCountIncreased: Bool,
        rowCountDecreased: Bool,
        viewportContribution: Bool,
        paletteChanged: Bool,
        performedFullReload: Bool,
        currentRowCount: Int,
        dirtyToken: UInt64,
        tableView: NSTableView
    ) {
        if columnsChanged {
            setSelectionRegion(nil, tableView: tableView)
            applyHeaderStyle(to: tableView)
            refreshVisibleRowBackgrounds(tableView)
        }

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
    }
}
#endif
