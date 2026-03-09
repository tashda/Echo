import Foundation

extension QueryEditorState {
    func updateForeignKeyResolutionContext(schema: String?, table: String?) {
        if let schema, let table {
            foreignKeyContext = ForeignKeyResolutionContext(schema: schema, table: table)
        } else {
            foreignKeyContext = nil
        }
        cachedForeignKeyMapping = [:]
        hasLoadedForeignKeyMapping = false
        isLoadingForeignKeyMapping = false
    }

    func foreignKeyReference(for columnName: String) -> ColumnInfo.ForeignKeyReference? {
        cachedForeignKeyMapping[columnName.lowercased()]
    }

    func beginForeignKeyMappingFetch() -> (schema: String, table: String)? {
        guard let context = foreignKeyContext else { return nil }
        guard !hasLoadedForeignKeyMapping else { return nil }
        if isLoadingForeignKeyMapping {
            return nil
        }
        isLoadingForeignKeyMapping = true
        return (context.schema, context.table)
    }

    func completeForeignKeyMappingFetch(with mapping: ForeignKeyMapping) {
        cachedForeignKeyMapping = mapping
        hasLoadedForeignKeyMapping = true
        isLoadingForeignKeyMapping = false
        guard !mapping.isEmpty else { return }
        streamingColumns = applyForeignKeyMapping(to: streamingColumns, mapping: mapping)
        if var currentResults = results {
            currentResults.columns = applyForeignKeyMapping(to: currentResults.columns, mapping: mapping)
            results = currentResults
        }
        markResultDataChanged(force: true)
    }

    func failForeignKeyMappingFetch() {
        isLoadingForeignKeyMapping = false
    }

    private func applyForeignKeyMapping(to columns: [ColumnInfo], mapping: ForeignKeyMapping) -> [ColumnInfo] {
        guard !mapping.isEmpty else { return columns }
        return columns.map { column in
            var updated = column
            if updated.foreignKey == nil, let reference = mapping[column.name.lowercased()] {
                updated.foreignKey = reference
            }
            return updated
        }
    }
}
