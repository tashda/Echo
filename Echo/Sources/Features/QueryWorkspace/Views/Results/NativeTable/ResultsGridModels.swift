import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension QueryResultsTableView {
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
        case requestMetadata(columnIndex: Int, columnName: String)
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
}

enum ResultExportFormat: String, CaseIterable {
    case tsv
    case csv
    case json
    case sqlInsert
    case markdown

    var menuTitle: String {
        switch self {
        case .tsv: return "Tab-Separated (TSV)"
        case .csv: return "CSV"
        case .json: return "JSON"
        case .sqlInsert: return "SQL INSERT"
        case .markdown: return "Markdown"
        }
    }

    var fileExtension: String {
        switch self {
        case .tsv: return "tsv"
        case .csv: return "csv"
        case .json: return "json"
        case .sqlInsert: return "sql"
        case .markdown: return "md"
        }
    }

#if os(macOS)
    var contentTypes: [UTType] {
        switch self {
        case .tsv: return [.tabSeparatedText]
        case .csv: return [.commaSeparatedText]
        case .json: return [.json]
        case .sqlInsert: return [UTType(filenameExtension: "sql") ?? .plainText]
        case .markdown: return [UTType(filenameExtension: "md") ?? .plainText]
        }
    }
#endif
}

struct SelectedRegion: Equatable {
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
