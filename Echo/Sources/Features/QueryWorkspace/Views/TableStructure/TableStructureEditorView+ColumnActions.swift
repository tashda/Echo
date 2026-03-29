import SwiftUI

extension TableStructureEditorView {
    
    internal func removeColumns(_ columns: [TableStructureEditorViewModel.ColumnModel]) {
        guard !columns.isEmpty else { return }
        columns.forEach { column in
            viewModel.removeColumn(column)
        }
        pruneSelectedColumns()
    }

    internal func presentBulkEditor(mode: BulkColumnEditorPresentation.Mode, columns: [TableStructureEditorViewModel.ColumnModel]) {
        guard !columns.isEmpty else { return }
        activeSheet = .bulkColumn(BulkColumnEditorPresentation(mode: mode, columnIDs: columns.map(\.id)))
    }

    internal func pruneSelectedColumns() {
        let valid = Set(visibleColumns.map(\.id))
        selectedColumnIDs = selectedColumnIDs.intersection(valid)
    }

    internal func presentNewColumn() {
        let model = viewModel.addColumn()
        activeSheet = .column(ColumnEditorPresentation(columnID: model.id, isNew: true))
    }

    internal func presentColumnEditor(for column: TableStructureEditorViewModel.ColumnModel) {
        activeSheet = .column(ColumnEditorPresentation(columnID: column.id, isNew: column.isNew))
    }

    internal func columnChangeDescription(for column: TableStructureEditorViewModel.ColumnModel) -> String? {
        var parts: [String] = []

        if column.hasRename, let previous = column.original?.name {
            parts.append("Renamed from \(previous)")
        }
        if column.hasTypeChange, let previous = column.original?.dataType {
            parts.append("Type changed from \(previous)")
        }
        if column.hasNullabilityChange {
            parts.append(column.isNullable ? "Now allows NULL" : "Now disallows NULL")
        }
        if column.hasDefaultChange {
            let previous = (column.original?.defaultValue).flatMap({ $0.isEmpty ? nil : $0 }) ?? "None"
            let current = column.defaultValue.flatMap({ $0.isEmpty ? nil : $0 }) ?? "None"
            parts.append("Default: \(previous) \u{2192} \(current)")
        }
        if column.hasExpressionChange {
            parts.append("Generated expression updated")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " \u{2022} ")
    }
}
