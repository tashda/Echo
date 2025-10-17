Echo/Sources/Domain/Tabs/WorkspaceTab.swift:            print("[GridDebug] sanitized columns (\(source)): count=\(normalized.count) sample=[\(sample)]")
Echo/Sources/Domain/Tabs/WorkspaceTab.swift:            print("[GridDebug] sanitized columns (\(source)): count=0")
Echo/Sources/UI/Results/QueryResultsTableView.swift:            print("[GridDebug] \(message)")
Echo/Sources/UI/Results/QueryResultsTableView.swift:        print("[GridDebug] Container layout -> frame=\(frame) scrollFrame=\(scrollView.frame) overlayFrame=\(overlay.frame) tableFrame=\(tableFrame)")
Echo/Sources/UI/Results/QueryResultsTableView.swift:        print("[GridDebug] Container subviews -> \(subviews.map { type(of: $0) })")
Echo/Sources/UI/Results/QueryResultsTableView.swift:            print("[GridDebug] RowIndexOverlay draw bounds=\(bounds) tableFrame=\(tableView.frame) scrollContentSize=\(scrollView.contentSize)")

#if os(macOS)
import SwiftUI
import AppKit
import QuartzCore

struct QueryResultsTableView: NSViewRepresentable {
    @ObservedObject var query: QueryEditorState
    var highlightedColumnIndex: Int?
    var activeSort: SortCriteria?
    var rowOrder: [Int]
    var onColumnTap: (Int) -> Void
    var onSort: (Int, HeaderSortAction) -> Void
    var backgroundColor: NSColor

    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore

    private let rowIndexWidth: CGFloat = 52

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
        if #available(macOS 13.0, *) {
            tableView.style = .inset
        }

        let overlay = RowIndexOverlayView(coordinator: context.coordinator, scrollView: scrollView, width: rowIndexWidth)
        let container = ResultTableContainerView(scrollView: scrollView, overlay: overlay)

        context.coordinator.configure(tableView: tableView, scrollView: scrollView, overlay: overlay)
        tableView.selectionDelegate = context.coordinator
        scrollView.documentView = tableView
        container.updateBackgroundColor(backgroundColor)
        return container
    }

    func updateNSView(_ nsView: ResultTableContainerView, context: Context) {
        guard let tableView = nsView.tableView else { return }
        tableView.backgroundColor = backgroundColor
        tableView.usesAlternatingRowBackgroundColors = ThemeManager.shared.showAlternateRowShading
        nsView.updateBackgroundColor(backgroundColor)
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
        private var rowIndexOverlay: RowIndexOverlayView?
        private var selectionFocus: QueryResultsTableView.SelectedCell?
        private var rowSelectionAnchor: Int?
        private var columnSelectionAnchor: Int?

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

        func configure(tableView: NSTableView, scrollView: NSScrollView, overlay: RowIndexOverlayView) {
            self.tableView = tableView
            self.scrollView = scrollView
            tableView.delegate = self
            tableView.dataSource = self
            tableView.menu = cellMenu
            if let header = tableView.headerView as? ResultTableHeaderView {
                header.coordinator = self
                header.menu = headerMenu
            } else {
                tableView.headerView?.menu = headerMenu
            }
            tableView.selectionHighlightStyle = .regular
            _ = reloadColumns()

            rowIndexOverlay = overlay
            overlay.refresh()

            scrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(contentViewDidScroll(_:)),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
        }

        func update(parent: QueryResultsTableView, tableView: NSTableView) {
            self.parent = parent
            if self.tableView == nil {
                self.tableView = tableView
            }
            if let header = tableView.headerView as? ResultTableHeaderView {
                header.coordinator = self
                header.menu = headerMenu
            } else {
                tableView.headerView?.menu = headerMenu
            }
            let currentRowOrder = parent.rowOrder
            let currentRowCount = currentRowOrder.isEmpty ? parent.query.displayedRowCount : currentRowOrder.count
            let columnsChanged = reloadColumns()
            let sortChanged = parent.activeSort != cachedSort
            let rowOrderChanged = currentRowOrder != cachedRowOrder

            var performedFullReload = false

            if columnsChanged || sortChanged || rowOrderChanged || currentRowCount < lastRowCount {
                tableView.reloadData()
                performedFullReload = true
            } else if currentRowCount > lastRowCount {
                let range = lastRowCount..<currentRowCount
                if !range.isEmpty {

        func continueColumnSelection(to column: Int) {
            guard let tableView else { return }
            guard let anchor = columnSelectionAnchor else { return }
            let columnCount = parent.query.displayedColumns.count
            guard columnCount > 0 else { return }
            let clampedColumn = max(0, min(column, columnCount - 1))
            applyColumnSelection(from: anchor, to: clampedColumn)
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
            guard maxRow >= 0 else {
                tableView.scrollColumnToVisible(lower)
                tableView.scrollColumnToVisible(upper)
                return
            }

            let top = QueryResultsTableView.SelectedCell(row: 0, column: lower)
            let bottom = QueryResultsTableView.SelectedCell(row: maxRow, column: upper)
            setSelectionRegion(SelectedRegion(start: top, end: bottom), tableView: tableView)
            tableView.scrollColumnToVisible(lower)
            tableView.scrollColumnToVisible(upper)
        }

        private func adjustTableSize(rowCount: Int? = nil) {
            guard let tableView, let scrollView else { return }
            let contentWidth = tableView.tableColumns.reduce(0.0) { $0 + Double($1.width) }
            let targetWidth = max(CGFloat(contentWidth), scrollView.contentSize.width)
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

        @objc private func contentViewDidScroll(_ notification: Notification) {
            guard let tableView else { return }
            reloadIndexColumn(for: tableView)
        }
    }
}

final class ResultTableContainerView: NSView {
    let scrollView: NSScrollView
    let overlay: RowIndexOverlayView

    init(scrollView: NSScrollView, overlay: RowIndexOverlayView) {
        self.scrollView = scrollView
        self.overlay = overlay
        super.init(frame: .zero)

        wantsLayer = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        overlay.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)
        addSubview(overlay)

        overlay.layer?.zPosition = 1

        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlay.topAnchor.constraint(equalTo: topAnchor),
            overlay.bottomAnchor.constraint(equalTo: bottomAnchor),
            overlay.widthAnchor.constraint(equalToConstant: overlay.width),

            scrollView.leadingAnchor.constraint(equalTo: overlay.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var tableView: NSTableView? {
        scrollView.documentView as? NSTableView
    }

    func updateBackgroundColor(_ color: NSColor) {
        wantsLayer = true
        layer?.backgroundColor = color.cgColor
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.contentView.backgroundColor = .clear
        overlay.updateBackgroundColor(color)
    }

    override func layout() {
        super.layout()
        #if DEBUG
        let tableFrame = tableView?.frame ?? .zero
        print("[GridDebug] Container layout -> frame=\(frame) scrollFrame=\(scrollView.frame) overlayFrame=\(overlay.frame) tableFrame=\(tableFrame)")
        print("[GridDebug] Container subviews -> \(subviews.map { type(of: $0) })")
        #endif

Echo/Sources/UI/Results/QueryResultsTableView.swift:61:        let overlay = RowIndexOverlayView(coordinator: context.coordinator, scrollView: scrollView, width: rowIndexWidth)
Echo/Sources/UI/Results/QueryResultsTableView.swift:94:        private var rowIndexOverlay: RowIndexOverlayView?
Echo/Sources/UI/Results/QueryResultsTableView.swift:149:        func configure(tableView: NSTableView, scrollView: NSScrollView, overlay: RowIndexOverlayView) {
Echo/Sources/UI/Results/QueryResultsTableView.swift:1147:    let overlay: RowIndexOverlayView
Echo/Sources/UI/Results/QueryResultsTableView.swift:1149:    init(scrollView: NSScrollView, overlay: RowIndexOverlayView) {
Echo/Sources/UI/Results/QueryResultsTableView.swift:1329:final class RowIndexOverlayView: NSView {

    override func mouseUp(with event: NSEvent) {
        if isDraggingColumns {
            coordinator?.endColumnSelection()
        }
        isDraggingColumns = false
        super.mouseUp(with: event)
    }
}

final class RowIndexOverlayView: NSView {
    weak var coordinator: QueryResultsTableView.Coordinator?
    weak var scrollView: NSScrollView?
    let width: CGFloat

    private let headerFont = NSFont.systemFont(ofSize: 11, weight: .medium)
    private let rowFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    private var isDraggingRowSelection = false
    private var overlayBackgroundColor: NSColor = .windowBackgroundColor

    init(coordinator: QueryResultsTableView.Coordinator, scrollView: NSScrollView, width: CGFloat) {
        self.coordinator = coordinator
        self.scrollView = scrollView
        self.width = width
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }

    override var isFlipped: Bool { true }

    func refresh() {
        needsDisplay = true
    }

    func updateBackgroundColor(_ color: NSColor) {
        overlayBackgroundColor = color
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let coordinator,
              let tableView = coordinator.currentTableView,
              let scrollView = scrollView else {
            NSColor.controlBackgroundColor.setFill()
            dirtyRect.fill()
            return
        }

        #if DEBUG
        if dirtyRect.origin == .zero {
            print("[GridDebug] RowIndexOverlay draw bounds=\(bounds) tableFrame=\(tableView.frame) scrollContentSize=\(scrollView.contentSize)")
        }
        #endif

        overlayBackgroundColor.setFill()
        dirtyRect.fill()

        let headerRect: NSRect?
        if let headerView = tableView.headerView {
            var converted = headerView.bounds
            converted = tableView.convert(converted, to: self)
            converted.origin.x = 0
            converted.size.width = bounds.width
            let clipped = converted.intersection(bounds)
            headerRect = clipped

            if !clipped.isEmpty {
                NSColor.controlBackgroundColor.setFill()
                clipped.fill()

                let headerString = "#" as NSString
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: headerFont,
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
                let size = headerString.size(withAttributes: attributes)
                let centerPoint = NSPoint(
                    x: clipped.midX - size.width / 2,
                    y: clipped.midY - size.height / 2
                )
                headerString.draw(at: centerPoint, withAttributes: attributes)
            }
        } else {
            headerRect = nil
        }

        let visibleRect = scrollView.contentView.bounds
        let visibleRows = tableView.rows(in: visibleRect)
        guard visibleRows.length > 0 else { return }

        let start = max(0, Int(visibleRows.location))
        let end = min(tableView.numberOfRows, start + Int(visibleRows.length) + 1)
        let selection = tableView.selectedRowIndexes

        for row in start..<end {
            let rowRectInTable = tableView.rect(ofRow: row)
            var rectInScroll = tableView.convert(rowRectInTable, to: scrollView)
            rectInScroll.origin.x = 0
            rectInScroll.size.width = width
            let rowRect = convert(rectInScroll, from: scrollView)

            var drawRect = rowRect
            if let headerRect, drawRect.intersects(headerRect) {
                let overlap = headerRect.maxY - drawRect.minY
                if overlap >= drawRect.height {
                    continue
                }
                drawRect.origin.y += overlap
                drawRect.size.height -= overlap
            }

            if drawRect.height <= 0 { continue }

            if selection.contains(row) {
                ThemeManager.shared.accentNSColor.withAlphaComponent(0.18).setFill()
                drawRect.fill()
            } else if coordinator.isRowInCellSelection(row) {
                ThemeManager.shared.accentNSColor.withAlphaComponent(0.1).setFill()
                drawRect.fill()
            } else {
                overlayBackgroundColor.setFill()
                drawRect.fill()
            }

            let number = "\(row + 1)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: rowFont,
                .foregroundColor: selection.contains(row) ? ThemeManager.shared.accentNSColor : NSColor.secondaryLabelColor
            ]
            let size = number.size(withAttributes: attributes)
            let insetRect = drawRect.insetBy(dx: 6, dy: max(0, (drawRect.height - size.height) / 2 - 1))
            let textPoint = NSPoint(x: insetRect.maxX - size.width, y: insetRect.minY + max(0, (insetRect.height - size.height) / 2))
            number.draw(at: textPoint, withAttributes: attributes)
        }

        let dividerPath = NSBezierPath()
        dividerPath.move(to: NSPoint(x: bounds.width - 0.5, y: 0))
        dividerPath.line(to: NSPoint(x: bounds.width - 0.5, y: bounds.height))
        NSColor.separatorColor.setStroke()
        dividerPath.lineWidth = 1
        dividerPath.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        guard let coordinator = coordinator,
              let tableView = coordinator.currentTableView,
              let scrollView = scrollView else { return }

        let locationInOverlay = convert(event.locationInWindow, from: nil)
        let pointInScroll = convert(locationInOverlay, to: scrollView)
        let pointInTable = tableView.convert(pointInScroll, from: scrollView)

        let rawRow = tableView.row(at: pointInTable)
        let row = clampRow(rawRow, point: pointInTable, tableView: tableView)
        guard row >= 0 else { return }

        window?.makeFirstResponder(tableView)
        isDraggingRowSelection = true
        coordinator.beginRowHeaderSelection(at: row, modifiers: event.modifierFlags)
    }

    override func rightMouseDown(with event: NSEvent) {
        mouseDown(with: event)
        if let tableView = coordinator?.currentTableView {
            tableView.rightMouseDown(with: event)
        } else {
            super.rightMouseDown(with: event)
        }
    }

    override func otherMouseDown(with event: NSEvent) {
        mouseDown(with: event)
        super.otherMouseDown(with: event)
    }

Echo/Sources/UI/Results/QueryResultsTableView.swift:6:struct QueryResultsTableView: NSViewRepresentable {
Echo/Sources/UI/Results/QueryResultsTableView.swift:80:        private var parent: QueryResultsTableView
Echo/Sources/UI/Results/QueryResultsTableView.swift:92:        private var selectionAnchor: QueryResultsTableView.SelectedCell?
Echo/Sources/UI/Results/QueryResultsTableView.swift:95:        private var selectionFocus: QueryResultsTableView.SelectedCell?
Echo/Sources/UI/Results/QueryResultsTableView.swift:112:        init(_ parent: QueryResultsTableView, clipboardHistory: ClipboardHistoryStore) {
Echo/Sources/UI/Results/QueryResultsTableView.swift:121:            var start: QueryResultsTableView.SelectedCell
Echo/Sources/UI/Results/QueryResultsTableView.swift:122:            var end: QueryResultsTableView.SelectedCell
Echo/Sources/UI/Results/QueryResultsTableView.swift:136:            func contains(_ cell: QueryResultsTableView.SelectedCell) -> Bool {
Echo/Sources/UI/Results/QueryResultsTableView.swift:176:        func update(parent: QueryResultsTableView, tableView: NSTableView) {
Echo/Sources/UI/Results/QueryResultsTableView.swift:394:            let cellSelection = QueryResultsTableView.SelectedCell(row: row, column: dataIndex)
Echo/Sources/UI/Results/QueryResultsTableView.swift:464:                let cell = QueryResultsTableView.SelectedCell(row: row, column: clickedColumn)
Echo/Sources/UI/Results/QueryResultsTableView.swift:475:                    let cell = QueryResultsTableView.SelectedCell(row: row, column: column)
Echo/Sources/UI/Results/QueryResultsTableView.swift:829:                let seed = QueryResultsTableView.SelectedCell(
Echo/Sources/UI/Results/QueryResultsTableView.swift:871:            focus = QueryResultsTableView.SelectedCell(row: targetRow, column: targetColumn)
Echo/Sources/UI/Results/QueryResultsTableView.swift:873:            let anchor: QueryResultsTableView.SelectedCell
Echo/Sources/UI/Results/QueryResultsTableView.swift:889:        private func resolvedCell(forRow row: Int, column: Int, tableView: NSTableView) -> QueryResultsTableView.SelectedCell? {
Echo/Sources/UI/Results/QueryResultsTableView.swift:895:            return QueryResultsTableView.SelectedCell(row: visibleRow, column: dataColumn)
Echo/Sources/UI/Results/QueryResultsTableView.swift:898:        private func resolvedCell(at point: NSPoint, in tableView: NSTableView, allowOutOfBounds: Bool) -> QueryResultsTableView.SelectedCell? {
Echo/Sources/UI/Results/QueryResultsTableView.swift:1112:            let top = QueryResultsTableView.SelectedCell(row: 0, column: lower)
Echo/Sources/UI/Results/QueryResultsTableView.swift:1113:            let bottom = QueryResultsTableView.SelectedCell(row: maxRow, column: upper)
Echo/Sources/UI/Results/QueryResultsTableView.swift:1205:    weak var selectionDelegate: QueryResultsTableView.Coordinator?
Echo/Sources/UI/Results/QueryResultsTableView.swift:1274:    weak var coordinator: QueryResultsTableView.Coordinator?
Echo/Sources/UI/Results/QueryResultsTableView.swift:1277:    init(coordinator: QueryResultsTableView.Coordinator?) {
Echo/Sources/UI/Results/QueryResultsTableView.swift:1330:    weak var coordinator: QueryResultsTableView.Coordinator?
Echo/Sources/UI/Results/QueryResultsTableView.swift:1339:    init(coordinator: QueryResultsTableView.Coordinator, scrollView: NSScrollView, width: CGFloat) {
Echo/Sources/UI/Workspace/Tabs/QueryTabsView.swift:708:                    QueryResultsSection(
Echo/Sources/UI/Results/QueryResultsSection.swift:8:struct QueryResultsSection: View {
Echo/Sources/UI/Results/QueryResultsSection.swift:266:                QueryResultsTableView(
Echo/Sources/UI/Results/QueryResultsSection.swift:281:    private func handleSortAction(columnIndex: Int, action: QueryResultsTableView.HeaderSortAction) {

Echo/Sources/UI/Results/QueryResultsTableView.swift:231:                let maxColumn = parent.query.displayedColumns.count
Echo/Sources/UI/Results/QueryResultsTableView.swift:255:            let columnIDs = parent.query.displayedColumns.map(\.id)
Echo/Sources/UI/Results/QueryResultsTableView.swift:260:                debugLog("Reload columns: changed count=\(parent.query.displayedColumns.count)")
Echo/Sources/UI/Results/QueryResultsTableView.swift:270:                for (offset, column) in parent.query.displayedColumns.enumerated() {
Echo/Sources/UI/Results/QueryResultsTableView.swift:302:               let columnIndex = parent.query.displayedColumns.firstIndex(where: { $0.name == sort.column }) {
Echo/Sources/UI/Results/QueryResultsTableView.swift:324:            for (index, column) in parent.query.displayedColumns.enumerated() {
Echo/Sources/UI/Results/QueryResultsTableView.swift:373:                    debugLog("cell[\(row),\(dataIndex)]='\(value)' (displayColumns=\(parent.query.displayedColumns.count))")
Echo/Sources/UI/Results/QueryResultsTableView.swift:375:            } else if parent.query.displayedColumns.indices.contains(dataIndex) {
Echo/Sources/UI/Results/QueryResultsTableView.swift:523:                      dataIndex < parent.query.displayedColumns.count else { return }
Echo/Sources/UI/Results/QueryResultsTableView.swift:530:                   sort.column == parent.query.displayedColumns[dataIndex].name,
Echo/Sources/UI/Results/QueryResultsTableView.swift:539:                   sort.column == parent.query.displayedColumns[dataIndex].name,
Echo/Sources/UI/Results/QueryResultsTableView.swift:602:            let columnCount = parent.query.displayedColumns.count
Echo/Sources/UI/Results/QueryResultsTableView.swift:639:                let columnCount = parent.query.displayedColumns.count
Echo/Sources/UI/Results/QueryResultsTableView.swift:667:            let columns = parent.query.displayedColumns
Echo/Sources/UI/Results/QueryResultsTableView.swift:894:            guard dataColumn < parent.query.displayedColumns.count else { return nil }
Echo/Sources/UI/Results/QueryResultsTableView.swift:1065:            let columnCount = parent.query.displayedColumns.count
Echo/Sources/UI/Results/QueryResultsTableView.swift:1083:            let columnCount = parent.query.displayedColumns.count
Echo/Sources/UI/Results/QueryResultsTableView.swift:1097:            let columnCount = parent.query.displayedColumns.count
Echo/Sources/UI/Results/QueryResultsSection.swift:986:        query.displayedColumns
Echo/Sources/Domain/Tabs/WorkspaceTab.swift:340:    var displayedColumns: [ColumnInfo] {

        #endif
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
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        selectionDelegate?.handleMouseDragged(event, in: self)
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

Echo/Sources/UI/Editor/SQLEditorView.swift:1059:private struct MacSQLEditorRepresentable: NSViewRepresentable {
Echo/Sources/UI/Editor/SQLEditorView.swift:3285:private struct GlassBackground: NSViewRepresentable {
Echo/Sources/UI/Results/QueryResultsTableView.swift:6:struct QueryResultsTableView: NSViewRepresentable {
Echo/Sources/UI/Workspace/Tabs/QueryTabsView.swift:1916:    private struct KeyCaptureView: NSViewRepresentable {
Echo/Sources/UI/Workspace/Tabs/QueryTabsView.swift:2414:private struct MiddleClickCapture: NSViewRepresentable {

            reloadIndexColumn(for: tableView)
        }
    }
}

final class ResultTableContainerView: NSView {
    let scrollView: NSScrollView
    let overlay: RowIndexOverlayView

    init(scrollView: NSScrollView, overlay: RowIndexOverlayView) {
        self.scrollView = scrollView
        self.overlay = overlay
        super.init(frame: .zero)

        wantsLayer = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        overlay.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)
        addSubview(overlay)

        overlay.layer?.zPosition = 1

        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlay.topAnchor.constraint(equalTo: topAnchor),
            overlay.bottomAnchor.constraint(equalTo: bottomAnchor),
            overlay.widthAnchor.constraint(equalToConstant: overlay.width),

            scrollView.leadingAnchor.constraint(equalTo: overlay.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var tableView: NSTableView? {
        scrollView.documentView as? NSTableView
    }

    func updateBackgroundColor(_ color: NSColor) {
        wantsLayer = true
        layer?.backgroundColor = color.cgColor
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.contentView.backgroundColor = .clear
        overlay.updateBackgroundColor(color)
    }

    override func layout() {
        super.layout()
        #if DEBUG
        let tableFrame = tableView?.frame ?? .zero
        print("[GridDebug] Container layout -> frame=\(frame) scrollFrame=\(scrollView.frame) overlayFrame=\(overlay.frame) tableFrame=\(tableFrame)")
        print("[GridDebug] Container subviews -> \(subviews.map { type(of: $0) })")
        #endif
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
        super.mouseDown(with: event)
    }


## master...origin/master
?? Echo/Sources/UI/Results/QueryResultsTableView.swift

  1130	            #if DEBUG
  1131	            let scrollBounds = scrollView.bounds
  1132	            let contentViewFrame = scrollView.contentView.frame
  1133	            let visibleRect = tableView.visibleRect
  1134	            debugLog("adjustTableSize -> tableFrame=\(tableView.frame) scrollFrame=\(scrollView.frame) scrollBounds=\(scrollBounds) contentViewFrame=\(contentViewFrame) contentSize=\(scrollView.contentSize) tableVisibleRect=\(visibleRect)")
  1135	            #endif
  1136	        }
  1137	
  1138	        @objc private func contentViewDidScroll(_ notification: Notification) {
  1139	            guard let tableView else { return }
  1140	            reloadIndexColumn(for: tableView)
  1141	        }
  1142	    }
  1143	}
  1144	
  1145	final class ResultTableContainerView: NSView {
  1146	    let scrollView: NSScrollView
  1147	    let overlay: RowIndexOverlayView
  1148	
  1149	    init(scrollView: NSScrollView, overlay: RowIndexOverlayView) {
  1150	        self.scrollView = scrollView
  1151	        self.overlay = overlay
  1152	        super.init(frame: .zero)
  1153	
  1154	        wantsLayer = true
  1155	        scrollView.autoresizingMask = [.width, .height]
  1156	        overlay.autoresizingMask = [.height]
  1157	
  1158	        addSubview(scrollView)
  1159	        addSubview(overlay)
  1160	
  1161	        overlay.layer?.zPosition = 1
  1162	    }
  1163	
  1164	    required init?(coder: NSCoder) {
  1165	        fatalError("init(coder:) has not been implemented")
  1166	    }
  1167	
  1168	    var tableView: NSTableView? {
  1169	        scrollView.documentView as? NSTableView
  1170	    }
  1171	
  1172	    func updateBackgroundColor(_ color: NSColor) {
  1173	        wantsLayer = true
  1174	        layer?.backgroundColor = color.cgColor
  1175	        scrollView.backgroundColor = .clear
  1176	        scrollView.drawsBackground = false
  1177	        scrollView.contentView.drawsBackground = false
  1178	        scrollView.contentView.backgroundColor = .clear
  1179	        overlay.updateBackgroundColor(color)
  1180	    }
  1181	
  1182	    override func layout() {
  1183	        super.layout()
  1184	        let overlayWidth = max(0, overlay.width)
  1185	        overlay.frame = NSRect(x: 0, y: 0, width: overlayWidth, height: bounds.height)
  1186	        let scrollOriginX = overlayWidth
  1187	        let scrollWidth = max(bounds.width - scrollOriginX, 0)
  1188	        scrollView.frame = NSRect(x: scrollOriginX, y: 0, width: scrollWidth, height: bounds.height)
  1189	        #if DEBUG
  1190	        let tableFrame = tableView?.frame ?? .zero

Success. Updated the following files:
M Echo/Sources/UI/Results/QueryResultsTableView.swift

160:        func configure(tableView: NSTableView, scrollView: NSScrollView, overlay: RowIndexOverlayView) {

            }
            #if DEBUG
            let scrollBounds = scrollView.bounds
            let contentViewFrame = scrollView.contentView.frame
            let visibleRect = tableView.visibleRect
            debugLog("adjustTableSize -> tableFrame=\(tableView.frame) scrollFrame=\(scrollView.frame) scrollBounds=\(scrollBounds) contentViewFrame=\(contentViewFrame) contentSize=\(scrollView.contentSize) tableVisibleRect=\(visibleRect)")
            #endif
        }

        @objc private func contentViewDidScroll(_ notification: Notification) {
            guard let tableView else { return }
            reloadIndexColumn(for: tableView)
        }
    }
}

final class ResultTableContainerView: NSView {
    let scrollView: NSScrollView
    let overlay: RowIndexOverlayView

    init(scrollView: NSScrollView, overlay: RowIndexOverlayView) {
        self.scrollView = scrollView
        self.overlay = overlay
        super.init(frame: .zero)

        wantsLayer = true
        addSubview(scrollView)
        addSubview(overlay)

        overlay.layer?.zPosition = 1
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var tableView: NSTableView? {
        scrollView.documentView as? NSTableView
    }

    func updateBackgroundColor(_ color: NSColor) {
        wantsLayer = true
        layer?.backgroundColor = color.cgColor
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.contentView.backgroundColor = .clear
        overlay.updateBackgroundColor(color)
    }

    override func layout() {
        super.layout()
        layoutChildren()
        #if DEBUG
        let tableFrame = tableView?.frame ?? .zero
        print("[GridDebug] Container layout -> frame=\(frame) scrollFrame=\(scrollView.frame) overlayFrame=\(overlay.frame) tableFrame=\(tableFrame)")
        print("[GridDebug] Container subviews -> \(subviews.map { type(of: $0) })")
        #endif
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        layoutChildren()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutChildren()
    }

    override func setBoundsSize(_ newSize: NSSize) {
        super.setBoundsSize(newSize)
        layoutChildren()
    }

    private func layoutChildren() {
        guard scrollView.superview === self, overlay.superview === self else { return }
        let overlayWidth = max(0, min(overlay.width, bounds.width))
        overlay.frame = NSRect(x: 0, y: 0, width: overlayWidth, height: bounds.height)
        let scrollOriginX = overlayWidth
        let scrollWidth = max(bounds.width - scrollOriginX, 0)
        scrollView.frame = NSRect(x: scrollOriginX, y: 0, width: scrollWidth, height: bounds.height)
        if let tableView = tableView {
            let columnWidth = tableView.tableColumns.reduce(0.0) { $0 + Double($1.width) }
            let targetWidth = max(CGFloat(columnWidth), scrollView.bounds.width)
            let headerHeight = tableView.headerView?.frame.height ?? 0
            let rowCount = max(tableView.numberOfRows, 0)
            let contentHeight = max(CGFloat(rowCount) * tableView.rowHeight + headerHeight, scrollView.bounds.height)
            let newSize = NSSize(width: targetWidth, height: contentHeight)
            if tableView.frame.size != newSize {
                tableView.setFrameSize(newSize)
            }
        }
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
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        selectionDelegate?.handleMouseDragged(event, in: self)
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        selectionDelegate?.handleMouseUp(event, in: self)
        super.mouseUp(with: event)

1315:private final class ResultTableHeaderView: NSTableHeaderView {


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


105:        private var rowIndexOverlay: RowIndexOverlayView?
175:            rowIndexOverlay = overlay
253:            rowIndexOverlay?.refresh()
299:            rowIndexOverlay?.refresh()
1005:            rowIndexOverlay?.refresh()

final class ResultTableContainerView: NSView {
    let scrollView: NSScrollView
    private var overlay: RowIndexOverlayView?
    private let overlayWidth: CGFloat

    init(scrollView: NSScrollView, overlay: RowIndexOverlayView?, overlayWidth: CGFloat) {
        self.scrollView = scrollView
        self.overlay = overlay
        self.overlayWidth = overlayWidth
        super.init(frame: .zero)

        wantsLayer = true
        addSubview(scrollView)

        if let overlay {
            addSubview(overlay)
            overlay.layer?.zPosition = 1
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var tableView: NSTableView? {
        scrollView.documentView as? NSTableView
    }

    func updateBackgroundColor(_ color: NSColor) {
        wantsLayer = true
        layer?.backgroundColor = color.cgColor
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.contentView.backgroundColor = .clear
        overlay?.updateBackgroundColor(color)
    }

    override func layout() {
        super.layout()
        layoutChildren()
        #if DEBUG
        let tableFrame = tableView?.frame ?? .zero
        let overlayFrame = overlay?.frame ?? .zero
        print("[GridDebug] Container layout -> frame=\(frame) scrollFrame=\(scrollView.frame) overlayFrame=\(overlayFrame) tableFrame=\(tableFrame)")
        print("[GridDebug] Container subviews -> \(subviews.map { type(of: $0) })")


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

        func configure(tableView: NSTableView, scrollView: NSScrollView, overlay: RowIndexOverlayView?) {
            self.tableView = tableView
            self.scrollView = scrollView
            tableView.delegate = self
            tableView.dataSource = self
            tableView.menu = cellMenu
            if let header = tableView.headerView as? ResultTableHeaderView {
                header.coordinator = self
                header.menu = headerMenu
            } else {
                tableView.headerView?.menu = headerMenu
            }
            tableView.selectionHighlightStyle = .regular
            _ = reloadColumns()

            rowIndexOverlay = overlay
            overlay?.refresh()

            scrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(contentViewDidScroll(_:)),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
        }


    20	    struct SelectedCell: Equatable {
    21	        let row: Int
    22	        let column: Int
    23	    }
    24	
    25	    enum HeaderSortAction {
    26	        case ascending
    27	        case descending
    28	        case clear
    29	    }
    30	
    31	    func makeCoordinator() -> Coordinator {
    32	        Coordinator(self, clipboardHistory: clipboardHistory)
    33	    }
    34	
    35	    func makeNSView(context: Context) -> ResultTableContainerView {
    36	        let scrollView = NSScrollView()
    37	        scrollView.hasVerticalScroller = true
    38	        scrollView.hasHorizontalScroller = true
    39	        scrollView.autohidesScrollers = true
    40	        scrollView.drawsBackground = false
    41	        if #available(macOS 13.0, *) {
    42	            scrollView.automaticallyAdjustsContentInsets = false
    43	        }
    44	
    45	        let tableView = ResultTableView()
    46	        tableView.usesAlternatingRowBackgroundColors = ThemeManager.shared.showAlternateRowShading
    47	        tableView.rowHeight = 24
    48	        tableView.headerView = ResultTableHeaderView(coordinator: context.coordinator)
    49	        tableView.gridStyleMask = []
    50	        tableView.columnAutoresizingStyle = .noColumnAutoresizing
    51	        tableView.allowsMultipleSelection = true
    52	        tableView.allowsColumnSelection = false
    53	        tableView.autoresizingMask = [.width, .height]
    54	        tableView.backgroundColor = backgroundColor
    55	#if DEBUG
    56	        tableView.layer?.backgroundColor = backgroundColor.cgColor
    57	#endif
    58	        if #available(macOS 13.0, *) {
    59	            tableView.style = .inset
    60	        }
    61	
    62	        let overlay: RowIndexOverlayView?
    63	        if enableRowIndexOverlay {
    64	            overlay = RowIndexOverlayView(coordinator: context.coordinator, scrollView: scrollView, width: rowIndexWidth)
    65	        } else {
    66	            overlay = nil
    67	        }
    68	        let container = ResultTableContainerView(
    69	            scrollView: scrollView,
    70	            overlay: overlay,
    71	            overlayWidth: enableRowIndexOverlay ? rowIndexWidth : 0
    72	        )
    73	
    74	        if let headerView = tableView.headerView {
    75	            scrollView.headerView = headerView
    76	        }
    77	
    78	        context.coordinator.configure(tableView: tableView, scrollView: scrollView, overlay: overlay)
    79	        tableView.selectionDelegate = context.coordinator
    80	        scrollView.documentView = tableView
    81	        container.updateBackgroundColor(backgroundColor)
    82	        overlay?.refresh()
    83	        return container
    84	    }
    85	
    86	    func updateNSView(_ nsView: ResultTableContainerView, context: Context) {
    87	        guard let tableView = nsView.tableView else { return }
    88	        tableView.backgroundColor = backgroundColor
    89	        tableView.usesAlternatingRowBackgroundColors = ThemeManager.shared.showAlternateRowShading
    90	        nsView.updateBackgroundColor(backgroundColor)
    91	        context.coordinator.update(parent: self, tableView: tableView)
    92	    }
    93	
    94	    final class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource, NSMenuDelegate {
    95	        private var parent: QueryResultsTableView
    96	        private let clipboardHistory: ClipboardHistoryStore
    97	        private weak var tableView: NSTableView?
    98	        private weak var scrollView: NSScrollView?
    99	        private let headerMenu = NSMenu()
   100	        private let cellMenu = NSMenu()
   101	        private var menuColumnIndex: Int?
   102	        private var cachedColumnIDs: [String] = []
   103	        private var cachedRowOrder: [Int] = []
   104	        private var cachedSort: SortCriteria?
   105	        private var lastRowCount: Int = 0
   106	        private var selectionRegion: SelectedRegion?
   107	        private var selectionAnchor: QueryResultsTableView.SelectedCell?
   108	        private var isDraggingCellSelection = false
   109	        private var rowIndexOverlay: RowIndexOverlayView?
   110	        private var selectionFocus: QueryResultsTableView.SelectedCell?
   111	        private var rowSelectionAnchor: Int?
   112	        private var columnSelectionAnchor: Int?
   113	
   114	        var currentTableView: NSTableView? { tableView }
   115	
   116	#if DEBUG
   117	        private var debugLogEmissionCount = 0
   118	        private func debugLog(_ message: String) {
   119	            guard debugLogEmissionCount < 200 else { return }
   120	            debugLogEmissionCount += 1
