#if os(macOS)
import SwiftUI
import AppKit
import QuartzCore
import Foundation

private enum ResultsGridMetrics {
    static let horizontalPadding: CGFloat = 12
}

struct QueryResultsTableView: NSViewRepresentable {
    @ObservedObject var query: QueryEditorState
    var highlightedColumnIndex: Int?
    var activeSort: SortCriteria?
    var rowOrder: [Int]
    var onColumnTap: (Int) -> Void
    var onSort: (Int, HeaderSortAction) -> Void
    var onClearColumnHighlight: () -> Void
    var backgroundColor: NSColor
    var foreignKeyDisplayMode: ForeignKeyDisplayMode
    var foreignKeyInspectorBehavior: ForeignKeyInspectorBehavior
    var onForeignKeyEvent: (ForeignKeyEvent) -> Void
    var onJsonEvent: (JsonCellEvent) -> Void
    var persistedState: QueryResultsGridState?

    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore
    struct SelectedCell: Equatable {
        let row: Int
        let column: Int
    }

    struct ForeignKeySelection: Equatable {
        let row: Int
        let column: Int
        let value: String
        let columnName: String
        let reference: ColumnInfo.ForeignKeyReference
        let valueKind: ResultGridValueKind
    }

    enum ForeignKeyEvent {
        case selectionChanged(ForeignKeySelection?)
        case activate(ForeignKeySelection)
    }

    struct JsonSelection: Equatable {
        let sourceRowIndex: Int
        let displayedRowIndex: Int
        let columnIndex: Int
        let columnName: String
        let rawValue: String
        let jsonValue: JsonValue
    }

    enum JsonCellEvent {
        case selectionChanged(JsonSelection?)
        case activate(JsonSelection)
    }

    enum HeaderSortAction {
        case ascending
        case descending
        case clear
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, clipboardHistory: clipboardHistory, persistedState: persistedState)
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
        tableView.headerView = NSTableHeaderView()
        tableView.gridStyleMask = []
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        tableView.allowsColumnReordering = false
        tableView.allowsMultipleSelection = true
        tableView.allowsColumnSelection = false
        tableView.autoresizingMask = [.width]
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
        context.coordinator.updatePersistedState(persistedState)
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
        private weak var observedContentView: NSView?
        private let headerMenu = NSMenu()
        private let cellMenu = NSMenu()
        private var menuColumnIndex: Int?
        private var cachedColumnIDs: [String] = []
        private var cachedColumnKinds: [ResultGridValueKind] = []
        private var cachedRowOrder: [Int] = []
        private var cachedSort: SortCriteria?
        private var lastRowCount: Int = 0
        private var lastResultTokenSnapshot: UInt64 = 0
        private var persistedState: QueryResultsGridState?
        private var selectionRegion: SelectedRegion?
        private var selectionAnchor: QueryResultsTableView.SelectedCell?
        private var isDraggingCellSelection = false
        private var selectionFocus: QueryResultsTableView.SelectedCell?
        private var columnSelectionAnchor: Int?
        private var contextMenuCell: QueryResultsTableView.SelectedCell?
        private weak var activeSelectableField: NSTextField?
        private var cachedPaletteSignature: String?
        private var cachedFontStyles: [SQLEditorTokenPalette.ResultGridStyle: NSFont] = [:]
        private let cellBaseFont = NSFont.systemFont(ofSize: 12)
        private var lastForeignKeySelection: QueryResultsTableView.ForeignKeySelection?
        private var lastForeignKeyDisplayMode: ForeignKeyDisplayMode?
        private var lastForeignKeyInspectorBehavior: ForeignKeyInspectorBehavior?
        private var lastJsonSelection: QueryResultsTableView.JsonSelection?
        private var cachedViewportSize: CGSize = .zero
        private var pendingPaginationEvaluation = false
        private var pendingTableSizeAdjustment = false
        private static let isGridDiagnosticsEnabled: Bool = {
            ProcessInfo.processInfo.environment["ECHO_GRID_DEBUG"] == "1"
        }()

        private func resolvedFont(for style: SQLEditorTokenPalette.ResultGridStyle) -> NSFont {
            if let cached = cachedFontStyles[style] {
                return cached
            }
            var traits: NSFontTraitMask = []
            if style.isBold {
                traits.insert(.boldFontMask)
            }
            if style.isItalic {
                traits.insert(.italicFontMask)
            }
            let font: NSFont
            if traits.isEmpty {
                font = cellBaseFont
            } else {
                font = NSFontManager.shared.convert(cellBaseFont, toHaveTrait: traits)
            }
            cachedFontStyles[style] = font
            return font
        }

        var currentTableView: NSTableView? { tableView }

#if DEBUG
        private var debugLogEmissionCount = 0
        private func debugLog(_ message: String) {
            guard Coordinator.isGridDiagnosticsEnabled else { return }
            guard debugLogEmissionCount < 200 else { return }
            debugLogEmissionCount += 1
            print("[GridDebug] \(message)")
        }
#else
        private func debugLog(_ message: String) {}
#endif

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
            registerScrollObservation(for: scrollView)
            tableView.delegate = self
            tableView.dataSource = self
            tableView.menu = cellMenu
            // Configure standard header view
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
            // Configure standard header view
            tableView.headerView?.menu = headerMenu
            tableView.headerView?.frame.size.height = max(tableView.headerView?.frame.size.height ?? 0, 28)
            tableView.headerView?.isHidden = false
            let currentRowOrder = parent.rowOrder
            let currentRowCount = currentRowOrder.isEmpty ? parent.query.displayedRowCount : currentRowOrder.count
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

#if DEBUG
            print("[QueryResultsTableView] update rowCount=\(currentRowCount) displayed=\(parent.query.displayedRowCount) tokenChanged=\(tokenChanged) columnsChanged=\(columnsChanged) mode=\(parent.query.streamingMode)")
#endif

            var performedFullReload = false
            var reloadWorkItem: DispatchWorkItem?
            var rowCountUpdateWorkItem: DispatchWorkItem?

            if columnsChanged || sortChanged || rowOrderChanged || rowCountDecreased {
                performedFullReload = true
                reloadWorkItem = DispatchWorkItem { [weak tableView] in
                    guard let tableView else { return }
                    tableView.reloadData()
#if DEBUG
                    print("[QueryResultsTableView] reloadData executed (columnsChanged=\(columnsChanged) sortChanged=\(sortChanged) rowOrderChanged=\(rowOrderChanged) rowCountDecreased=\(rowCountDecreased) tokenChanged=\(tokenChanged))")
#endif
                    tableView.layoutSubtreeIfNeeded()
                }
            } else if rowCountIncreased {
                let range = lastRowCount..<currentRowCount
                if !range.isEmpty {
                    if tableView.tableColumns.isEmpty {
                        performedFullReload = true
                        reloadWorkItem = DispatchWorkItem { [weak tableView] in
                            guard let tableView else { return }
                            tableView.reloadData()
#if DEBUG
                            print("[QueryResultsTableView] reloadData due to empty columns rowIncrease range=\(range)")
#endif
                            tableView.layoutSubtreeIfNeeded()
                        }
                    } else {
                        rowCountUpdateWorkItem = DispatchWorkItem { [weak tableView] in
                            guard let tableView else { return }
                            let indexes = IndexSet(integersIn: range)
                            CATransaction.begin()
                            CATransaction.setDisableActions(true)
                            tableView.beginUpdates()
                            tableView.insertRows(at: indexes, withAnimation: [])
                            tableView.endUpdates()
                            CATransaction.commit()
#if DEBUG
                            print("[QueryResultsTableView] insertRows range=\(range)")
#endif
                        }
                    }
                }
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
            let needsSizeAdjustment = viewportChanged
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
#if DEBUG
                        print("[QueryResultsTableView] reloadData executed (foreign key display mode change)")
#endif
                        tableView.layoutSubtreeIfNeeded()
                    }
                } else {
                    performedFullReload = true
                }
                notifyForeignKeySelection(selectionRegion)
            }

            if paletteChanged {
                deactivateActiveSelectableField(in: tableView)
                cachedFontStyles.removeAll(keepingCapacity: true)
                applyHeaderStyle(to: tableView)
                if reloadWorkItem == nil {
                    performedFullReload = true
                    reloadWorkItem = DispatchWorkItem { [weak tableView] in
                        guard let tableView else { return }
                        tableView.reloadData()
#if DEBUG
                        print("[QueryResultsTableView] reloadData executed (palette change)")
#endif
                        tableView.layoutSubtreeIfNeeded()
                    }
                } else {
                    performedFullReload = true
                }
                refreshVisibleRowBackgrounds(tableView)
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
                DispatchQueue.main.async(execute: reloadWorkItem)
            } else if let rowCountUpdateWorkItem {
                DispatchQueue.main.async(execute: rowCountUpdateWorkItem)
            }

            if performedFullReload || rowCountIncreased || rowCountDecreased || viewportChanged {
                requestPaginationEvaluation()
            }
        }

        private func registerScrollObservation(for scrollView: NSScrollView) {
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

        @objc private func handleContentViewBoundsChange(_ notification: Notification) {
            requestPaginationEvaluation()
        }

        private func requestPaginationEvaluation() {
            guard !pendingPaginationEvaluation else { return }
            pendingPaginationEvaluation = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pendingPaginationEvaluation = false
                self.evaluatePaginationForVisibleRows()
            }
        }

        private func requestTableSizeAdjustment(rowCount: Int? = nil) {
            guard !pendingTableSizeAdjustment else { return }
            pendingTableSizeAdjustment = true
            let capturedRowCount = rowCount
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pendingTableSizeAdjustment = false
                self.adjustTableSize(rowCount: capturedRowCount)
            }
        }

        private func evaluatePaginationForVisibleRows() {
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
            cachedColumnKinds = parent.query.displayedColumns.map { column in
                ResultGridValueClassifier.kind(for: column, value: "")
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
            // Use system-styled headers with minimal customization
            // Headers will automatically follow system appearance (light/dark mode)
            for column in tableView.tableColumns {
                // Use standard NSTableHeaderCell for system styling
                column.headerCell = NSTableHeaderCell(textCell: column.title)
                column.headerCell.controlSize = .regular
                column.headerCell.alignment = .left
                column.headerCell.title = column.title
                column.headerCell.isHighlighted = false
            }

            // Let the header view redraw with system appearance
            tableView.headerView?.needsDisplay = true
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

        private func headerContentWidth(for column: NSTableColumn, in tableView: NSTableView) -> CGFloat {
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
            let indicatorWidth: CGFloat
            if tableView.indicatorImage(in: column) != nil {
                indicatorWidth = 16
            } else {
                indicatorWidth = 0
            }
            let padding = ResultsGridMetrics.horizontalPadding * 2
            return ceil(size.width) + padding + indicatorWidth + 4
        }

        private func widestCellWidth(forColumn column: Int, tableView: NSTableView) -> CGFloat {
            guard column >= 0 else { return 0 }
            let rowCount = tableView.numberOfRows
            guard rowCount > 0 else { return 0 }

            let padding = ResultsGridMetrics.horizontalPadding * 2
            let columnInfo = column < parent.query.displayedColumns.count ? parent.query.displayedColumns[column] : nil
            let theme = ThemeManager.shared

            var maxWidth = CGFloat.zero
            for row in 0..<rowCount {
                let sourceRow = resolvedRowIndex(for: row)
                let value = parent.query.valueForDisplay(row: sourceRow, column: column)
                let kind = ResultGridValueClassifier.kind(for: columnInfo, value: value)
                let style = theme.resultGridStyle(for: kind)
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
                tableColumn.headerCell.controlSize = .regular
                if !(tableColumn.headerCell is ResultTableHeaderCell) {
                    tableColumn.headerCell = ResultTableHeaderCell(textCell: column.name)
                    tableColumn.headerCell.controlSize = .regular
                    tableColumn.headerCell.alignment = .left
                }
                tableColumn.headerCell.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
                tableView.addTableColumn(tableColumn)
            }
        }

        // MARK: Column Selection

        func beginColumnSelection(at column: Int, modifiers: NSEvent.ModifierFlags) {
            guard tableView != nil else { return }
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
            let totalRows = rowCount ?? (parent.rowOrder.isEmpty ? parent.query.displayedRowCount : parent.rowOrder.count)
            let headerHeight = tableView.headerView?.frame.height ?? 0
            let viewportHeight = scrollView.contentView.bounds.height
            cachedViewportSize = scrollView.contentView.bounds.size
            let resolvedRows = max(totalRows, 0)
            let contentHeight = max(CGFloat(resolvedRows) * tableView.rowHeight + headerHeight, viewportHeight)
            let newSize = NSSize(width: targetWidth, height: contentHeight)
            let widthDelta = abs(tableView.frame.size.width - newSize.width)
            let heightDelta = abs(tableView.frame.size.height - newSize.height)
            if widthDelta > 0.5 || heightDelta > 0.5 {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                tableView.setFrameSize(newSize)
                CATransaction.commit()
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
            let cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? ResultTableDataCellView ?? makeDataCellView(identifier: identifier)
            let textField = cellView.contentTextField

            let sourceIndex = resolvedRowIndex(for: row)
            let rawValue = parent.query.valueForDisplay(row: sourceIndex, column: dataIndex)
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
            let style = theme.resultGridStyle(for: kind)
            let resolvedValue = rawValue ?? ""

            switch kind {
            case .null:
                textField.stringValue = "NULL"
            default:
                textField.stringValue = resolvedValue
            }

            textField.textColor = style.nsColor
            textField.font = resolvedFont(for: style)
            textField.drawsBackground = false
            textField.backgroundColor = .clear
            textField.layer?.backgroundColor = NSColor.clear.cgColor
            textField.layer?.borderWidth = 0
            textField.layer?.borderColor = nil

            let cellSelection = QueryResultsTableView.SelectedCell(row: row, column: dataIndex)
            let isSelectedCell = selectionRegion?.contains(cellSelection) ?? false
            if isSelectedCell {
                textField.textColor = theme.resultsGridCellTextNSColor
            }

            let showsIcon = shouldShowForeignKeyIcon(forColumnInfo: columnInfo, value: rawValue)
            if showsIcon {
                cellView.configureIcon { [weak self] in
                    self?.activateForeignKey(at: cellSelection)
                }
            } else {
                cellView.configureIcon(nil)
            }

            cellView.frame = NSRect(x: 0, y: 0, width: tableColumn.width, height: tableView.rowHeight)
            return cellView
        }

        private func makeDataCellView(identifier: NSUserInterfaceItemIdentifier) -> ResultTableDataCellView {
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
            }
            return cellView
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
                let clickedColumn = menuColumnIndex ?? tableView.clickedColumn
                guard clickedColumn >= 0 else {
                    menuColumnIndex = nil
                    return
                }
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
            menuColumnIndex = nil
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

        func prepareHeaderContextMenu(at column: Int?) {
            if let column, column >= 0 {
                menuColumnIndex = column
            } else {
                menuColumnIndex = nil
            }
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
            let cell = consumeContextMenuCell()
                ?? resolvedCell(forRow: tableView.clickedRow, column: tableView.clickedColumn, tableView: tableView)
            guard let cell else {
                return
            }

            if let region = selectionRegion, region.contains(cell) {
                tableView.deselectAll(nil)
                tableView.selectionHighlightStyle = .none
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
            contextMenuCell = nil
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
                if let jsonSelection = makeJsonSelection(for: cell) {
                    parent.onJsonEvent(.activate(jsonSelection))
                    isDraggingCellSelection = false
                    return
                } else {
                    focusCellEditor(at: cell, tableView: tableView)
                    isDraggingCellSelection = false
                    return
                }
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

        func handleRightMouseDown(_ event: NSEvent, in tableView: NSTableView) {
            guard tableView.numberOfRows > 0 else { return }
            deactivateActiveSelectableField(in: tableView)
            let point = tableView.convert(event.locationInWindow, from: nil)
            if point.y < 0 {
                contextMenuCell = nil
                return
            }

            guard let cell = resolvedCell(at: point, in: tableView, allowOutOfBounds: false) else {
                contextMenuCell = nil
                setSelectionRegion(nil, tableView: tableView)
                selectionAnchor = nil
                selectionFocus = nil
                return
            }

            if let region = selectionRegion, region.contains(cell) {
                contextMenuCell = cell
                selectionFocus = cell
                if selectionAnchor == nil {
                    selectionAnchor = region.start
                }
                return
            }

            let region = SelectedRegion(start: cell, end: cell)
            setSelectionRegion(region, tableView: tableView)
            selectionAnchor = cell
            selectionFocus = cell
            parent.onClearColumnHighlight()
            contextMenuCell = cell
        }

        func consumeContextMenuCell() -> QueryResultsTableView.SelectedCell? {
            defer { contextMenuCell = nil }
            return contextMenuCell
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
               event.modifierFlags.contains(.command) {
                switch characters {
                case "c":
                    copySelection(includeHeaders: event.modifierFlags.contains(.shift))
                    return true
                case "a":
                    selectAllCells(in: tableView)
                    return true
                default:
                    break
                }
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
                moveSelection(rowDelta: 0, columnDelta: -Int.max, extend: extend, tableView: tableView)
                return true
            case .end:
                moveSelection(rowDelta: 0, columnDelta: Int.max, extend: extend, tableView: tableView)
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

        private func selectAllCells(in tableView: NSTableView) {
            let columnCount = tableView.tableColumns.count
            let rowCount = tableView.numberOfRows
            guard columnCount > 0, rowCount > 0 else {
                setSelectionRegion(nil, tableView: tableView)
                return
            }

            let topLeft = QueryResultsTableView.SelectedCell(row: 0, column: 0)
            let bottomRight = QueryResultsTableView.SelectedCell(row: rowCount - 1, column: columnCount - 1)
            setSelectionRegion(SelectedRegion(start: topLeft, end: bottomRight), tableView: tableView)
            selectionAnchor = topLeft
            selectionFocus = bottomRight
            isDraggingCellSelection = false
            parent.onClearColumnHighlight()
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
                column = clampColumn(column, point: point, tableView: tableView)
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

        private func clampColumn(_ column: Int, point: NSPoint, tableView: NSTableView) -> Int {
            let maxIndex = tableView.tableColumns.count - 1
            if maxIndex < 0 { return -1 }
            if column >= 0 && column <= maxIndex { return column }

            if point.x < 0 {
                return 0
            }

            let lastColumnRect = tableView.rect(ofColumn: maxIndex)
            if point.x > lastColumnRect.maxX {
                return maxIndex
            }

            let clampedX = min(max(point.x, 0), lastColumnRect.maxX - 1)
            let probePoint = NSPoint(x: clampedX, y: point.y)
            let fallback = tableView.column(at: probePoint)
            if fallback >= 0 {
                return min(fallback, maxIndex)
            }

            var cumulativeWidth: CGFloat = 0
            for (index, column) in tableView.tableColumns.enumerated() {
                cumulativeWidth += column.width
                if clampedX < cumulativeWidth {
                    return index
                }
            }

            return maxIndex
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

        private func notifyJsonSelection(_ region: SelectedRegion?) {
            guard let region,
                  region.start.row == region.end.row,
                  region.start.column == region.end.column,
                  let selection = makeJsonSelection(for: region.start) else {
                if lastJsonSelection != nil {
                    lastJsonSelection = nil
                    parent.onJsonEvent(.selectionChanged(nil))
                }
                return
            }

            if lastJsonSelection != selection {
                lastJsonSelection = selection
                parent.onJsonEvent(.selectionChanged(selection))
            }
        }

        private func notifyForeignKeySelection(_ region: SelectedRegion?) {
            guard parent.foreignKeyDisplayMode != .disabled else {
                lastForeignKeySelection = nil
                parent.onForeignKeyEvent(.selectionChanged(nil))
                return
            }

            guard let region,
                  region.start.row == region.end.row,
                  region.start.column == region.end.column,
                  let selection = makeForeignKeySelection(for: region.start) else {
                if lastForeignKeySelection != nil {
                    lastForeignKeySelection = nil
                    parent.onForeignKeyEvent(.selectionChanged(nil))
                }
                return
            }

            if lastForeignKeySelection != selection {
                lastForeignKeySelection = selection
                parent.onForeignKeyEvent(.selectionChanged(selection))
            }
        }

        private func makeJsonSelection(for cell: QueryResultsTableView.SelectedCell) -> QueryResultsTableView.JsonSelection? {
            guard cell.column >= 0,
                  cell.column < parent.query.displayedColumns.count else { return nil }
            let columnInfo = parent.query.displayedColumns[cell.column]
            let sourceRowIndex = resolvedRowIndex(for: cell.row)
            guard sourceRowIndex >= 0,
                  let rawValue = parent.query.valueForDisplay(row: sourceRowIndex, column: cell.column) else {
                return nil
            }
            let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let kind = ResultGridValueClassifier.kind(for: columnInfo, value: rawValue)
            guard kind == .json else { return nil }
            guard let jsonValue = try? JsonValue.parse(from: rawValue) else { return nil }
            return QueryResultsTableView.JsonSelection(
                sourceRowIndex: sourceRowIndex,
                displayedRowIndex: cell.row,
                columnIndex: cell.column,
                columnName: columnInfo.name,
                rawValue: rawValue,
                jsonValue: jsonValue
            )
        }

        private func makeForeignKeySelection(for cell: QueryResultsTableView.SelectedCell) -> QueryResultsTableView.ForeignKeySelection? {
            guard cell.column >= 0,
                  cell.column < parent.query.displayedColumns.count else { return nil }
            let columnInfo = parent.query.displayedColumns[cell.column]
            guard let reference = columnInfo.foreignKey else { return nil }
            let rowIndex = resolvedRowIndex(for: cell.row)
            guard let rawValue = parent.query.valueForDisplay(row: rowIndex, column: cell.column) else { return nil }
            let kind = ResultGridValueClassifier.kind(for: columnInfo, value: rawValue)
            return QueryResultsTableView.ForeignKeySelection(
                row: rowIndex,
                column: cell.column,
                value: rawValue,
                columnName: columnInfo.name,
                reference: reference,
                valueKind: kind
            )
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
            notifyJsonSelection(region)
            notifyForeignKeySelection(region)
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

final class ResultTableContainerView: NSView {
    let scrollView: NSScrollView
    private let leadingView: ResultTableLeadingBackgroundView
    private var leadingWidth: CGFloat

    init(scrollView: NSScrollView, leadingWidth: CGFloat) {
        self.scrollView = scrollView
        self.leadingWidth = max(0, leadingWidth)
        self.leadingView = ResultTableLeadingBackgroundView(width: self.leadingWidth)
        super.init(frame: .zero)

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

private final class ResultTableLeadingBackgroundView: NSView {
    private var configuredWidth: CGFloat
    private let separatorLayer = CALayer()

    init(width: CGFloat) {
        self.configuredWidth = width
        super.init(frame: .zero)
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

    override func drawBackground(inClipRect clipRect: NSRect) {
        ThemeManager.shared.resultsGridCellBackgroundNSColor.setFill()
        clipRect.fill()
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

    override func rightMouseDown(with event: NSEvent) {
        selectionDelegate?.handleRightMouseDown(event, in: self)
        let location = convert(event.locationInWindow, from: nil)
        let row = row(at: location)

        if selectionDelegate?.hasActiveCellSelection == true {
            deselectAll(nil)
            selectionHighlightStyle = .none
            if row >= 0, let rowView = rowView(atRow: row, makeIfNecessary: false) {
                rowView.needsDisplay = true
                rowView.displayIfNeeded()
            } else {
                needsDisplay = true
                displayIfNeeded()
            }
        }

        if let contextMenu = menu {
            NSMenu.popUpContextMenu(contextMenu, with: event, for: self)
        } else {
            super.rightMouseDown(with: event)
        }
    }

    override func keyDown(with event: NSEvent) {
        if selectionDelegate?.handleKeyDown(event, in: self) == true {
            return
        }
        super.keyDown(with: event)
    }

    override func selectRowIndexes(_ indexes: IndexSet, byExtendingSelection extend: Bool) {
        if selectionDelegate?.hasActiveCellSelection == true,
           let currentEvent = NSApp.currentEvent,
           currentEvent.type == .rightMouseDown
                || currentEvent.type == .otherMouseDown
                || currentEvent.type == .rightMouseDragged
                || (currentEvent.type == .leftMouseDown && currentEvent.modifierFlags.contains(.control)) {
            super.selectRowIndexes(IndexSet(), byExtendingSelection: false)
            return
        }
        super.selectRowIndexes(indexes, byExtendingSelection: extend)
    }

    @objc func copy(_ sender: Any?) {
        if selectionDelegate?.performMenuCopy(in: self) == true {
            return
        }
        NSApp.sendAction(#selector(NSTextView.copy(_:)), to: nil, from: self)
    }
}

private final class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    private let horizontalPadding: CGFloat = ResultsGridMetrics.horizontalPadding

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

private final class ResultTableDataCellView: NSTableCellView {
    let contentTextField: NSTextField
    private let actionButton: NSButton
    private var actionHandler: (() -> Void)?

    override init(frame frameRect: NSRect) {
        contentTextField = NSTextField(frame: .zero)
        actionButton = NSButton(frame: .zero)
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        contentTextField = NSTextField(frame: .zero)
        actionButton = NSButton(frame: .zero)
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        contentTextField.isEditable = false
        contentTextField.isSelectable = false
        contentTextField.isBordered = false
        contentTextField.drawsBackground = false
        contentTextField.focusRingType = .none
        contentTextField.wantsLayer = true
        if let layer = contentTextField.layer {
            layer.masksToBounds = true
            layer.cornerRadius = 6
            if #available(macOS 10.15, *) {
                layer.cornerCurve = .continuous
            }
        }
        contentTextField.lineBreakMode = .byTruncatingTail
        contentTextField.usesSingleLineMode = true
        contentTextField.maximumNumberOfLines = 1
        contentTextField.alignment = .left
        contentTextField.translatesAutoresizingMaskIntoConstraints = true
        contentTextField.autoresizingMask = [.width, .height]
        addSubview(contentTextField)
        textField = contentTextField

        actionButton.target = self
        actionButton.action = #selector(handleAction)
        actionButton.isBordered = false
        actionButton.bezelStyle = .inline
        actionButton.image = NSImage(systemSymbolName: "arrow.up.right.square", accessibilityDescription: "Show Inspector")
        actionButton.imageScaling = .scaleProportionallyDown
        actionButton.contentTintColor = NSColor.secondaryLabelColor
        actionButton.isHidden = true
        actionButton.translatesAutoresizingMaskIntoConstraints = true
        actionButton.autoresizingMask = []
        addSubview(actionButton)
    }

    func configureIcon(_ handler: (() -> Void)?) {
        actionHandler = handler
        let shouldShow = handler != nil
        actionButton.isHidden = !shouldShow
        actionButton.isEnabled = shouldShow
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let padding = ResultsGridMetrics.horizontalPadding
        let buttonWidth: CGFloat = actionButton.isHidden ? 0 : 18
        let spacing: CGFloat = actionButton.isHidden ? 0 : 6
        let availableWidth = max(bounds.width - padding * 2 - buttonWidth - spacing, 0)
        contentTextField.frame = NSRect(x: padding, y: 0, width: availableWidth, height: bounds.height)
        if !actionButton.isHidden {
            let buttonHeight: CGFloat = 16
            let originY = (bounds.height - buttonHeight) / 2
            actionButton.frame = NSRect(x: bounds.width - padding - buttonWidth, y: originY, width: buttonWidth, height: buttonHeight)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        actionHandler = nil
        configureIcon(nil)
    }

    @objc private func handleAction() {
        actionHandler?()
    }
}

private struct ResultTableHeaderStyle {
    let topColor: NSColor
    let bottomColor: NSColor
    let sheenTopAlpha: CGFloat
    let sheenMidAlpha: CGFloat
    let highlightAlpha: CGFloat
    let borderColor: NSColor
    let separatorColor: CGColor

    static func make(for theme: ThemeManager) -> ResultTableHeaderStyle {
        let baseColor = theme.resultsGridHeaderBackgroundNSColor.usingColorSpace(.extendedSRGB) ?? theme.resultsGridHeaderBackgroundNSColor
        let accentColor = theme.accentNSColor.usingColorSpace(.extendedSRGB) ?? theme.accentNSColor
        let isDarkMode = theme.activePaletteTone == .dark

        let topBlendFraction: CGFloat = isDarkMode ? 0.12 : 0.08
        let bottomBlendFraction: CGFloat = isDarkMode ? 0.28 : 0.24
        let topBlendColor: NSColor = isDarkMode ? NSColor.white : accentColor
        let bottomBlendColor: NSColor
        if isDarkMode {
            bottomBlendColor = accentColor
        } else if let shadedAccent = accentColor.shadow(withLevel: 0.2) {
            bottomBlendColor = shadedAccent
        } else {
            bottomBlendColor = accentColor
        }

        let topColor = baseColor.blended(withFraction: topBlendFraction, of: topBlendColor) ?? baseColor
        let bottomColor = baseColor.blended(withFraction: bottomBlendFraction, of: bottomBlendColor) ?? baseColor

        let highlightAlpha: CGFloat = isDarkMode ? 0.12 : 0.16
        let sheenTop: CGFloat = isDarkMode ? 0.08 : 0.12
        let sheenMid: CGFloat = isDarkMode ? 0.04 : 0.06
        let borderColor: NSColor
        if isDarkMode {
            borderColor = accentColor.withAlphaComponent(0.5)
        } else if let shadedBase = baseColor.shadow(withLevel: 0.25) {
            borderColor = shadedBase
        } else {
            borderColor = theme.resultsGridHeaderSeparatorNSColor
        }
        let separatorColor = theme.accentNSColor.withAlphaComponent(isDarkMode ? 0.3 : 0.22).cgColor

        return ResultTableHeaderStyle(
            topColor: topColor,
            bottomColor: bottomColor,
            sheenTopAlpha: sheenTop,
            sheenMidAlpha: sheenMid,
            highlightAlpha: highlightAlpha,
            borderColor: borderColor,
            separatorColor: separatorColor
        )
    }
}

private final class ResultTableHeaderView: NSTableHeaderView {
    weak var coordinator: QueryResultsTableView.Coordinator?
    private var isDraggingColumns = false
    private let backgroundLayer = CAGradientLayer()
    private let sheenLayer = CAGradientLayer()
    private let topHighlightLayer = CALayer()
    private let bottomBorderLayer = CALayer()
    private var separatorLayers: [CALayer] = []
    private var separatorColor: CGColor?
    private let resizeEdgeTolerance: CGFloat = 5

    init(coordinator: QueryResultsTableView.Coordinator?) {
        self.coordinator = coordinator
        super.init(frame: .zero)
        configureLayers()
        updateAppearance(with: ThemeManager.shared)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayers()
        updateAppearance(with: ThemeManager.shared)
    }

    private func configureLayers() {
        wantsLayer = true
        layer?.masksToBounds = false

        backgroundLayer.startPoint = CGPoint(x: 0, y: 0)
        backgroundLayer.endPoint = CGPoint(x: 0, y: 1)
        backgroundLayer.locations = [0, 1]
        backgroundLayer.zPosition = -10

        sheenLayer.startPoint = CGPoint(x: 0, y: 0)
        sheenLayer.endPoint = CGPoint(x: 0, y: 1)
        sheenLayer.locations = [0, 0.4, 1]
        sheenLayer.zPosition = -5

        topHighlightLayer.masksToBounds = true
        topHighlightLayer.zPosition = 2
        bottomBorderLayer.masksToBounds = true
        bottomBorderLayer.zPosition = 2

        layer?.addSublayer(backgroundLayer)
        layer?.addSublayer(sheenLayer)
        layer?.addSublayer(topHighlightLayer)
        layer?.addSublayer(bottomBorderLayer)
    }

    func updateAppearance(with theme: ThemeManager) {
        let style = ResultTableHeaderStyle.make(for: theme)

        backgroundLayer.colors = [
            style.topColor.cgColor,
            style.bottomColor.cgColor
        ]

        sheenLayer.colors = [
            NSColor.white.withAlphaComponent(style.sheenTopAlpha).cgColor,
            NSColor.white.withAlphaComponent(style.sheenMidAlpha).cgColor,
            NSColor.clear.cgColor
        ]

        topHighlightLayer.backgroundColor = NSColor.white.withAlphaComponent(style.highlightAlpha).cgColor
        bottomBorderLayer.backgroundColor = style.borderColor.cgColor
        separatorColor = style.separatorColor
        separatorLayers.forEach { $0.backgroundColor = separatorColor }

        needsLayout = true
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backgroundLayer.frame = bounds
        sheenLayer.frame = bounds
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        let lineWidth = 1 / max(scale, 1)
        topHighlightLayer.frame = CGRect(x: 0, y: bounds.height - lineWidth, width: bounds.width, height: lineWidth)
        bottomBorderLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: lineWidth)
        updateSeparatorFrames(lineWidth: lineWidth)
        CATransaction.commit()
    }

    override func mouseDown(with event: NSEvent) {
        guard event.buttonNumber == 0,
              !event.modifierFlags.contains(.control),
              let tableView = tableView else {
            super.mouseDown(with: event)
            return
        }

        let location = convert(event.locationInWindow, from: nil)
        let column = tableView.column(at: location)
        if column >= 0 {
            let columnRect = headerRect(ofColumn: column)
            let isNearLeftEdge = column > 0 && abs(location.x - columnRect.minX) <= resizeEdgeTolerance
            let isNearRightEdge = abs(location.x - columnRect.maxX) <= resizeEdgeTolerance
            if isNearLeftEdge || isNearRightEdge {
                isDraggingColumns = false
                super.mouseDown(with: event)
                return
            }
            coordinator?.beginColumnSelection(at: column, modifiers: event.modifierFlags)
            isDraggingColumns = true
        } else {
            isDraggingColumns = false
        }
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard event.buttonNumber == 0,
              !event.modifierFlags.contains(.control),
              isDraggingColumns,
              let tableView = tableView else {
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
        if isDraggingColumns, event.buttonNumber == 0 {
            coordinator?.endColumnSelection()
        }
        isDraggingColumns = false
        super.mouseUp(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let location = convert(event.locationInWindow, from: nil)
        let column = tableView?.column(at: location) ?? -1
        coordinator?.prepareHeaderContextMenu(at: column >= 0 ? column : nil)
        return menu ?? super.menu(for: event)
    }

    private func updateSeparatorFrames(lineWidth: CGFloat) {
        guard let tableView else {
            separatorLayers.forEach { $0.removeFromSuperlayer() }
            separatorLayers.removeAll()
            return
        }

        let columnCount = tableView.numberOfColumns
        let required = max(columnCount - 1, 0)

        if separatorLayers.count != required {
            separatorLayers.forEach { $0.removeFromSuperlayer() }
            separatorLayers.removeAll()

            guard required > 0 else { return }

            for _ in 0..<required {
                let layer = CALayer()
                layer.zPosition = 1
                layer.backgroundColor = separatorColor
                self.layer?.addSublayer(layer)
                separatorLayers.append(layer)
            }
        }

        guard !separatorLayers.isEmpty else { return }

        for (index, layer) in separatorLayers.enumerated() {
            let columnRect = tableView.rect(ofColumn: index)
            let converted = convert(columnRect, from: tableView)
            let xPosition = converted.maxX - lineWidth / 2
            layer.backgroundColor = separatorColor
            layer.frame = CGRect(x: xPosition, y: 0, width: lineWidth, height: bounds.height)
        }
    }
}

private final class ResultTableHeaderCell: NSTableHeaderCell {
    override init(textCell: String) {
        super.init(textCell: textCell)
        lineBreakMode = .byTruncatingTail
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        lineBreakMode = .byTruncatingTail
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        var adjusted = rect.insetBy(dx: ResultsGridMetrics.horizontalPadding, dy: 0)
        let attributed = attributedStringValue
        if attributed.length > 0 {
            let bounds = attributed.boundingRect(
                with: CGSize(width: adjusted.width, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            let clampedHeight = min(bounds.height, adjusted.height)
            adjusted.origin.y = adjusted.midY - clampedHeight / 2
            adjusted.size.height = clampedHeight
        }
        adjusted.origin.y = floor(adjusted.origin.y)
        return adjusted
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        if isHighlighted {
            let theme = ThemeManager.shared
            let base = theme.resultsGridHeaderBackgroundNSColor
            let pressed = base.shadow(withLevel: 0.18) ?? base
            pressed.setFill()
            cellFrame.fill()
        }
        drawInterior(withFrame: cellFrame, in: controlView)
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let attributed = attributedStringValue.length > 0
            ? attributedStringValue
            : NSAttributedString(string: title)
        let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        let rect = titleRect(forBounds: cellFrame)
        attributed.draw(with: rect, options: options)
    }
}
#endif
