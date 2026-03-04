#if os(iOS)
import UIKit

extension ResultGridViewController {
    internal func beginColumnSelection(at column: Int) {
        guard !columns.isEmpty, displayedRowCount > 0 else { return }
        let clamped = max(0, min(column, columns.count - 1))
        columnSelectionAnchor = clamped
        let lastRow = max(0, displayedRowCount - 1)
        let start = SelectedCell(row: 0, column: clamped)
        let end = SelectedCell(row: lastRow, column: clamped)
        selectionAnchor = start
        selectionFocus = end
        setSelectionRegion(SelectedRegion(start: start, end: end))
        scrollColumnIntoView(clamped)
        becomeFirstResponder()
    }

    internal func continueColumnSelection(to column: Int) {
        guard let anchor = columnSelectionAnchor,
              displayedRowCount > 0,
              !columns.isEmpty else { return }
        let clamped = max(0, min(column, columns.count - 1))
        let lower = min(anchor, clamped)
        let upper = max(anchor, clamped)
        let lastRow = max(0, displayedRowCount - 1)
        let start = SelectedCell(row: 0, column: lower)
        let end = SelectedCell(row: lastRow, column: upper)
        selectionAnchor = start
        selectionFocus = SelectedCell(row: lastRow, column: clamped)
        setSelectionRegion(SelectedRegion(start: start, end: end))
        scrollColumnIntoView(clamped)
        becomeFirstResponder()
    }

    internal func beginRowSelection(at row: Int) {
        guard !columns.isEmpty, displayedRowCount > 0 else { return }
        let clamped = max(0, min(row, displayedRowCount - 1))
        rowSelectionAnchor = clamped
        let lastColumn = columns.count - 1
        let start = SelectedCell(row: clamped, column: 0)
        let end = SelectedCell(row: clamped, column: lastColumn)
        selectionAnchor = start
        selectionFocus = end
        setSelectionRegion(SelectedRegion(start: start, end: end))
        scrollRowIntoView(clamped)
        becomeFirstResponder()
    }

    internal func continueRowSelection(to row: Int) {
        guard let anchor = rowSelectionAnchor,
              !columns.isEmpty,
              displayedRowCount > 0 else { return }
        let clamped = max(0, min(row, displayedRowCount - 1))
        let lower = min(anchor, clamped)
        let upper = max(anchor, clamped)
        let lastColumn = columns.count - 1
        let start = SelectedCell(row: lower, column: 0)
        let end = SelectedCell(row: upper, column: lastColumn)
        selectionAnchor = start
        selectionFocus = SelectedCell(row: clamped, column: lastColumn)
        setSelectionRegion(SelectedRegion(start: start, end: end))
        scrollRowIntoView(clamped)
        becomeFirstResponder()
    }

    internal func beginCellSelection(at cell: SelectedCell) {
        selectionAnchor = cell
        selectionFocus = cell
        setSelectionRegion(SelectedRegion(start: cell, end: cell))
        scrollRowIntoView(cell.row)
        scrollColumnIntoView(cell.column)
        becomeFirstResponder()
    }

    internal func continueCellSelection(to cell: SelectedCell, extend: Bool) {
        ensureSelectionSeed()
        if extend, let anchor = selectionAnchor {
            let region = SelectedRegion(start: anchor, end: cell)
            selectionFocus = cell
            setSelectionRegion(region)
        } else {
            selectionAnchor = cell
            selectionFocus = cell
            setSelectionRegion(SelectedRegion(start: cell, end: cell))
        }
        scrollRowIntoView(cell.row)
        scrollColumnIntoView(cell.column)
        becomeFirstResponder()
    }

    internal func finalizeDragSelection() {
        dragContext = nil
        columnSelectionAnchor = nil
        rowSelectionAnchor = nil
    }

    internal func scrollRowIntoView(_ row: Int) {
        guard row >= 0, row < displayedRowCount else { return }
        let indexPath = IndexPath(item: 1, section: row + 1)
        collectionView.scrollToItem(at: indexPath, at: [.centeredVertically], animated: false)
    }

    internal func scrollColumnIntoView(_ column: Int) {
        guard column >= 0, column < columns.count else { return }
        let indexPath = IndexPath(item: column + 1, section: 1)
        collectionView.scrollToItem(at: indexPath, at: [.centeredHorizontally], animated: false)
    }

    internal func moveSelection(rowDelta: Int, columnDelta: Int, extend: Bool) {
        guard displayedRowCount > 0, !columns.isEmpty else { return }
        ensureSelectionSeed()
        guard var focus = selectionFocus ?? selectionRegion?.end else { return }

        if rowDelta == Int.max {
            focus.row = displayedRowCount - 1
        } else if rowDelta == -Int.max {
            focus.row = 0
        } else {
            focus.row = max(0, min(displayedRowCount - 1, focus.row + rowDelta))
        }

        if columnDelta == Int.max {
            focus.column = columns.count - 1
        } else if columnDelta == -Int.max {
            focus.column = 0
        } else {
            focus.column = max(0, min(columns.count - 1, focus.column + columnDelta))
        }

        if extend, let anchor = selectionAnchor {
            selectionFocus = focus
            setSelectionRegion(SelectedRegion(start: anchor, end: focus))
        } else {
            selectionAnchor = focus
            selectionFocus = focus
            setSelectionRegion(SelectedRegion(start: focus, end: focus))
        }

        scrollRowIntoView(focus.row)
        scrollColumnIntoView(focus.column)
    }

    internal func pageJumpAmount() -> Int {
        let visibleHeight = collectionView.bounds.height
        return max(1, Int(visibleHeight / ResultGridMetrics.rowHeight) - 1)
    }

    internal func copySelection(includeHeaders: Bool) {
        guard let query = query, !columns.isEmpty else { return }
        let totalRows = query.totalAvailableRowCount
        guard totalRows > 0 else { return }

        let columnIndices: [Int]
        let rowIndices: [Int]

        if let region = selectionRegion {
            let lowerColumn = max(0, min(columns.count - 1, region.normalizedColumnRange.lowerBound))
            let upperColumn = max(0, min(columns.count - 1, region.normalizedColumnRange.upperBound))
            guard upperColumn >= lowerColumn else { return }
            columnIndices = Array(lowerColumn...upperColumn)

            let lowerRow = max(0, min(displayedRowCount - 1, region.normalizedRowRange.lowerBound))
            let upperRow = max(0, min(displayedRowCount - 1, region.normalizedRowRange.upperBound))
            guard upperRow >= lowerRow else { return }
            rowIndices = Array(lowerRow...upperRow)
        } else {
            rowIndices = Array(0..<displayedRowCount)
            columnIndices = Array(0..<columns.count)
        }

        guard !rowIndices.isEmpty, !columnIndices.isEmpty else { return }

        var lines: [String] = []
        if includeHeaders {
            let headers = columnIndices.map { columns[$0].name }
            lines.append(headers.joined(separator: "\t"))
        }

        for displayedRow in rowIndices {
            let dataRow = resolvedDataRowIndex(forDisplayed: displayedRow)
            guard dataRow >= 0, dataRow < totalRows else { continue }
            let values = columnIndices.map { query.valueForDisplay(row: dataRow, column: $0) ?? "" }
            lines.append(values.joined(separator: "\t"))
        }

        guard !lines.isEmpty else { return }

        let export = lines.joined(separator: "\n")
        PlatformClipboard.copy(export)
        clipboardHistory?.record(
            .resultGrid(includeHeaders: includeHeaders),
            content: export,
            metadata: query.clipboardMetadata
        )
    }

    internal func setSelectionRegion(_ region: SelectedRegion?) {
        selectionRegion = region
        refreshVisibleCells()
    }

    internal func ensureSelectionSeed() {
        guard selectionRegion == nil else { return }
        guard displayedRowCount > 0, !columns.isEmpty else { return }
        let seed = SelectedCell(row: 0, column: 0)
        selectionRegion = SelectedRegion(start: seed, end: seed)
        selectionAnchor = seed
        selectionFocus = seed
        refreshVisibleCells()
    }
}
#endif
