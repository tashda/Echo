#if os(macOS)
import AppKit
import SwiftUI

extension QueryResultsTableView.Coordinator: NSTableViewDelegate, NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        parent.rowOrder.isEmpty ? parent.query.displayedRowCount : parent.rowOrder.count
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = ResultTableRowView()
        rowView.configure(
            row: row,
            colorProvider: { [weak self] index in
                self?.rowBackgroundColor(for: index) ?? NSColor(ColorTokens.Background.tertiary)
            },
            highlightProvider: { [weak self, weak tableView] view, index in
                guard let self, let tableView else { return nil }
                return self.selectionRenderInfo(forRow: index, rowView: view, tableView: tableView)
            }
        )
        return rowView
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn else { return nil }
        guard let dataIndex = dataColumnIndex(for: tableColumn) else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("data-cell-\(dataIndex)")
        let cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? ResultTableDataCellView ?? makeDataCellView(identifier: identifier)
        configureCellView(cellView, dataIndex: dataIndex, tableView: tableView, row: row)
        cellView.frame = NSRect(x: 0, y: 0, width: tableColumn.width, height: tableView.rowHeight)
        return cellView
    }

    func tableView(_ tableView: NSTableView, shouldReorderColumn columnIndex: Int, toColumn newColumnIndex: Int) -> Bool {
        false
    }

    func tableView(_ tableView: NSTableView, sizeToFitWidthOfColumn column: Int) -> CGFloat {
        guard column >= 0, column < tableView.tableColumns.count else { return 0 }
        guard column < parent.query.displayedColumns.count else {
            return max(tableView.tableColumns[column].minWidth, tableView.tableColumns[column].width)
        }

        let tableColumn = tableView.tableColumns[column]
        let headerWidth = headerContentWidth(for: tableColumn, in: tableView)
        let contentWidth = widestCellWidth(forColumn: column, tableView: tableView)
        let desired = max(headerWidth, contentWidth)
        let minWidth = tableColumn.minWidth
        let maxWidth = tableColumn.maxWidth > 0 ? tableColumn.maxWidth : CGFloat.greatestFiniteMagnitude
        return min(max(desired, minWidth), maxWidth)
    }

    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
        guard let dataIndex = dataColumnIndex(for: tableColumn) else { return }
        parent.onColumnTap(dataIndex)
        selectColumn(at: dataIndex, in: tableView)
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let clickedColumn = tableView.clickedColumn
        if clickedColumn >= 0 {
            let cell = QueryResultsTableView.SelectedCell(row: row, column: clickedColumn)
            setSelectionRegion(SelectedRegion(start: cell, end: cell), tableView: tableView)
            isDraggingCellSelection = true
            return false
        }

        if let event = NSApp.currentEvent {
            let location = tableView.convert(event.locationInWindow, from: nil)
            let column = tableView.column(at: location)
            if column >= 0 {
                let cell = QueryResultsTableView.SelectedCell(row: row, column: column)
                setSelectionRegion(SelectedRegion(start: cell, end: cell), tableView: tableView)
                endSelectionDrag()
                return false
            }
        }

        return true
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView else { return }
        let hasRowSelection = !tableView.selectedRowIndexes.isEmpty

        if selectionRegion != nil, hasRowSelection {
            tableView.deselectAll(nil)
            return
        }

        if hasRowSelection {
            endSelectionDrag()
            setSelectionRegion(nil, tableView: tableView)
        }
    }

    // MARK: - Internal Helpers

    func rowBackgroundColor(for row: Int) -> NSColor {
        return NSColor(ColorTokens.Background.tertiary)
    }

    func dataColumnIndex(for tableColumn: NSTableColumn) -> Int? {
        guard let tableView else { return nil }
        guard let index = tableView.tableColumns.firstIndex(of: tableColumn) else { return nil }
        return index
    }

    func reloadColumns() -> Bool {
        guard let tableView else { return false }

        let columnIDs = parent.query.displayedColumns.map(\.id)
        let desiredColumnCount = columnIDs.count
        let columnsChanged = tableView.tableColumns.count != desiredColumnCount || columnIDs != cachedColumnIDs
        var headerNeedsRefresh = false

        if columnsChanged {
            while tableView.tableColumns.count > 0 {
                tableView.removeTableColumn(tableView.tableColumns[0])
            }

            addDataColumns(to: tableView)
            headerNeedsRefresh = true
        } else {
            for (offset, column) in parent.query.displayedColumns.enumerated() {
                let tableColumn = tableView.tableColumns[offset]
                if tableColumn.title != column.name {
                    tableColumn.title = column.name
                    headerNeedsRefresh = true
                }
                let minWidth = defaultWidth(for: column)
                if abs(tableColumn.minWidth - minWidth) > 1 {
                    tableColumn.minWidth = minWidth
                    if tableColumn.width < minWidth {
                        tableColumn.width = minWidth
                    }
                }
                tableColumn.headerCell.alignment = .left
            }
        }

        tableView.headerView?.needsDisplay = true
        if headerNeedsRefresh {
            applyHeaderStyle(to: tableView)
        }
        cachedColumnKinds = parent.query.displayedColumns.map { column in
            ResultGridValueClassifier.kind(for: column, value: "")
        }
        cachedColumnIDs = columnIDs
        return columnsChanged
    }

    func addDataColumns(to tableView: NSTableView) {
        for column in parent.query.displayedColumns {
            let identifier = NSUserInterfaceItemIdentifier("data-\(column.id)")
            let tableColumn = NSTableColumn(identifier: identifier)
            tableColumn.title = column.name
            tableColumn.minWidth = defaultWidth(for: column)
            tableColumn.width = tableColumn.minWidth
            tableColumn.isEditable = false
            tableColumn.resizingMask = [.userResizingMask]
            if !(tableColumn.headerCell is ResultTableHeaderCell) {
                tableColumn.headerCell = ResultTableHeaderCell(textCell: column.name)
            }
            tableColumn.headerCell.controlSize = .regular
            tableColumn.headerCell.alignment = .left
            tableColumn.headerCell.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
            if let dataCell = tableColumn.dataCell as? NSTextFieldCell {
                dataCell.alignment = .left
            }
            tableView.addTableColumn(tableColumn)
        }
    }

    func defaultWidth(for column: ColumnInfo) -> CGFloat {
        let type = column.dataType.lowercased()
        if type.contains("bool") { return 80 }
        if type.contains("int") || type.contains("numeric") || type.contains("decimal") || type.contains("float") || type.contains("double") || type.contains("money") {
            return 120
        }
        if type.contains("date") || type.contains("time") { return 160 }
        return 200
    }

    func headerContentWidth(for column: NSTableColumn, in tableView: NSTableView) -> CGFloat {
        let baseString: NSString
        let attributes: [NSAttributedString.Key: Any]
        if column.headerCell.attributedStringValue.length > 0 {
            baseString = column.headerCell.attributedStringValue.string as NSString
            attributes = column.headerCell.attributedStringValue.attributes(at: 0, effectiveRange: nil)
        } else {
            baseString = column.title as NSString
            attributes = [
                .font: column.headerCell.font ?? NSFont.systemFont(ofSize: 12, weight: .semibold)
            ]
        }
        let size = baseString.size(withAttributes: attributes)
        let indicatorWidth: CGFloat = tableView.indicatorImage(in: column) != nil ? 16 : 0
        let padding = ResultsGridMetrics.horizontalPadding * 2
        return ceil(size.width) + padding + indicatorWidth + 4
    }

    func widestCellWidth(forColumn column: Int, tableView: NSTableView) -> CGFloat {
        guard column >= 0 else { return 0 }
        let rowCount = tableView.numberOfRows
        guard rowCount > 0 else { return 0 }

        let padding = ResultsGridMetrics.horizontalPadding * 2
        let columnInfo = column < parent.query.displayedColumns.count ? parent.query.displayedColumns[column] : nil

        var maxWidth = CGFloat.zero
        let sampleCount = parent.isResizing ? min(rowCount, 32) : min(rowCount, ResultsGridMetrics.maxAutoWidthSampleCount)
        if sampleCount == 0 {
            return ceil(maxWidth) + padding + 6
        }
        var sampledRows: [Int] = []
        sampledRows.reserveCapacity(sampleCount)
        if sampleCount == rowCount {
            sampledRows = Array(0..<rowCount)
        } else {
            let step = max(1, rowCount / sampleCount)
            var index = 0
            while index < rowCount && sampledRows.count < sampleCount {
                sampledRows.append(index)
                index += step
            }
            if sampledRows.count < sampleCount, let last = sampledRows.last {
                for tail in Swift.stride(from: rowCount - 1, through: last, by: -1) {
                    sampledRows.append(tail)
                    if sampledRows.count >= sampleCount { break }
                }
            }
        }

        for row in sampledRows {
            let sourceRow = resolvedRowIndex(for: row)
            guard sourceRow >= 0 else { continue }
            let value = parent.query.valueForDisplay(row: sourceRow, column: column)
            let kind = ResultGridValueClassifier.kind(for: columnInfo, value: value)
            let style = fallbackResultGridStyle(for: kind)
            let font = resolvedFont(for: style)
            let resolvedString: String
            if let value {
                resolvedString = value
            } else if kind == .null {
                resolvedString = "NULL"
            } else {
                resolvedString = ""
            }
            let displayString = resolvedString as NSString
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let measured = displayString.size(withAttributes: attributes).width
            maxWidth = max(maxWidth, measured)
        }

        return ceil(maxWidth) + padding + 6
    }

    func fallbackResultGridStyle(for kind: ResultGridValueKind) -> SQLEditorTokenPalette.ResultGridStyle {
        let tone: SQLEditorPalette.Tone = ThemeManager.shared.effectiveColorScheme == .dark ? .dark : .light
        let defaults = SQLEditorTokenPalette.ResultGridColors.defaults(for: tone)
        return defaults.style(for: kind)
    }

    func applyHeaderStyle(to tableView: NSTableView) {
        for column in tableView.tableColumns {
            column.headerCell = NSTableHeaderCell(textCell: column.title)
            column.headerCell.controlSize = .regular
            column.headerCell.alignment = .left
            column.headerCell.title = column.title
            column.headerCell.isHighlighted = false
        }
        tableView.headerView?.needsDisplay = true
    }

    func updateHeaderIndicators() {
        guard let tableView else { return }
        for tableColumn in tableView.tableColumns {
            tableView.setIndicatorImage(nil, in: tableColumn)
        }

        if let sort = parent.activeSort,
           let columnIndex = parent.query.displayedColumns.firstIndex(where: { $0.name == sort.column }),
           columnIndex < tableView.tableColumns.count {
            let tableColumn = tableView.tableColumns[columnIndex]
            let imageName = sort.ascending ? NSImage.touchBarGoUpTemplateName : NSImage.touchBarGoDownTemplateName
            let indicator = NSImage(named: imageName)
            tableView.setIndicatorImage(indicator, in: tableColumn)
        }
    }

    func adjustTableSize(rowCount _: Int? = nil) {
        guard let tableView, let scrollView else { return }
        cachedViewportSize = scrollView.contentView.bounds.size

        let contentWidth = tableView.tableColumns.reduce(CGFloat(0)) { $0 + $1.width }
        let targetWidth = max(contentWidth, scrollView.contentSize.width)
        let currentSize = tableView.frame.size
        if abs(currentSize.width - targetWidth) > 0.5 {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            tableView.setFrameSize(NSSize(width: targetWidth, height: currentSize.height))
            CATransaction.commit()
        }
    }

    func registerScrollObservation(for scrollView: NSScrollView) {
        let contentView = scrollView.contentView
        if observedContentView === contentView { return }
        if let observedContentView {
            NotificationCenter.default.removeObserver(
                self,
                name: NSView.boundsDidChangeNotification,
                object: observedContentView
            )
        }
        contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleContentViewBoundsChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: contentView
        )
        observedContentView = contentView
        requestPaginationEvaluation()
    }

    @objc func handleContentViewBoundsChange(_ notification: Notification) {
        requestPaginationEvaluation()
    }

    func requestPaginationEvaluation() {
        guard !parent.isResizing else { return }
        guard !pendingPaginationEvaluation else { return }
        pendingPaginationEvaluation = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingPaginationEvaluation = false
            self.evaluatePaginationForVisibleRows()
        }
    }

    func evaluatePaginationForVisibleRows() {
        guard let tableView else { return }
        let visibleRange = tableView.rows(in: tableView.visibleRect)
        guard visibleRange.length > 0 else { return }
        let lowerBound = max(visibleRange.location, 0)
        let upperBound = min(tableView.numberOfRows, lowerBound + visibleRange.length)
        guard upperBound > lowerBound else { return }

        parent.query.revealMoreRowsIfNeeded(forDisplayedRow: upperBound - 1)

        var sourceIndices: [Int] = []
        sourceIndices.reserveCapacity(upperBound - lowerBound)
        if parent.rowOrder.isEmpty {
            for displayedRow in lowerBound..<upperBound {
                sourceIndices.append(displayedRow)
            }
        } else {
            for displayedRow in lowerBound..<upperBound {
                guard displayedRow < parent.rowOrder.count else { continue }
                sourceIndices.append(parent.rowOrder[displayedRow])
            }
        }

        parent.query.updateVisibleGridWindow(
            displayedRange: lowerBound..<upperBound,
            sourceIndices: sourceIndices
        )
    }

    func requestTableSizeAdjustment(rowCount: Int? = nil) {
        guard !parent.isResizing else { return }
        guard !pendingTableSizeAdjustment else { return }
        pendingTableSizeAdjustment = true
        let capturedRowCount = rowCount
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingTableSizeAdjustment = false
            self.adjustTableSize(rowCount: capturedRowCount)
        }
    }

    func installRowCountObserver(for state: QueryResultsGridState?) {
        if let observer = rowCountObserver {
            NotificationCenter.default.removeObserver(observer)
            rowCountObserver = nil
        }
        guard let state else { return }
        rowCountObserver = NotificationCenter.default.addObserver(
            forName: .queryResultsRowCountDidChange,
            object: state,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let tableView = self.tableView {
                    self.scheduleRowCountUpdate(for: tableView)
                } else {
                    self.pendingRowCountCorrection = true
                }
            }
        }
    }

    func scheduleRowCountUpdate(for tableView: NSTableView) {
        pendingRowCountCorrection = true
        if let existing = rowCountUpdateWorkItem {
            if !existing.isCancelled { return }
            rowCountUpdateWorkItem = nil
        }
        let workItem = DispatchWorkItem { [weak self, weak tableView] in
            guard let self else { return }
            self.rowCountUpdateWorkItem = nil
            self.pendingRowCountCorrection = false
            guard let tableView else { return }
            tableView.noteNumberOfRowsChanged()
        }
        rowCountUpdateWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    func refreshVisibleRowBackgrounds(_ tableView: NSTableView) {
        let visibleRange = tableView.rows(in: tableView.visibleRect)
        guard visibleRange.length > 0 else { return }
        let lower = max(0, visibleRange.location)
        let upper = min(tableView.numberOfRows, lower + visibleRange.length)
        guard upper > lower else { return }

        for row in lower..<upper {
            guard let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) as? ResultTableRowView else { continue }
            rowView.configure(
                row: row,
                colorProvider: { [weak self] index in
                    self?.rowBackgroundColor(for: index) ?? NSColor(ColorTokens.Background.tertiary)
                },
                highlightProvider: { [weak self, weak tableView] view, index in
                    guard let self, let tableView else { return nil }
                    return self.selectionRenderInfo(forRow: index, rowView: view, tableView: tableView)
                }
            )
        }
    }

    func refreshVisibleCellsAppearance(_ tableView: NSTableView) {
        let visibleRange = tableView.rows(in: tableView.visibleRect)
        guard visibleRange.length > 0 else { return }
        let lower = max(0, visibleRange.location)
        let upper = min(tableView.numberOfRows, lower + visibleRange.length)
        guard upper > lower else { return }

        for row in lower..<upper {
            guard let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) else { continue }
            for columnIndex in 0..<tableView.tableColumns.count {
                guard let cellView = rowView.view(atColumn: columnIndex) as? ResultTableDataCellView else { continue }
                configureCellView(cellView, dataIndex: columnIndex, tableView: tableView, row: row)
            }
        }
    }

    func makeDataCellView(identifier: NSUserInterfaceItemIdentifier) -> ResultTableDataCellView {
        let cellView = ResultTableDataCellView()
        cellView.identifier = identifier
        let textField = cellView.contentTextField
        if !(textField.cell is VerticallyCenteredTextFieldCell) {
            textField.cell = VerticallyCenteredTextFieldCell(textCell: "")
        }
        if let cell = textField.cell as? VerticallyCenteredTextFieldCell {
            cell.isBordered = false
            cell.backgroundColor = .clear
            cell.usesSingleLineMode = true
            cell.truncatesLastVisibleLine = true
            cell.alignment = .left
        }
        return cellView
    }

    func resolvedRowIndex(for visibleRow: Int) -> Int {
        let availableCount = parent.rowOrder.isEmpty
            ? parent.query.displayedRowCount
            : parent.rowOrder.count
        guard visibleRow >= 0 else { return -1 }
        guard visibleRow < availableCount else {
            scheduleRowCountCorrection()
            return -1
        }
        if parent.rowOrder.isEmpty {
            return visibleRow
        }
        return parent.rowOrder[visibleRow]
    }

    func scheduleRowCountCorrection() {
        guard !pendingRowCountCorrection else { return }
        pendingRowCountCorrection = true
        if let state = persistedState {
            state.scheduleRowCountRefresh()
            return
        }
        if let tableView = tableView {
            scheduleRowCountUpdate(for: tableView)
        }
    }

    func configureCellView(_ cellView: ResultTableDataCellView, dataIndex: Int, tableView: NSTableView, row: Int) {
        let sourceIndex = resolvedRowIndex(for: row)
        guard sourceIndex >= 0 else {
            let theme = ThemeManager.shared
            let fallbackStyle = fallbackResultGridStyle(for: .text)
            let baseColor = fallbackStyle.nsColor
            cellView.apply(
                text: "",
                font: resolvedFont(for: fallbackStyle),
                baseTextColor: baseColor,
                selectionTextColor: theme.resultsGridCellTextNSColor,
                isSelected: false
            )
            cellView.configureIcon(nil)
            return
        }
        let rowValues = displayedRowValues(for: sourceIndex)
        let rawValue: String?
        if let rowValues, dataIndex >= 0, dataIndex < rowValues.count {
            rawValue = rowValues[dataIndex]
        } else {
            rawValue = parent.query.valueForDisplay(row: sourceIndex, column: dataIndex)
        }
        let columnInfo = dataIndex < parent.query.displayedColumns.count ? parent.query.displayedColumns[dataIndex] : nil

        let kind: ResultGridValueKind
        if rawValue == nil {
            kind = .null
        } else if dataIndex < cachedColumnKinds.count {
            kind = cachedColumnKinds[dataIndex]
        } else {
            kind = ResultGridValueClassifier.kind(for: columnInfo, value: rawValue)
        }

        let theme = ThemeManager.shared
        let style: SQLEditorTokenPalette.ResultGridStyle
        if let cachedStyle = cachedResultGridStyles[kind] {
            style = cachedStyle
        } else {
            let resolvedStyle = fallbackResultGridStyle(for: kind)
            cachedResultGridStyles[kind] = resolvedStyle
            style = resolvedStyle
        }
        let font = resolvedFont(for: style)
        let displayText: String
        if let rawValue {
            displayText = rawValue
        } else if kind == .null {
            displayText = "NULL"
        } else {
            displayText = ""
        }

        let cellSelection = QueryResultsTableView.SelectedCell(row: row, column: dataIndex)
        let isSelectedCell = selectionRegion?.contains(cellSelection) ?? false
        let baseTextColor: NSColor
        if let cached = cachedTextColors[kind] {
            baseTextColor = cached
        } else {
            let color = style.nsColor
            cachedTextColors[kind] = color
            baseTextColor = color
        }
        let selectionTextColor = theme.resultsGridCellTextNSColor

        cellView.apply(
            text: displayText,
            font: font,
            baseTextColor: baseTextColor,
            selectionTextColor: selectionTextColor,
            isSelected: isSelectedCell
        )

        if shouldShowForeignKeyIcon(forColumnInfo: columnInfo, value: rawValue) {
            cellView.configureIcon { [weak self] in
                self?.activateForeignKey(at: cellSelection)
            }
        } else {
            cellView.configureIcon(nil)
        }
    }

    private func displayedRowValues(for sourceIndex: Int) -> [String?]? {
        if let cached = cachedDisplayedRows[sourceIndex] {
            return cached
        }
        guard let rowValues = parent.query.displayedRow(at: sourceIndex) else {
            return nil
        }
        cachedDisplayedRows[sourceIndex] = rowValues
        if cachedDisplayedRows.count > 512 {
            cachedDisplayedRows.removeAll(keepingCapacity: true)
        }
        return rowValues
    }

    private func shouldShowForeignKeyIcon(forColumnInfo column: ColumnInfo?, value: String?) -> Bool {
        guard parent.foreignKeyDisplayMode == .showIcon else { return false }
        guard let column, column.foreignKey != nil else { return false }
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return false }
        return true
    }

    private func activateForeignKey(at cell: QueryResultsTableView.SelectedCell) {
        guard parent.foreignKeyDisplayMode != .disabled else { return }
        if let tableView {
            let region = SelectedRegion(start: cell, end: cell)
            setSelectionRegion(region, tableView: tableView)
        }
        if let selection = makeForeignKeySelection(for: cell) {
            parent.onForeignKeyEvent(.activate(selection))
        }
    }
}
#endif
