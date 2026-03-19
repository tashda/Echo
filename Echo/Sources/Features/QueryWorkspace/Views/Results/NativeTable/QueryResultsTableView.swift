#if os(macOS)
import SwiftUI
import AppKit

struct QueryResultsTableView: NSViewRepresentable {
    @Bindable var query: QueryEditorState
    var highlightedColumnIndex: Int?
    var activeSort: SortCriteria?
    var rowOrder: [Int]
    var onColumnTap: (Int) -> Void
    var onSort: (Int, HeaderSortAction) -> Void
    var onClearColumnHighlight: () -> Void
    var backgroundColor: NSColor
    var onForeignKeyEvent: (ForeignKeyEvent) -> Void
    var onJsonEvent: (JsonCellEvent) -> Void
    var onCellInspect: ((CellValueInspectorContent) -> Void)?
    var persistedState: QueryResultsGridState?
    var isResizing: Bool = false
    var alternateRowShading: Bool = false
    var showRowNumbers: Bool = true
    var colorOverrides: ResultGridColorOverrides = .init()

    @Environment(EnvironmentState.self) private var environmentState
    @Environment(ClipboardHistoryStore.self) private var clipboardHistory

    func makeCoordinator() -> Coordinator {
        Coordinator(self, clipboardHistory: clipboardHistory, persistedState: persistedState)
    }

    func makeNSView(context: Context) -> ResultTableContainerView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false

        let tableView = ResultTableView()
        tableView.usesAlternatingRowBackgroundColors = alternateRowShading
        tableView.rowHeight = 24
        tableView.headerView = ResultTableHeaderView(coordinator: context.coordinator)
        tableView.gridStyleMask = []
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        tableView.allowsColumnReordering = false
        tableView.allowsMultipleSelection = true
        tableView.allowsColumnSelection = false
        tableView.autoresizingMask = [.width]
        tableView.backgroundColor = backgroundColor

        if let headerView = tableView.headerView {
            headerView.frame.size.height = max(headerView.frame.size.height, 28)
            headerView.isHidden = false
        }

        context.coordinator.configure(tableView: tableView, scrollView: scrollView)
        tableView.selectionDelegate = context.coordinator
        scrollView.documentView = tableView

        let container = ResultTableContainerView(scrollView: scrollView, showRowNumbers: showRowNumbers)
        container.updateBackgroundColor(backgroundColor)
        let rowCount = rowOrder.isEmpty ? query.displayedRowCount : rowOrder.count
        container.updateRowNumbers(count: rowCount)
        let coordinator = context.coordinator
        container.setRowNumberCallbacks(
            onSelect: { [weak coordinator] row in coordinator?.selectFullRow(row) },
            onExtendSelect: { [weak coordinator] row in coordinator?.extendRowSelection(to: row) }
        )
        return container
    }

    func updateNSView(_ container: ResultTableContainerView, context: Context) {
        guard let tableView = container.tableView else { return }
        context.coordinator.isSplitResizing = isResizing
        if isResizing {
            context.coordinator.parent = self
            return
        }
        context.coordinator.updatePersistedState(persistedState)
        tableView.backgroundColor = backgroundColor
        if tableView.usesAlternatingRowBackgroundColors != alternateRowShading {
            tableView.usesAlternatingRowBackgroundColors = alternateRowShading
            let visibleRows = tableView.rows(in: tableView.visibleRect)
            for row in visibleRows.location..<(visibleRows.location + visibleRows.length) {
                tableView.rowView(atRow: row, makeIfNecessary: false)?.needsDisplay = true
            }
            tableView.needsDisplay = true
        }
        container.updateShowRowNumbers(showRowNumbers)
        let rowCount = rowOrder.isEmpty ? query.displayedRowCount : rowOrder.count
        container.updateRowNumbers(count: rowCount)
        container.updateBackgroundColor(backgroundColor)
        context.coordinator.update(parent: self, tableView: tableView)
    }
}
#endif
