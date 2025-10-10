#if os(macOS)
import SwiftUI
import AppKit
import QuartzCore
import Foundation

struct QueryResultsTableView: NSViewRepresentable {
    @ObservedObject var query: QueryEditorState
    var highlightedColumnIndex: Int?
    var activeSort: SortCriteria?
    var rowOrder: [Int]
    var onColumnTap: (Int) -> Void
    var onSort: (Int, HeaderSortAction) -> Void
    var onClearColumnHighlight: () -> Void
    var backgroundColor: NSColor

    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore
    struct SelectedCell: Equatable {
        let row: Int
        let column: Int
    }

    enum HeaderSortAction {
        case ascending
        case descending
        case clear
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, clipboardHistory: clipboardHistory)
    }

    func makeNSView(context: Context) -> ResultTableContainerView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        if #available(macOS 13.0, *) {
            scrollView.automaticallyAdjustsContentInsets = false
        }

        let tableView = ResultTableView()
        tableView.usesAlternatingRowBackgroundColors = ThemeManager.shared.showAlternateRowShading
        tableView.rowHeight = 24
        tableView.headerView = ResultTableHeaderView(coordinator: context.coordinator)
        tableView.gridStyleMask = []
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        tableView.allowsMultipleSelection = true
        tableView.allowsColumnSelection = false
        tableView.autoresizingMask = [.width, .height]
        tableView.backgroundColor = backgroundColor
#if DEBUG
        tableView.layer?.backgroundColor = backgroundColor.cgColor
#endif
        if let headerView = tableView.headerView {
            headerView.frame.size.height = max(headerView.frame.size.height, 28)
            headerView.isHidden = false
        }
        context.coordinator.configure(tableView: tableView, scrollView: scrollView)
        tableView.selectionDelegate = context.coordinator
        scrollView.documentView = tableView

        let leadingWidth = ThemeManager.shared.resultsGridLeadingInset
        let container = ResultTableContainerView(scrollView: scrollView, leadingWidth: leadingWidth)
        container.updateBackgroundColor(backgroundColor)
        return container
    }

    func updateNSView(_ container: ResultTableContainerView, context: Context) {
        guard let tableView = container.tableView else { return }
        tableView.backgroundColor = backgroundColor
        tableView.usesAlternatingRowBackgroundColors = ThemeManager.shared.showAlternateRowShading
        container.updateLeadingWidth(ThemeManager.shared.resultsGridLeadingInset)
        container.updateBackgroundColor(backgroundColor)
        context.coordinator.update(parent: self, tableView: tableView)
    }

    final class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource, NSMenuDelegate {
        private var parent: QueryResultsTableView
        private let clipboardHistory: ClipboardHistoryStore
        private weak var tableView: NSTableView?
        private weak var scrollView: NSScrollView?
        private let headerMenu = NSMenu()
        private let cellMenu = NSMenu()
        private var menuColumnIndex: Int?
        private var cachedColumnIDs: [String] = []
        private var cachedRowOrder: [Int] = []
        private var cachedSort: SortCriteria?
        private var lastRowCount: Int = 0
        private var selectionRegion: SelectedRegion?
        private var selectionAnchor: QueryResultsTableView.SelectedCell?
        private var isDraggingCellSelection = false
        private var selectionFocus: QueryResultsTableView.SelectedCell?
        private var columnSelectionAnchor: Int?
        private weak var activeSelectableField: NSTextField?
        private var cachedPaletteSignature: String?

        var currentTableView: NSTableView? { tableView }

#if DEBUG
        private var debugLogEmissionCount = 0
        private func debugLog(_ message: String) {
            guard debugLogEmissionCount < 200 else { return }
            debugLogEmissionCount += 1
            print("[GridDebug] \(message)")
        }
#else
        private func debugLog(_ message: String) {}
#endif

        init(_ parent: QueryResultsTableView, clipboardHistory: ClipboardHistoryStore) {
            self.parent = parent
            self.clipboardHistory = clipboardHistory
            super.init()
            headerMenu.delegate = self
            cellMenu.delegate = self
        }

        private struct SelectedRegion: Equatable {
            var start: QueryResultsTableView.SelectedCell
            var end: QueryResultsTableView.SelectedCell

            var normalizedRowRange: ClosedRange<Int> {
                let lower = min(start.row, end.row)
                let upper = max(start.row, end.row)
                return lower...upper
            }

            var normalizedColumnRange: ClosedRange<Int> {
                let lower = min(start.column, end.column)
                let upper = max(start.column, end.column)
                return lower...upper
            }

            func contains(_ cell: QueryResultsTableView.SelectedCell) -> Bool {
                normalizedRowRange.contains(cell.row) && normalizedColumnRange.contains(cell.column)
            }

            func containsRow(_ row: Int) -> Bool {
                normalizedRowRange.contains(row)
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func configure(tableView: NSTableView, scrollView: NSScrollView) {
            self.tableView = tableView
            self.scrollView = scrollView
            tableView.delegate = self
            tableView.dataSource = self
            tableView.menu = cellMenu
            if let header = tableView.headerView as? ResultTableHeaderView {
                header.coordinator = self
                header.menu = headerMenu
                header.frame.size.height = max(header.frame.size.height, 28)
                header.isHidden = false
            } else {
                tableView.headerView?.menu = headerMenu
                tableView.headerView?.frame.size.height = max(tableView.headerView?.frame.size.height ?? 0, 28)
                tableView.headerView?.isHidden = false
            }
            tableView.selectionHighlightStyle = .regular
            tableView.usesAlternatingRowBackgroundColors = false
            _ = reloadColumns()
            applyHeaderStyle(to: tableView)
            refreshVisibleRowBackgrounds(tableView)
            cachedPaletteSignature = paletteSignature()

            adjustTableSize()
        }

        func update(parent: QueryResultsTableView, tableView: NSTableView) {
            self.parent = parent
            if self.tableView == nil {
                self.tableView = tableView
            }
            if scrollView == nil {
                scrollView = tableView.enclosingScrollView
            }
            if let header = tableView.headerView as? ResultTableHeaderView {
                header.coordinator = self
                header.menu = headerMenu
                header.frame.size.height = max(header.frame.size.height, 28)
                header.isHidden = false
            } else {
                tableView.headerView?.menu = headerMenu
                tableView.headerView?.frame.size.height = max(tableView.headerView?.frame.size.height ?? 0, 28)
                tableView.headerView?.isHidden = false
            }
            let currentRowOrder = parent.rowOrder
            let currentRowCount = currentRowOrder.isEmpty ? parent.query.displayedRowCount : currentRowOrder.count
            let columnsChanged = reloadColumns()
            let sortChanged = parent.activeSort != cachedSort
            let rowOrderChanged = currentRowOrder != cachedRowOrder
            let currentPaletteSignature = paletteSignature()
            let paletteChanged = currentPaletteSignature != cachedPaletteSignature
            cachedPaletteSignature = currentPaletteSignature

            var performedFullReload = false

            if columnsChanged || sortChanged || rowOrderChanged || currentRowCount < lastRowCount {
                tableView.reloadData()
                performedFullReload = true
            } else if currentRowCount > lastRowCount {
                let range = lastRowCount..<currentRowCount
                if !range.isEmpty {
                    if tableView.tableColumns.isEmpty {
                        tableView.reloadData()
                        performedFullReload = true
                    } else {
                        tableView.noteNumberOfRowsChanged()
                        let rowIndexes = IndexSet(integersIn: range)
                        let columnIndexes = IndexSet(integersIn: 0..<tableView.tableColumns.count)
                        tableView.reloadData(forRowIndexes: rowIndexes, columnIndexes: columnIndexes)
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

            if performedFullReload {
                tableView.layoutSubtreeIfNeeded()
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
            adjustTableSize(rowCount: currentRowCount)

            if paletteChanged {
                deactivateActiveSelectableField(in: tableView)
                applyHeaderStyle(to: tableView)
                if !performedFullReload {
                    tableView.reloadData()
                    performedFullReload = true
                }
                refreshVisibleRowBackgrounds(tableView)
            }
        }

        private func reloadColumns() -> Bool {
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
                    let minWidth = width(for: column)
                    if abs(tableColumn.minWidth - minWidth) > 1 {
                        tableColumn.minWidth = minWidth
                        if tableColumn.width < minWidth {
                            tableColumn.width = minWidth
                        }
                    }
                }
            }

            tableView.headerView?.needsDisplay = true
            if headerNeedsRefresh {
                applyHeaderStyle(to: tableView)
            }
            cachedColumnIDs = columnIDs
            return columnsChanged
        }

        private func paletteSignature() -> String {
            let theme = ThemeManager.shared
            return [
                String(theme.useAppThemeForResultsGrid),
                String(theme.resultsAlternateRowShading),
                colorSignature(theme.resultsGridCellBackgroundNSColor),
                colorSignature(theme.resultsGridAlternateRowNSColor),
                colorSignature(theme.resultsGridCellTextNSColor),
                colorSignature(theme.resultsGridHeaderBackgroundNSColor),
                colorSignature(theme.resultsGridHeaderTextNSColor)
            ].joined(separator: "|")
        }

        private func colorSignature(_ color: NSColor) -> String {
            guard let converted = color.usingColorSpace(.extendedSRGB) else { return color.description }
            func fmt(_ value: CGFloat) -> String { String(format: "%.4f", value) }
            return [converted.redComponent, converted.greenComponent, converted.blueComponent, converted.alphaComponent].map(fmt).joined(separator: ",")
        }

        private func applyHeaderStyle(to tableView: NSTableView) {
            let theme = ThemeManager.shared
            if let headerView = tableView.headerView {
                headerView.wantsLayer = true
                headerView.layer?.backgroundColor = theme.resultsGridHeaderBackgroundNSColor.cgColor
                headerView.layer?.borderColor = theme.resultsGridHeaderSeparatorNSColor.cgColor
                let scale = headerView.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
                headerView.layer?.borderWidth = 1 / max(scale, 1)
                headerView.needsDisplay = true
            }

            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: theme.resultsGridHeaderTextNSColor,
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold)
            ]

            for column in tableView.tableColumns {
                column.headerCell.attributedStringValue = NSAttributedString(string: column.title, attributes: attributes)
            }
        }

        private func updateHeaderIndicators() {
            guard let tableView else { return }
            for tableColumn in tableView.tableColumns {
                tableView.setIndicatorImage(nil, in: tableColumn)
            }

            if let sort = parent.activeSort,
               let columnIndex = parent.query.displayedColumns.firstIndex(where: { $0.name == sort.column }) {
                let tableColumn = tableView.tableColumns[columnIndex]
                let imageName = sort.ascending ? NSImage.touchBarGoUpTemplateName : NSImage.touchBarGoDownTemplateName
                let indicator = NSImage(named: imageName)
                tableView.setIndicatorImage(indicator, in: tableColumn)
            }
            // Column highlighting is managed explicitly when the user selects a column.
        }

        private func width(for column: ColumnInfo) -> CGFloat {
            let type = column.dataType.lowercased()
            if type.contains("bool") { return 80 }
            if type.contains("int") || type.contains("numeric") || type.contains("decimal") || type.contains("float") || type.contains("double") || type.contains("money") {
                return 120
            }
            if type.contains("date") || type.contains("time") { return 160 }
            return 200
        }

        private func addDataColumns(to tableView: NSTableView) {
            for column in parent.query.displayedColumns {
                let identifier = NSUserInterfaceItemIdentifier("data-\(column.id)")
                let tableColumn = NSTableColumn(identifier: identifier)
                tableColumn.title = column.name
                tableColumn.minWidth = width(for: column)
                tableColumn.width = tableColumn.minWidth
                tableColumn.isEditable = false
                tableColumn.resizingMask = [.userResizingMask]
                tableColumn.headerCell.alignment = .left
                tableColumn.headerCell.controlSize = .small
                tableColumn.headerCell.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
                tableView.addTableColumn(tableColumn)
            }
        }

        // MARK: Column Selection

        func beginColumnSelection(at column: Int, modifiers: NSEvent.ModifierFlags) {
            guard let tableView else { return }
            let columnCount = parent.query.displayedColumns.count
            guard columnCount > 0 else { return }

            let target = max(0, min(column, columnCount - 1))
            let anchor: Int
            if modifiers.contains(.shift), let stored = columnSelectionAnchor ?? selectionRegion?.start.column {
                anchor = max(0, min(stored, columnCount - 1))
            } else {
                anchor = target
            }
            columnSelectionAnchor = anchor
            applyColumnSelection(from: anchor, to: target)
        }

        func continueColumnSelection(to column: Int) {
            guard let tableView else { return }
            guard let anchor = columnSelectionAnchor else { return }
            let columnCount = parent.query.displayedColumns.count
            guard columnCount > 0 else { return }
            let clamped = max(0, min(column, columnCount - 1))
            applyColumnSelection(from: anchor, to: clamped)
            tableView.scrollColumnToVisible(clamped)
        }

        func endColumnSelection() {
            if selectionRegion == nil {
                columnSelectionAnchor = nil
            }
        }

        private func applyColumnSelection(from start: Int, to end: Int) {
            guard let tableView else { return }
            let columnCount = parent.query.displayedColumns.count
            guard columnCount > 0 else { return }

            let clampedStart = max(0, min(start, columnCount - 1))
            let clampedEnd = max(0, min(end, columnCount - 1))
            let lower = min(clampedStart, clampedEnd)
            let upper = max(clampedStart, clampedEnd)

            let maxRow = tableView.numberOfRows - 1
            if maxRow < 0 {
                tableView.scrollColumnToVisible(lower)
                tableView.scrollColumnToVisible(upper)
                return
            }

            let top = QueryResultsTableView.SelectedCell(row: 0, column: lower)
            let bottom = QueryResultsTableView.SelectedCell(row: maxRow, column: upper)
            setSelectionRegion(SelectedRegion(start: top, end: bottom), tableView: tableView)
            selectionAnchor = top
            selectionFocus = bottom
            tableView.scrollColumnToVisible(lower)
            tableView.scrollColumnToVisible(upper)
        }

        private func adjustTableSize(rowCount: Int? = nil) {
            guard let tableView, let scrollView else { return }
            let contentWidth = tableView.tableColumns.reduce(CGFloat(0)) { $0 + $1.width }
            let targetWidth = max(contentWidth, scrollView.contentSize.width)
            let effectiveRowCount = rowCount ?? (parent.rowOrder.isEmpty ? parent.query.displayedRowCount : parent.rowOrder.count)
            let headerHeight = tableView.headerView?.frame.height ?? 0
            let contentHeight = max(CGFloat(effectiveRowCount) * tableView.rowHeight + headerHeight, scrollView.contentSize.height)
            let newSize = NSSize(width: targetWidth, height: contentHeight)
            if tableView.frame.size != newSize {
                tableView.setFrameSize(newSize)
            }
#if DEBUG
            let scrollBounds = scrollView.bounds
            let contentViewFrame = scrollView.contentView.frame
            let visibleRect = tableView.visibleRect
            debugLog("adjustTableSize -> tableFrame=\(tableView.frame) scrollFrame=\(scrollView.frame) scrollBounds=\(scrollBounds) contentViewFrame=\(contentViewFrame) contentSize=\(scrollView.contentSize) tableVisibleRect=\(visibleRect)")
#endif
        }

        // MARK: NSTableViewDataSource

        func numberOfRows(in tableView: NSTableView) -> Int {
            parent.rowOrder.isEmpty ? parent.query.displayedRowCount : parent.rowOrder.count
        }

        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            let rowView = ResultTableRowView()
            rowView.configure(
                row: row,
                colorProvider: { [weak self] index in
                    self?.rowBackgroundColor(for: index) ?? ThemeManager.shared.resultsGridCellBackgroundNSColor
                },
                highlightProvider: { [weak self, weak tableView] view, index in
                    guard let self, let tableView else { return nil }
                    return self.selectionRenderInfo(forRow: index, rowView: view, tableView: tableView)
                }
            )
            return rowView
        }

        private func rowBackgroundColor(for row: Int) -> NSColor {
            let theme = ThemeManager.shared
            if theme.resultsAlternateRowShading && row.isMultiple(of: 2) {
                return theme.resultsGridAlternateRowNSColor
            }
            return theme.resultsGridCellBackgroundNSColor
        }

        private func refreshVisibleRowBackgrounds(_ tableView: NSTableView) {
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
                        self?.rowBackgroundColor(for: index) ?? ThemeManager.shared.resultsGridCellBackgroundNSColor
                    },
                    highlightProvider: { [weak self, weak tableView] view, index in
                        guard let self, let tableView else { return nil }
                        return self.selectionRenderInfo(forRow: index, rowView: view, tableView: tableView)
                    }
                )
            }
        }

        private func selectionRenderInfo(forRow row: Int, rowView: NSTableRowView, tableView: NSTableView) -> ResultTableRowView.SelectionRenderInfo? {
            guard let region = selectionRegion, region.containsRow(row) else { return nil }
            let maxColumn = tableView.tableColumns.count - 1
            guard maxColumn >= 0 else { return nil }

            let lowerColumn = max(0, min(region.normalizedColumnRange.lowerBound, maxColumn))
            let upperColumn = max(0, min(region.normalizedColumnRange.upperBound, maxColumn))
            guard upperColumn >= lowerColumn else { return nil }

            let leftEdge = tableView.rect(ofColumn: lowerColumn).minX
            let rightEdge = tableView.rect(ofColumn: upperColumn).maxX

            let isTop = row == region.normalizedRowRange.lowerBound
            let isBottom = row == region.normalizedRowRange.upperBound

            var rect = NSRect(x: leftEdge, y: tableView.rect(ofRow: row).minY, width: rightEdge - leftEdge, height: tableView.rowHeight)
            rect = rect.insetBy(dx: 1.5, dy: 0)

            var converted = rowView.convert(rect, from: tableView)

            let topInset: CGFloat = isTop ? 2 : 0
            let bottomInset: CGFloat = isBottom ? 2 : 0

            if rowView.isFlipped {
                converted.origin.y += topInset
                converted.size.height -= (topInset + bottomInset)
            } else {
                converted.origin.y += bottomInset
                converted.size.height -= (topInset + bottomInset)
            }

            converted.size.height = max(converted.size.height, 0)

            let topRadiusRaw: CGFloat = isTop ? 6 : 0
            let bottomRadiusRaw: CGFloat = isBottom ? 6 : 0
            let (topRadius, bottomRadius): (CGFloat, CGFloat)
            if rowView.isFlipped {
                topRadius = bottomRadiusRaw
                bottomRadius = topRadiusRaw
            } else {
                topRadius = topRadiusRaw
                bottomRadius = bottomRadiusRaw
            }

            return ResultTableRowView.SelectionRenderInfo(rect: converted, topCornerRadius: topRadius, bottomCornerRadius: bottomRadius)
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let tableColumn else { return nil }
            guard let dataIndex = dataColumnIndex(for: tableColumn) else { return nil }
            let identifier = NSUserInterfaceItemIdentifier("data-cell-\(dataIndex)")
            let textField = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField ?? makeLabel(identifier: identifier)
            if !(textField.cell is VerticallyCenteredTextFieldCell) {
                textField.cell = VerticallyCenteredTextFieldCell(textCell: "")
                if let cell = textField.cell as? VerticallyCenteredTextFieldCell {
                    cell.isBordered = false
                    cell.backgroundColor = .clear
                    cell.usesSingleLineMode = true
                    cell.truncatesLastVisibleLine = true
                }
            }

            let sourceIndex = resolvedRowIndex(for: row)
            let value = parent.query.valueForDisplay(row: sourceIndex, column: dataIndex)
            if let value {
                textField.stringValue = value
                textField.textColor = ThemeManager.shared.resultsGridCellTextNSColor
                textField.font = NSFont.systemFont(ofSize: 12)
            } else {
                textField.stringValue = "NULL"
                textField.textColor = ThemeManager.shared.resultsGridCellTextNSColor.withAlphaComponent(0.65)
                let baseFont = NSFont.systemFont(ofSize: 12)
                textField.font = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
            }

            textField.wantsLayer = true
            if let layer = textField.layer {
                layer.masksToBounds = true
                layer.cornerRadius = 6
                if #available(macOS 10.15, *) {
                    layer.cornerCurve = .continuous
                }
            }

            let cellSelection = QueryResultsTableView.SelectedCell(row: row, column: dataIndex)
            let isSelectedCell = selectionRegion?.contains(cellSelection) ?? false

            textField.drawsBackground = false
            textField.backgroundColor = .clear
            textField.layer?.backgroundColor = NSColor.clear.cgColor
            textField.layer?.borderWidth = 0
            textField.layer?.borderColor = nil

            if isSelectedCell {
                textField.textColor = ThemeManager.shared.resultsGridCellTextNSColor
            }

            textField.alignment = .left
            textField.autoresizingMask = [.width, .height]
            textField.frame = NSRect(x: 0, y: 0, width: tableColumn.width, height: tableView.rowHeight)
            return textField
        }

        private func makeLabel(identifier: NSUserInterfaceItemIdentifier) -> NSTextField {
            let cell = VerticallyCenteredTextFieldCell(textCell: "")
            cell.isBordered = false
            cell.backgroundColor = .clear
            cell.usesSingleLineMode = true
            cell.truncatesLastVisibleLine = true

            let label = NSTextField(frame: .zero)
            label.identifier = identifier
            label.cell = cell
            label.isEditable = false
            label.isSelectable = false
            label.isBordered = false
            label.drawsBackground = false
            label.focusRingType = .none
            label.lineBreakMode = .byTruncatingTail
            label.usesSingleLineMode = true
            label.maximumNumberOfLines = 1
            label.translatesAutoresizingMaskIntoConstraints = true
            label.autoresizingMask = [.width, .height]
            return label
        }

        private func dataColumnIndex(for tableColumn: NSTableColumn) -> Int? {
            guard let tableView else { return nil }
            guard let index = tableView.tableColumns.firstIndex(of: tableColumn) else { return nil }
            return index
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
                    isDraggingCellSelection = false
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
                isDraggingCellSelection = false
                setSelectionRegion(nil, tableView: tableView)
            }
        }

        // MARK: NSMenuDelegate

        func menuNeedsUpdate(_ menu: NSMenu) {
            guard let tableView else { return }
            menu.removeAllItems()

            if menu === headerMenu {
                let clickedColumn = tableView.clickedColumn
                guard clickedColumn >= 0 else { return }
                menuColumnIndex = clickedColumn

                guard let dataIndex = menuColumnIndex,
                      dataIndex < parent.query.displayedColumns.count else { return }

                selectColumn(at: dataIndex, in: tableView)

                let ascendingItem = NSMenuItem(title: "Sort Ascending", action: #selector(sortAscending), keyEquivalent: "")
                ascendingItem.target = self
                if let sort = parent.activeSort,
                   sort.column == parent.query.displayedColumns[dataIndex].name,
                   sort.ascending {
                    ascendingItem.state = .on
                }
                menu.addItem(ascendingItem)

                let descendingItem = NSMenuItem(title: "Sort Descending", action: #selector(sortDescending), keyEquivalent: "")
                descendingItem.target = self
                if let sort = parent.activeSort,
                   sort.column == parent.query.displayedColumns[dataIndex].name,
                   !sort.ascending {
                    descendingItem.state = .on
                }
                menu.addItem(descendingItem)

                menu.addItem(.separator())

                let copyColumnItem = NSMenuItem(title: "Copy Column", action: #selector(copyColumnPlain), keyEquivalent: "c")
                copyColumnItem.target = self
                copyColumnItem.isEnabled = hasCopyableSelection()
                copyColumnItem.keyEquivalentModifierMask = [.command]
                if #available(macOS 11.0, *) {
                    copyColumnItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
                }
                menu.addItem(copyColumnItem)

                let copyColumnWithHeadersItem = NSMenuItem(title: "Copy Column with Headers", action: #selector(copyColumnWithHeaders), keyEquivalent: "c")
                copyColumnWithHeadersItem.target = self
                copyColumnWithHeadersItem.isEnabled = hasCopyableSelection()
                copyColumnWithHeadersItem.keyEquivalentModifierMask = [.command, .shift]
                if #available(macOS 11.0, *) {
                    copyColumnWithHeadersItem.image = NSImage(systemSymbolName: "tablecells", accessibilityDescription: nil)
                }
                menu.addItem(copyColumnWithHeadersItem)
            } else if menu === cellMenu {
                updateCellMenu(menu, tableView: tableView)
            }
        }

        @objc private func sortAscending() {
            guard let dataIndex = menuColumnIndex else { return }
            parent.onSort(dataIndex, .ascending)
        }

        @objc private func sortDescending() {
            guard let dataIndex = menuColumnIndex else { return }
            parent.onSort(dataIndex, .descending)
        }

        @objc private func copyColumnPlain() {
            copySelection(includeHeaders: false)
        }

        @objc private func copyColumnWithHeaders() {
            copySelection(includeHeaders: true)
        }

        private func updateCellMenu(_ menu: NSMenu, tableView: NSTableView) {
            ensureSelectionForContextMenu(tableView: tableView)

            let hasSelection = hasCopyableSelection()

            let copyItem = NSMenuItem(title: "Copy", action: #selector(copySelectionPlain), keyEquivalent: "c")
            copyItem.target = self
            if #available(macOS 11.0, *) {
                copyItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
            }
            copyItem.isEnabled = hasSelection
            copyItem.keyEquivalentModifierMask = [.command]
            menu.addItem(copyItem)

            let copyHeadersItem = NSMenuItem(title: "Copy with Headers", action: #selector(copySelectionWithHeaders), keyEquivalent: "c")
            copyHeadersItem.target = self
            if #available(macOS 11.0, *) {
                copyHeadersItem.image = NSImage(systemSymbolName: "tablecells", accessibilityDescription: nil)
            }
            copyHeadersItem.isEnabled = hasSelection
            copyHeadersItem.keyEquivalentModifierMask = [.command, .shift]
            menu.addItem(copyHeadersItem)
        }

        private func selectColumn(at index: Int, in tableView: NSTableView) {
            let maxRow = tableView.numberOfRows - 1
            guard index >= 0, index < tableView.tableColumns.count, maxRow >= 0 else {
                setSelectionRegion(nil, tableView: tableView)
                return
            }

            let top = QueryResultsTableView.SelectedCell(row: 0, column: index)
            let bottom = QueryResultsTableView.SelectedCell(row: maxRow, column: index)
            setSelectionRegion(SelectedRegion(start: top, end: bottom), tableView: tableView)
            selectionAnchor = top
            selectionFocus = bottom
            isDraggingCellSelection = false
            tableView.highlightedTableColumn = tableView.tableColumns[index]
        }


        private func ensureSelectionForContextMenu(tableView: NSTableView) {
            let clickedRow = tableView.clickedRow
            let clickedColumn = tableView.clickedColumn

            guard let cell = resolvedCell(forRow: clickedRow, column: clickedColumn, tableView: tableView) else {
                return
            }

            if let region = selectionRegion, region.contains(cell) {
                return
            }

            setSelectionRegion(SelectedRegion(start: cell, end: cell), tableView: tableView)
            parent.onClearColumnHighlight()
        }

        private func hasCopyableSelection() -> Bool {
            guard let tableView else { return false }

            if let selectionRegion {
                let columnCount = parent.query.displayedColumns.count
                let rowCount = tableView.numberOfRows
                guard columnCount > 0, rowCount > 0 else { return false }

                let lowerRow = max(selectionRegion.normalizedRowRange.lowerBound, 0)
                let upperRow = min(selectionRegion.normalizedRowRange.upperBound, rowCount - 1)
                guard upperRow >= lowerRow else { return false }

                let lowerColumn = max(selectionRegion.normalizedColumnRange.lowerBound, 0)
                let upperColumn = min(selectionRegion.normalizedColumnRange.upperBound, columnCount - 1)
                guard upperColumn >= lowerColumn else { return false }

                return true
            }

            return !tableView.selectedRowIndexes.isEmpty
        }

        @objc private func copySelectionPlain() {
            copySelection(includeHeaders: false)
        }

        @objc private func copySelectionWithHeaders() {
            copySelection(includeHeaders: true)
        }

        private func copySelection(includeHeaders: Bool) {
            guard let tableView else { return }
            let columns = parent.query.displayedColumns
            guard !columns.isEmpty else { return }

            let totalRows = parent.query.totalAvailableRowCount
            guard totalRows > 0 else { return }

            let columnIndices: [Int]
            let visibleRows: [Int]

            if let selectionRegion {
                let maxColumnIndex = columns.count - 1
                let lowerColumn = max(selectionRegion.normalizedColumnRange.lowerBound, 0)
                let upperColumn = min(selectionRegion.normalizedColumnRange.upperBound, maxColumnIndex)
                guard upperColumn >= lowerColumn else { return }
                columnIndices = Array(lowerColumn...upperColumn)

                let maxVisibleRow = tableView.numberOfRows - 1
                guard maxVisibleRow >= 0 else { return }
                let lowerRow = max(selectionRegion.normalizedRowRange.lowerBound, 0)
                let upperRow = min(selectionRegion.normalizedRowRange.upperBound, maxVisibleRow)
                guard upperRow >= lowerRow else { return }
                visibleRows = Array(lowerRow...upperRow)
            } else {
                let selectedIndexes = tableView.selectedRowIndexes
                guard !selectedIndexes.isEmpty else { return }
                visibleRows = selectedIndexes.sorted()
                columnIndices = Array(0..<columns.count)
            }

            let sourceRows: [Int] = visibleRows.compactMap { visible in
                guard visible >= 0 else { return nil }
                let source = resolvedRowIndex(for: visible)
                guard source >= 0, source < totalRows else { return nil }
                return source
            }

            guard !sourceRows.isEmpty, !columnIndices.isEmpty else { return }

            var lines: [String] = []
            if includeHeaders {
                let header = columnIndices.map { columns[$0].name }
                lines.append(header.joined(separator: "\t"))
            }

            for row in sourceRows {
                let values = columnIndices.map { parent.query.valueForDisplay(row: row, column: $0) ?? "" }
                lines.append(values.joined(separator: "\t"))
            }

            let export = lines.joined(separator: "\n")
            PlatformClipboard.copy(export)
            clipboardHistory.record(
                .resultGrid(includeHeaders: includeHeaders),
                content: export,
                metadata: parent.query.clipboardMetadata
            )
        }

        func handleMouseDown(_ event: NSEvent, in tableView: NSTableView) {
            guard tableView.numberOfRows > 0 else { return }
            deactivateActiveSelectableField(in: tableView)
            tableView.window?.makeFirstResponder(tableView)
            let point = tableView.convert(event.locationInWindow, from: nil)
            guard let cell = resolvedCell(at: point, in: tableView, allowOutOfBounds: false) else {
                clearColumnSelection(in: tableView)
                isDraggingCellSelection = false
                tableView.deselectAll(nil)
                selectionAnchor = nil
                selectionFocus = nil
                selectionRegion = nil
                return
            }

            let clickCount = event.clickCount
            let extendSelection = event.modifierFlags.contains(.shift)
            let currentRegion = selectionRegion
            let anchorCell: QueryResultsTableView.SelectedCell

            if extendSelection, let existingAnchor = selectionAnchor {
                anchorCell = existingAnchor
            } else if let existingRegion = currentRegion, regionRepresentsEntireColumn(existingRegion, tableView: tableView) {
                anchorCell = cell
                setSelectionRegion(SelectedRegion(start: anchorCell, end: cell), tableView: tableView)
            } else {
                anchorCell = cell
                if currentRegion?.contains(cell) != true {
                    setSelectionRegion(SelectedRegion(start: anchorCell, end: cell), tableView: tableView)
                }
            }

            if clickCount >= 2 {
                focusCellEditor(at: cell, tableView: tableView)
                isDraggingCellSelection = false
                return
            }

            if extendSelection {
                setSelectionRegion(SelectedRegion(start: anchorCell, end: cell), tableView: tableView)
                selectionAnchor = anchorCell
            } else {
                setSelectionRegion(SelectedRegion(start: cell, end: cell), tableView: tableView)
                selectionAnchor = cell
                parent.onClearColumnHighlight()
            }

            selectionFocus = cell
            isDraggingCellSelection = true
        }

        func handleMouseDragged(_ event: NSEvent, in tableView: NSTableView) {
            guard isDraggingCellSelection, let anchor = selectionAnchor else { return }
            let point = tableView.convert(event.locationInWindow, from: nil)
            guard let cell = resolvedCell(at: point, in: tableView, allowOutOfBounds: true) else { return }
            let region = SelectedRegion(start: anchor, end: cell)
            if selectionRegion != region {
                setSelectionRegion(region, tableView: tableView)
            }
        }

        func handleMouseUp(_ event: NSEvent, in tableView: NSTableView) {
            isDraggingCellSelection = false
        }

        func handleKeyDown(_ event: NSEvent, in tableView: NSTableView) -> Bool {
            if let characters = event.charactersIgnoringModifiers?.lowercased(),
               characters == "c",
               event.modifierFlags.contains(.command) {
                copySelection(includeHeaders: event.modifierFlags.contains(.shift))
                return true
            }
            return handleNavigationKey(event, in: tableView)
        }

        private func handleNavigationKey(_ event: NSEvent, in tableView: NSTableView) -> Bool {
            guard let specialKey = event.specialKey else { return false }
            let extend = event.modifierFlags.contains(.shift)

            switch specialKey {
            case .upArrow:
                moveSelection(rowDelta: -1, columnDelta: 0, extend: extend, tableView: tableView)
                return true
            case .downArrow:
                moveSelection(rowDelta: 1, columnDelta: 0, extend: extend, tableView: tableView)
                return true
            case .leftArrow:
                moveSelection(rowDelta: 0, columnDelta: -1, extend: extend, tableView: tableView)
                return true
            case .rightArrow, .tab:
                moveSelection(rowDelta: 0, columnDelta: 1, extend: extend, tableView: tableView)
                return true
            case .pageUp:
                moveSelection(rowDelta: -pageJumpAmount(for: tableView), columnDelta: 0, extend: extend, tableView: tableView)
                return true
            case .pageDown:
                moveSelection(rowDelta: pageJumpAmount(for: tableView), columnDelta: 0, extend: extend, tableView: tableView)
                return true
            case .home:
                moveSelection(rowDelta: -Int.max, columnDelta: 0, extend: extend, tableView: tableView)
                return true
            case .end:
                moveSelection(rowDelta: Int.max, columnDelta: 0, extend: extend, tableView: tableView)
                return true
            default:
                return false
            }
        }

        private func pageJumpAmount(for tableView: NSTableView) -> Int {
            let visibleHeight = tableView.visibleRect.height
            let rowHeight = max(tableView.rowHeight, 1)
            return max(1, Int(visibleHeight / rowHeight) - 1)
        }

        func performMenuCopy(in tableView: NSTableView) -> Bool {
            guard self.tableView === tableView else { return false }
            copySelection(includeHeaders: false)
            return true
        }

        func clearCellSelection(for tableView: NSTableView) {
            setSelectionRegion(nil, tableView: tableView)
            parent.onClearColumnHighlight()
            deactivateActiveSelectableField(in: tableView)
        }

        private func clearColumnSelection(in tableView: NSTableView) {
            setSelectionRegion(nil, tableView: tableView)
            tableView.highlightedTableColumn = nil
            parent.onClearColumnHighlight()
            deactivateActiveSelectableField(in: tableView)
            selectionAnchor = nil
            selectionFocus = nil
        }

        func isRowInCellSelection(_ row: Int) -> Bool {
            selectionRegion?.containsRow(row) ?? false
        }

        var hasActiveCellSelection: Bool { selectionRegion != nil }

        private func ensureSelectionSeed(in tableView: NSTableView) {
            guard tableView.numberOfRows > 0, tableView.tableColumns.count > 0 else { return }
            if selectionRegion == nil {
                let defaultRow = tableView.clickedRow >= 0 ? tableView.clickedRow : (selectionFocus?.row ?? 0)
                let defaultColumn = tableView.clickedColumn >= 0 ? tableView.clickedColumn : (selectionFocus?.column ?? 0)
                let seed = QueryResultsTableView.SelectedCell(
                    row: max(0, min(tableView.numberOfRows - 1, defaultRow)),
                    column: max(0, min(tableView.tableColumns.count - 1, defaultColumn))
                )
                setSelectionRegion(SelectedRegion(start: seed, end: seed), tableView: tableView)
                selectionAnchor = seed
                selectionFocus = seed
            }
        }

        private func moveSelection(rowDelta: Int, columnDelta: Int, extend: Bool, tableView: NSTableView) {
            guard tableView.numberOfRows > 0, tableView.tableColumns.count > 0 else { return }

            deactivateActiveSelectableField(in: tableView)

            ensureSelectionSeed(in: tableView)

            guard var focus = selectionFocus ?? selectionRegion?.end else { return }

            let maxRow = tableView.numberOfRows - 1
            let maxColumn = tableView.tableColumns.count - 1

            // Vertical movement
            let targetRow: Int
            if rowDelta == Int.max {
                targetRow = maxRow
            } else if rowDelta == -Int.max {
                targetRow = 0
            } else {
                targetRow = max(0, min(maxRow, focus.row + rowDelta))
            }

            // Horizontal movement
            let targetColumn: Int
            if columnDelta == 0 {
                targetColumn = focus.column
            } else if columnDelta == Int.max {
                targetColumn = maxColumn
            } else if columnDelta == -Int.max {
                targetColumn = 0
            } else {
                targetColumn = max(0, min(maxColumn, focus.column + columnDelta))
            }

            focus = QueryResultsTableView.SelectedCell(row: targetRow, column: targetColumn)

            let anchor: QueryResultsTableView.SelectedCell
            if extend, let existingAnchor = selectionAnchor ?? selectionRegion?.start {
                anchor = existingAnchor
            } else {
                anchor = focus
            }

            let region = SelectedRegion(start: anchor, end: focus)
            setSelectionRegion(region, tableView: tableView)
            selectionAnchor = anchor
            selectionFocus = focus

            tableView.scrollRowToVisible(focus.row)
            tableView.scrollColumnToVisible(focus.column)
        }

        private func resolvedCell(forRow row: Int, column: Int, tableView: NSTableView) -> QueryResultsTableView.SelectedCell? {
            guard row >= 0, row < tableView.numberOfRows else { return nil }
            guard column >= 0, column < tableView.tableColumns.count else { return nil }
            let visibleRow = row
            let dataColumn = column
            guard dataColumn < parent.query.displayedColumns.count else { return nil }
            return QueryResultsTableView.SelectedCell(row: visibleRow, column: dataColumn)
        }

        private func focusCellEditor(at cell: QueryResultsTableView.SelectedCell, tableView: NSTableView) {
            guard let textField = tableView.view(atColumn: cell.column, row: cell.row, makeIfNecessary: false) as? NSTextField else {
                return
            }
            deactivateActiveSelectableField(in: tableView)
            textField.isSelectable = true
            activeSelectableField = textField
            tableView.window?.makeFirstResponder(textField)
            textField.selectText(nil)
        }

        private func resolvedCell(at point: NSPoint, in tableView: NSTableView, allowOutOfBounds: Bool) -> QueryResultsTableView.SelectedCell? {
            var row = tableView.row(at: point)
            var column = tableView.column(at: point)

            if allowOutOfBounds {
                row = clampRow(row, point: point, tableView: tableView)
                column = clampColumn(column, tableView: tableView)
            }

            return resolvedCell(forRow: row, column: column, tableView: tableView)
        }

        private func clampRow(_ row: Int, point: NSPoint, tableView: NSTableView) -> Int {
            if row >= 0 { return row }
            let maxRow = tableView.numberOfRows - 1
            guard maxRow >= 0 else { return -1 }

            if point.y < 0 {
                return 0
            }

            let lastRowRect = tableView.rect(ofRow: maxRow)
            if point.y > lastRowRect.maxY {
                return maxRow
            }

            let clampedPoint = NSPoint(x: point.x, y: min(max(point.y, 0), lastRowRect.maxY - 1))
            let fallback = tableView.row(at: clampedPoint)
            if fallback >= 0 {
                return fallback
            }

            let approximate = Int(clampedPoint.y / max(tableView.rowHeight, 1))
            return max(0, min(maxRow, approximate))
        }

        private func clampColumn(_ column: Int, tableView: NSTableView) -> Int {
            let maxIndex = tableView.tableColumns.count - 1
            if maxIndex < 0 { return -1 }
            if column < 0 { return 0 }
            if column > maxIndex { return maxIndex }
            return column
        }

        private func regionRepresentsEntireColumn(_ region: SelectedRegion, tableView: NSTableView) -> Bool {
            guard region.start.column == region.end.column else { return false }
            let rowCount = tableView.numberOfRows
            guard rowCount > 0 else { return false }
            return region.normalizedRowRange.lowerBound <= 0 && region.normalizedRowRange.upperBound >= rowCount - 1
        }

        private func deactivateActiveSelectableField(in tableView: NSTableView?) {
            guard let field = activeSelectableField else { return }
            if let tableView, let window = tableView.window, let editor = window.firstResponder as? NSTextView, editor.delegate as? NSTextField === field {
                window.makeFirstResponder(tableView)
            }
            field.isSelectable = false
            activeSelectableField = nil
        }

        private func resolvedRowIndex(for visibleRow: Int) -> Int {
            guard !parent.rowOrder.isEmpty else { return visibleRow }
            if visibleRow < parent.rowOrder.count {
                return parent.rowOrder[visibleRow]
            }
            return visibleRow
        }

        private func setSelectionRegion(_ region: SelectedRegion?, tableView: NSTableView?) {
            let previous = selectionRegion
            selectionRegion = region
            selectionAnchor = region?.start
            selectionFocus = region?.end

            guard let tableView else { return }

            if region != nil {
                tableView.selectionHighlightStyle = .none
                tableView.deselectAll(nil)
            } else {
                tableView.selectionHighlightStyle = .regular
                isDraggingCellSelection = false
                deactivateActiveSelectableField(in: tableView)
            }

            reload(region: previous, tableView: tableView)
            reload(region: region, tableView: tableView)

            tableView.highlightedTableColumn = nil
            if let region,
               regionRepresentsEntireColumn(region, tableView: tableView),
               region.start.column >= 0,
               region.start.column < tableView.tableColumns.count {
                tableView.highlightedTableColumn = tableView.tableColumns[region.start.column]
            } else {
                parent.onClearColumnHighlight()
            }

            refreshVisibleRowBackgrounds(tableView)
        }

        private func reload(region: SelectedRegion?, tableView: NSTableView) {
            guard let region else { return }

            let rowCount = tableView.numberOfRows
            guard rowCount > 0 else { return }
            let maxRowIndex = rowCount - 1
            let lowerRow = max(region.normalizedRowRange.lowerBound, 0)
            let upperRow = min(region.normalizedRowRange.upperBound, maxRowIndex)
            guard lowerRow <= upperRow else { return }
            let rowIndexes = IndexSet(integersIn: lowerRow...upperRow)

            let maxColumns = tableView.tableColumns.count
            guard maxColumns > 0 else { return }

            let lower = max(0, min(region.normalizedColumnRange.lowerBound, maxColumns - 1))
            let upper = max(0, min(region.normalizedColumnRange.upperBound, maxColumns - 1))
            let columnIndexes = IndexSet(integersIn: lower...upper)
            tableView.reloadData(forRowIndexes: rowIndexes, columnIndexes: columnIndexes)
        }

    }
}

final class ResultTableContainerView: NSVisualEffectView {
    let scrollView: NSScrollView
    private let leadingView: ResultTableLeadingBackgroundView
    private var leadingWidth: CGFloat

    init(scrollView: NSScrollView, leadingWidth: CGFloat) {
        self.scrollView = scrollView
        self.leadingWidth = max(0, leadingWidth)
        self.leadingView = ResultTableLeadingBackgroundView(width: self.leadingWidth)
        super.init(frame: .zero)

        material = .contentBackground
        blendingMode = .withinWindow
        state = .followsWindowActiveState
        isEmphasized = false
        wantsLayer = true
        layer?.masksToBounds = false
        scrollView.autoresizingMask = [.width, .height]
        leadingView.autoresizingMask = [.height]
        leadingView.isHidden = self.leadingWidth <= 0

        addSubview(leadingView)
        addSubview(scrollView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var tableView: NSTableView? {
        scrollView.documentView as? NSTableView
    }

    func updateBackgroundColor(_ color: NSColor) {
        leadingView.updateBackgroundColor(ThemeManager.shared.resultsGridHeaderBackgroundNSColor)
        wantsLayer = true
        layer?.backgroundColor = color.cgColor
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.contentView.backgroundColor = .clear
    }

    func updateLeadingWidth(_ width: CGFloat) {
        let normalized = max(0, width)
        guard abs(normalized - leadingWidth) > 0.01 else { return }
        leadingWidth = normalized
        leadingView.updateConfiguredWidth(normalized)
        leadingView.isHidden = normalized <= 0
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    override func layout() {
        super.layout()
        layoutChildren()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        layoutChildren()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutChildren()
    }

    private func layoutChildren() {
        guard scrollView.superview === self else { return }
        let actualWidth = max(0, min(leadingWidth, bounds.width))
        leadingView.isHidden = actualWidth <= 0
        leadingView.frame = NSRect(x: 0, y: 0, width: actualWidth, height: bounds.height)
        let scrollOriginX = actualWidth
        let scrollWidth = max(bounds.width - scrollOriginX, 0)
        scrollView.frame = NSRect(x: scrollOriginX, y: 0, width: scrollWidth, height: bounds.height)
        if scrollView.responds(to: #selector(getter: NSScrollView.contentInsets)) {
            scrollView.contentInsets = NSEdgeInsetsZero
        }
    }
}

private final class ResultTableLeadingBackgroundView: NSVisualEffectView {
    private var configuredWidth: CGFloat
    private let separatorLayer = CALayer()

    init(width: CGFloat) {
        self.configuredWidth = width
        super.init(frame: .zero)
        material = .sidebar
        blendingMode = .withinWindow
        state = .followsWindowActiveState
        isEmphasized = false
        wantsLayer = true
        layer?.masksToBounds = false
        layer?.addSublayer(separatorLayer)
        separatorLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        separatorLayer.isHidden = width <= 0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateBackgroundColor(_ color: NSColor) {
        wantsLayer = true
        material = .sidebar
        blendingMode = .withinWindow
        state = .followsWindowActiveState
        layer?.backgroundColor = color.cgColor
        separatorLayer.backgroundColor = ThemeManager.shared.resultsGridHeaderSeparatorNSColor.cgColor
        separatorLayer.isHidden = configuredWidth <= 0
        needsLayout = true
    }

    func updateConfiguredWidth(_ width: CGFloat) {
        configuredWidth = width
        separatorLayer.isHidden = width <= 0
        needsLayout = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func layout() {
        super.layout()
        separatorLayer.frame = CGRect(
            x: max(0, bounds.width - 1),
            y: 0,
            width: configuredWidth > 0 ? 1 : 0,
            height: bounds.height
        )
    }
}

private final class ResultTableRowView: NSTableRowView {
    private var rowIndex: Int = 0
    private var colorProvider: ((Int) -> NSColor)?

    struct SelectionRenderInfo {
        let rect: NSRect
        let topCornerRadius: CGFloat
        let bottomCornerRadius: CGFloat
    }

    private var highlightProvider: ((ResultTableRowView, Int) -> SelectionRenderInfo?)?

    func configure(row: Int,
                   colorProvider: @escaping (Int) -> NSColor,
                   highlightProvider: @escaping (ResultTableRowView, Int) -> SelectionRenderInfo?) {
        self.rowIndex = row
        self.colorProvider = colorProvider
        self.highlightProvider = highlightProvider
        needsDisplay = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        colorProvider = nil
        highlightProvider = nil
    }

    override func drawBackground(in dirtyRect: NSRect) {
        let color = colorProvider?(rowIndex) ?? NSColor.clear
        color.setFill()
        dirtyRect.fill()

        if let info = highlightProvider?(self, rowIndex) {
            let accent = ThemeManager.shared.accentNSColor
            let fill = accent.withAlphaComponent(0.18)
            let stroke = accent.withAlphaComponent(0.65)
            let path = makeRoundedPath(in: info.rect, topRadius: info.topCornerRadius, bottomRadius: info.bottomCornerRadius)
            fill.setFill()
            path.fill()
            stroke.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    override func drawSelection(in dirtyRect: NSRect) {}

    override var isEmphasized: Bool {
        get { false }
        set { }
    }

    private func makeRoundedPath(in rect: NSRect, topRadius: CGFloat, bottomRadius: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        let topR = min(topRadius, rect.width / 2, rect.height / 2)
        let bottomR = min(bottomRadius, rect.width / 2, rect.height / 2)

        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY

        path.move(to: NSPoint(x: minX, y: minY + bottomR))

        if bottomR > 0 {
            path.appendArc(withCenter: NSPoint(x: minX + bottomR, y: minY + bottomR), radius: bottomR, startAngle: 180, endAngle: 270)
        } else {
            path.line(to: NSPoint(x: minX, y: minY))
        }

        path.line(to: NSPoint(x: maxX - bottomR, y: minY))

        if bottomR > 0 {
            path.appendArc(withCenter: NSPoint(x: maxX - bottomR, y: minY + bottomR), radius: bottomR, startAngle: 270, endAngle: 360)
        } else {
            path.line(to: NSPoint(x: maxX, y: minY))
        }

        path.line(to: NSPoint(x: maxX, y: maxY - topR))

        if topR > 0 {
            path.appendArc(withCenter: NSPoint(x: maxX - topR, y: maxY - topR), radius: topR, startAngle: 0, endAngle: 90)
        } else {
            path.line(to: NSPoint(x: maxX, y: maxY))
        }

        path.line(to: NSPoint(x: minX + topR, y: maxY))

        if topR > 0 {
            path.appendArc(withCenter: NSPoint(x: minX + topR, y: maxY - topR), radius: topR, startAngle: 90, endAngle: 180)
        } else {
            path.line(to: NSPoint(x: minX, y: maxY))
        }

        path.close()
        return path
    }
}

private final class ResultTableView: NSTableView {
    weak var selectionDelegate: QueryResultsTableView.Coordinator?

    override var acceptsFirstResponder: Bool { true }

    override func highlightSelection(inClipRect clipRect: NSRect) {
        if selectionDelegate?.hasActiveCellSelection == true {
            return
        }
        super.highlightSelection(inClipRect: clipRect)
    }

    override func mouseDown(with event: NSEvent) {
        selectionDelegate?.handleMouseDown(event, in: self)
        if selectionDelegate?.hasActiveCellSelection == true {
            return
        }
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        selectionDelegate?.handleMouseDragged(event, in: self)
        if selectionDelegate?.hasActiveCellSelection == true {
            return
        }
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        selectionDelegate?.handleMouseUp(event, in: self)
        super.mouseUp(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if selectionDelegate?.handleKeyDown(event, in: self) == true {
            return
        }
        super.keyDown(with: event)
    }

    @objc func copy(_ sender: Any?) {
        if selectionDelegate?.performMenuCopy(in: self) == true {
            return
        }
        NSApp.sendAction(#selector(NSTextView.copy(_:)), to: nil, from: self)
    }
}

private final class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    private let horizontalPadding: CGFloat = 8

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        var newRect = super.drawingRect(forBounds: rect)
        let textSize = cellSize(forBounds: rect)
        if newRect.height > textSize.height {
            let heightDelta = newRect.height - textSize.height
            newRect.origin.y += heightDelta / 2
            newRect.size.height = textSize.height
        }
        newRect.origin.x += horizontalPadding
        newRect.size.width = max(0, newRect.size.width - horizontalPadding * 2)
        return newRect
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        let adjusted = drawingRect(forBounds: rect)
        super.edit(withFrame: adjusted, in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        let adjusted = drawingRect(forBounds: rect)
        super.select(withFrame: adjusted, in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }
}

private final class ResultTableHeaderView: NSTableHeaderView {
    weak var coordinator: QueryResultsTableView.Coordinator?
    private var isDraggingColumns = false

    init(coordinator: QueryResultsTableView.Coordinator?) {
        self.coordinator = coordinator
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func mouseDown(with event: NSEvent) {
        guard let tableView = tableView else {
            super.mouseDown(with: event)
            return
        }
        let location = convert(event.locationInWindow, from: nil)
        let column = tableView.column(at: location)
        if column >= 0 {
            coordinator?.beginColumnSelection(at: column, modifiers: event.modifierFlags)
            isDraggingColumns = true
        } else {
            isDraggingColumns = false
        }
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDraggingColumns, let tableView = tableView else {
            super.mouseDragged(with: event)
            return
        }
        guard !tableView.tableColumns.isEmpty else {
            super.mouseDragged(with: event)
            return
        }
        let location = convert(event.locationInWindow, from: nil)
        var column = tableView.column(at: location)
        if column < 0 {
            column = location.x < 0 ? 0 : tableView.tableColumns.count - 1
        }
        coordinator?.continueColumnSelection(to: column)
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if isDraggingColumns {
            coordinator?.endColumnSelection()
        }
        isDraggingColumns = false
        super.mouseUp(with: event)
    }
}
#endif
