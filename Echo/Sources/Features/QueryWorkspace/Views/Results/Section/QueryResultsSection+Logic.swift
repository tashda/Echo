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

        let column = tableColumns[columnIndex]
        let indices = Array(0..<count)
        rowOrder = indices.sorted { lhs, rhs in
            let result = compare(rowIndex: lhs, otherRowIndex: rhs, columnIndex: columnIndex, column: column)
            return sort.ascending ? result == .orderedAscending : result == .orderedDescending
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

    internal func compare(rowIndex lhs: Int, otherRowIndex rhs: Int, columnIndex: Int, column: ColumnInfo) -> ComparisonResult {
        let left = rowValue(at: lhs, columnIndex: columnIndex)
        let right = rowValue(at: rhs, columnIndex: columnIndex)
        return compare(left, right, column: column)
    }

    internal func compare(_ lhs: String?, _ rhs: String?, column: ColumnInfo) -> ComparisonResult {
        if lhs == rhs { return .orderedSame }
        if lhs == nil { return .orderedDescending }
        if rhs == nil { return .orderedAscending }

        guard let lhs, let rhs else { return .orderedSame }

        let trimmedLeft = lhs.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRight = rhs.trimmingCharacters(in: .whitespacesAndNewlines)
        let type = column.dataType.lowercased()

        if isNumericType(type),
           let leftNumber = Decimal(string: trimmedLeft),
           let rightNumber = Decimal(string: trimmedRight) {
            if leftNumber == rightNumber { return .orderedSame }
            return leftNumber < rightNumber ? .orderedAscending : .orderedDescending
        }

        if type.contains("bool"),
           let leftBool = parseBool(trimmedLeft),
           let rightBool = parseBool(trimmedRight) {
            if leftBool == rightBool { return .orderedSame }
            return leftBool ? .orderedDescending : .orderedAscending
        }

        return trimmedLeft.caseInsensitiveCompare(trimmedRight)
    }

    private func isNumericType(_ type: String) -> Bool {
        type.contains("int") ||
        type.contains("serial") ||
        type.contains("numeric") ||
        type.contains("decimal") ||
        type.contains("float") ||
        type.contains("double") ||
        type.contains("money")
    }

    private func parseBool(_ value: String) -> Bool? {
        switch value.lowercased() {
        case "true", "t", "1", "yes", "y":
            return true
        case "false", "f", "0", "no", "n":
            return false
        default:
            return nil
        }
    }
}
