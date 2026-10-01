import SwiftUI

extension QueryResultsSection {
    private var prefersMessagesAfterExecution: Bool {
        guard query.errorMessage == nil, !query.isExecuting else { return false }
        return query.prefersMessagesAfterExecution
    }
    
    internal func handleResultTokenChange() {
        let newIDs = tableColumns.map(\.id)
        if newIDs != lastObservedColumnIDs {
            lastObservedColumnIDs = newIDs
            sortCriteria = nil
            highlightedColumnIndex = nil
        }
        if prefersMessagesAfterExecution {
            panelState.selectedSegment = .messages
            if !panelState.isOpen { panelState.isOpen = true }
        } else if panelState.selectedSegment == .messages, query.errorMessage == nil {
            panelState.selectedSegment = .results
        }
        rebuildRowOrder()
    }

    internal func handleExecutionStateChange(isExecuting: Bool) {
        if isExecuting {
            sortCriteria = nil
            highlightedColumnIndex = nil
            rowOrder = []
            if panelState.selectedSegment == .messages {
                panelState.selectedSegment = .results
            }
        } else {
            if prefersMessagesAfterExecution {
                panelState.selectedSegment = .messages
                if !panelState.isOpen { panelState.isOpen = true }
            }
        }
    }

    internal func rebuildRowOrder() {
        sortTask?.cancel()
        sortTask = nil
        let count = query.displayedRowCount
        guard count > 0 else {
            rowOrder = []
            return
        }

        guard let sort = activeSort,
              let columnIndex = tableColumns.firstIndex(where: { $0.name == sort.column }) else {
            rowOrder = []
            return
        }

        // Each row's value once; the keys and the sort itself are `ResultRowSorter`'s. A big result
        // is sorted off the main thread, so the window keeps answering while it works.
        let dataType = tableColumns[columnIndex].dataType
        let values = (0..<count).map { rowValue(at: $0, columnIndex: columnIndex) }
        if count <= ResultRowSorter.immediateLimit {
            rowOrder = ResultRowSorter.order(keys: ResultRowSorter.keys(for: values, dataType: dataType), ascending: sort.ascending)
            return
        }
        sortTask = Task(name: "results-sort") {
            let order = await ResultRowSorter.sortedOrder(values: values, dataType: dataType, ascending: sort.ascending)
            guard !Task.isCancelled else { return }
            rowOrder = order
        }
    }

    internal func toggleHighlightedColumn(_ index: Int) {
        if highlightedColumnIndex == index {
            highlightedColumnIndex = nil
        } else {
            highlightedColumnIndex = index
        }
        rebuildRowOrder()
    }

    internal func applySort(column: ColumnInfo, ascending: Bool) {
        sortCriteria = SortCriteria(column: column.name, ascending: ascending)
        if let index = tableColumns.firstIndex(where: { $0.id == column.id }) {
            highlightedColumnIndex = index
        }
        rebuildRowOrder()
    }

    internal func statusBubbleConfiguration() -> (label: String, icon: String, tint: Color) {
        if query.isExecuting {
            return ("Executing", "bolt.fill", .orange)
        }
        if query.wasCancelled {
            return ("Cancelled", "stop.fill", .yellow)
        }
        if let error = query.errorMessage, !error.isEmpty {
            return ("Error", "exclamationmark.triangle.fill", .red)
        }
        if query.hasExecutedAtLeastOnce {
            return ("Completed", "checkmark.circle.fill", .green)
        }
        return ("Ready", "clock", .secondary)
    }

    internal func formatCompact(_ value: Int) -> String {
        EchoFormatters.compactNumber(value)
    }

    internal func formattedDuration(_ seconds: Int) -> String {
        EchoFormatters.duration(seconds: seconds)
    }

    internal func rowValue(at rowIndex: Int, columnIndex: Int) -> String? {
        query.valueForDisplay(row: rowIndex, column: columnIndex)
    }
}
