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
        bulkColumnEditor = BulkColumnEditorPresentation(mode: mode, columnIDs: columns.map(\.id))
    }

    internal func pruneSelectedColumns() {
        let valid = Set(visibleColumns.map(\.id))
        selectedColumnIDs = selectedColumnIDs.intersection(valid)
        if let anchor = selectionAnchor, !valid.contains(anchor) {
            selectionAnchor = selectedColumnIDs.first
        }
    }

    internal func rebuildColumnIndexLookup() {
        columnIndexLookup = Dictionary(
            uniqueKeysWithValues: viewModel.columns.enumerated().map { pair in
                let (index, column) = pair
                return (column.id, index)
            }
        )
    }

    internal func presentNewColumn() {
        let model = viewModel.addColumn()
        activeColumnEditor = ColumnEditorPresentation(columnID: model.id, isNew: true)
    }

    internal func presentColumnEditor(for column: TableStructureEditorViewModel.ColumnModel) {
        activeColumnEditor = ColumnEditorPresentation(columnID: column.id, isNew: column.isNew)
    }

    internal func columnStatusMetadata(for column: TableStructureEditorViewModel.ColumnModel) -> (title: String, systemImage: String, tint: Color) {
        if column.isNew {
            return ("New", "sparkles", Color.accentColor)
        }
        if column.isDirty {
            return ("Modified", "paintbrush", Color.accentColor)
        }
        return ("Synced", "checkmark.circle", Color.secondary)
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
            let previous = column.original?.defaultValue?.isEmpty == false ? column.original!.defaultValue! : "None"
            let current = column.defaultValue?.isEmpty == false ? column.defaultValue! : "None"
            parts.append("Default: \(previous) → \(current)")
        }
        if column.hasExpressionChange {
            parts.append("Generated expression updated")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}
