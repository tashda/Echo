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
        // Preserve selection state during active cell drags to prevent
        // intermittent drag failures when table updates occur mid-drag.
        let preserveSelection = isDraggingSelection

        if columnsChanged {
            if !preserveSelection {
                setSelectionRegion(nil, tableView: tableView)
            }
            applyHeaderStyle(to: tableView)
            refreshVisibleRowBackgrounds(tableView)
        }

        if rowOrderChanged && !preserveSelection {
            setSelectionRegion(nil, tableView: tableView)
        }

        if !preserveSelection, let region = selectionRegion {
            let maxRow = tableView.numberOfRows
            let maxColumn = parent.displayedColumns.count
            if maxRow == 0 || maxColumn == 0 || region.normalizedRowRange.upperBound >= maxRow || region.normalizedColumnRange.upperBound >= maxColumn {
                setSelectionRegion(nil, tableView: tableView)
            }
        }

        if !preserveSelection && parent.isExecuting && parent.displayedRowCount == 0 {
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
            // Debounce palette refresh to avoid overwhelming updates during continuous
            // ColorPicker changes — coalesce into a single refresh after 200ms
            pendingPaletteRefresh?.cancel()
            pendingPaletteRefresh = Task { @MainActor [weak self, weak tableView] in
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, let tableView, !Task.isCancelled else { return }
                self.pendingPaletteRefresh = nil
                self.deactivateActiveSelectableField(in: tableView)
                self.cachedFontStyles.removeAll(keepingCapacity: true)
                self.cachedResultGridStyles.removeAll(keepingCapacity: true)
                self.cachedTextColors.removeAll(keepingCapacity: true)
                self.applyHeaderStyle(to: tableView)
                self.refreshVisibleRowBackgrounds(tableView)
                self.refreshVisibleCellsAppearance(tableView)
            }
        }

        if performedFullReload || rowCountIncreased {
            let qs = queryState
            let totalAvailableRowCount = qs.totalAvailableRowCount
            Task { @MainActor in
                qs.recordTableViewUpdate(
                    visibleRowCount: currentRowCount,
                    totalAvailableRowCount: totalAvailableRowCount
                )
            }
        }

        if let state = persistedState {
            state.cachedColumnIDs = cachedColumnIDs
            state.cachedRowOrder = cachedRowOrder
            state.cachedSort = cachedSort
            state.lastRowCount = lastRowCount
            state.lastResultToken = dirtyToken
        }

        // Persist column widths after structural changes so tab switches
        // can restore them instantly without expensive re-measurement.
        if columnsChanged || performedFullReload {
            saveColumnWidths()
        }
    }
}
#endif
