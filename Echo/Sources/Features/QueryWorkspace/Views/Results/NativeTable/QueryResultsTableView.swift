#if os(macOS)
import SwiftUI
import AppKit

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
    var isResizing: Bool = false
    var alternateRowShading: Bool = false

    @EnvironmentObject private var environmentState: EnvironmentState
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore

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
        
        let container = ResultTableContainerView(scrollView: scrollView, leadingWidth: 0.0)
        container.updateBackgroundColor(backgroundColor)
        return container
    }

    func updateNSView(_ container: ResultTableContainerView, context: Context) {
        guard let tableView = container.tableView else { return }
        // Update the resize flag on coordinator directly — skip expensive work during resize
        context.coordinator.isSplitResizing = isResizing
        if isResizing {
            // During split-pane resize, only update the parent reference — skip all table work
            context.coordinator.parent = self
            return
        }
        context.coordinator.updatePersistedState(persistedState)
        tableView.backgroundColor = backgroundColor
        tableView.usesAlternatingRowBackgroundColors = alternateRowShading
        container.updateLeadingWidth(0.0)
        container.updateBackgroundColor(backgroundColor)
        context.coordinator.update(parent: self, tableView: tableView)
    }
}
#endif
