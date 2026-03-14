import SwiftUI
import AppKit

struct AdditionalResultSetTableView: NSViewRepresentable {
    let resultSet: QueryResultSet
    let backgroundColor: NSColor
    let alternateRowShading: Bool
    let showRowNumbers: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = backgroundColor

        let tableView = NSTableView()
        tableView.style = .plain
        tableView.usesAlternatingRowBackgroundColors = alternateRowShading
        tableView.allowsColumnReordering = true
        tableView.allowsColumnResizing = true
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        tableView.intercellSpacing = NSSize(width: 8, height: 2)
        tableView.rowHeight = 22
        tableView.headerView = NSTableHeaderView()
        tableView.backgroundColor = backgroundColor
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator

        if showRowNumbers {
            let rowNumberColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("_rowNumber"))
            rowNumberColumn.title = "#"
            rowNumberColumn.width = 48
            rowNumberColumn.minWidth = 36
            rowNumberColumn.isEditable = false
            tableView.addTableColumn(rowNumberColumn)
        }

        for (index, column) in resultSet.columns.enumerated() {
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col_\(index)"))
            tableColumn.title = column.name
            tableColumn.width = estimateColumnWidth(column.name, rowCount: resultSet.rows.count, columnIndex: index)
            tableColumn.minWidth = 50
            tableColumn.isEditable = false
            tableView.addTableColumn(tableColumn)
        }

        scrollView.documentView = tableView
        context.coordinator.tableView = tableView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.resultSet = resultSet
        context.coordinator.showRowNumbers = showRowNumbers
        if let tableView = context.coordinator.tableView {
            tableView.usesAlternatingRowBackgroundColors = alternateRowShading
            tableView.reloadData()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(resultSet: resultSet, showRowNumbers: showRowNumbers)
    }

    private func estimateColumnWidth(_ name: String, rowCount: Int, columnIndex: Int) -> CGFloat {
        let headerWidth = CGFloat(name.count) * 8.0 + 24
        var maxDataWidth: CGFloat = 0
        let sampleCount = min(rowCount, 20)
        for i in 0..<sampleCount {
            if let value: String = resultSet.rows[i][safe: columnIndex] ?? nil {
                let dataWidth = CGFloat(value.prefix(100).count) * 7.5 + 16
                maxDataWidth = max(maxDataWidth, dataWidth)
            }
        }
        return min(max(headerWidth, maxDataWidth, 60), 400)
    }

    @MainActor final class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        var resultSet: QueryResultSet
        var showRowNumbers: Bool
        weak var tableView: NSTableView?

        init(resultSet: QueryResultSet, showRowNumbers: Bool) {
            self.resultSet = resultSet
            self.showRowNumbers = showRowNumbers
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            resultSet.rows.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let tableColumn else { return nil }

            if tableColumn.identifier.rawValue == "_rowNumber" {
                let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as? NSTextField
                    ?? makeTextField(identifier: tableColumn.identifier)
                cell.stringValue = "\(row + 1)"
                cell.textColor = .tertiaryLabelColor
                cell.alignment = .right
                return cell
            }

            let columnIdentifier = tableColumn.identifier.rawValue
            guard columnIdentifier.hasPrefix("col_"),
                  let columnIndex = Int(columnIdentifier.dropFirst(4)),
                  row < resultSet.rows.count,
                  columnIndex < resultSet.rows[row].count else {
                return nil
            }

            let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as? NSTextField
                ?? makeTextField(identifier: tableColumn.identifier)

            if let value = resultSet.rows[row][columnIndex] {
                cell.stringValue = value
                cell.textColor = .labelColor
            } else {
                cell.stringValue = "NULL"
                cell.textColor = .tertiaryLabelColor
            }
            return cell
        }

        private func makeTextField(identifier: NSUserInterfaceItemIdentifier) -> NSTextField {
            let field = NSTextField()
            field.identifier = identifier
            field.isEditable = false
            field.isBordered = false
            field.drawsBackground = false
            field.lineBreakMode = .byTruncatingTail
            field.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            return field
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
