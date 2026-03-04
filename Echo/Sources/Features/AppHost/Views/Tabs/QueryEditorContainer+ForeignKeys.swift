import SwiftUI
import EchoSense
#if os(macOS)
import AppKit
#endif

internal typealias ForeignKeyMapping = [String: ColumnInfo.ForeignKeyReference]

extension QueryEditorContainer {
#if os(macOS)
    internal func handleForeignKeyEvent(_ event: QueryResultsTableView.ForeignKeyEvent) {
        switch event {
        case .selectionChanged(let selection):
            latestForeignKeySelection = selection
            if selection != nil {
                latestJsonSelection = nil
            }
            if let selection {
                if shouldAutoActivate(for: selection, triggeredByIcon: false) {
                    performForeignKeyActivation(for: selection)
                } else {
                    if foreignKeyDisplayMode == .showInspector,
                       foreignKeyInspectorBehavior == .respectInspectorVisibility,
                       !appState.showInfoSidebar {
                        if case .foreignKey = environmentState.dataInspectorContent {
                            environmentState.dataInspectorContent = nil
                        }
                    }
                }
            } else {
                foreignKeyFetchTask?.cancel()
                foreignKeyFetchTask = nil
                if case .foreignKey = environmentState.dataInspectorContent {
                    environmentState.dataInspectorContent = nil
                }
                if foreignKeyInspectorBehavior == .autoOpenAndClose && autoOpenedInspector {
                    autoOpenedInspector = false
                    if appState.showInfoSidebar {
                        appState.showInfoSidebar = false
                    }
                }
            }
        case .requestMetadata:
            guard foreignKeyDisplayMode != .disabled else { return }
            guard let context = query.beginForeignKeyMappingFetch() else { return }
            Task(priority: .utility) {
                let mapping = await loadForeignKeyMapping(schema: context.schema, table: context.table)
                await MainActor.run {
                    if Task.isCancelled {
                        query.failForeignKeyMappingFetch()
                    } else {
                        query.completeForeignKeyMappingFetch(with: mapping)
                    }
                }
            }

        case .activate(let selection):
            performForeignKeyActivation(for: selection)
        }
    }

    private func shouldAutoActivate(for selection: QueryResultsTableView.ForeignKeySelection, triggeredByIcon: Bool) -> Bool {
        guard foreignKeyDisplayMode != .disabled else { return false }
        switch foreignKeyDisplayMode {
        case .showInspector:
            if foreignKeyInspectorBehavior == .autoOpenAndClose {
                return true
            }
            return appState.showInfoSidebar
        case .showIcon:
            if foreignKeyInspectorBehavior == .autoOpenAndClose {
                return true
            }
            return triggeredByIcon
        case .disabled:
            return false
        }
    }

    private func performForeignKeyActivation(for selection: QueryResultsTableView.ForeignKeySelection) {
        guard foreignKeyDisplayMode != .disabled else { return }

        foreignKeyFetchTask?.cancel()

        foreignKeyFetchTask = Task {
            if foreignKeyInspectorBehavior == .autoOpenAndClose {
                await MainActor.run {
                    if !appState.showInfoSidebar {
                        appState.showInfoSidebar = true
                        autoOpenedInspector = true
                    }
                }
            }

            guard let content = await fetchForeignKeyInspectorContent(for: selection, includeRelated: includeRelatedForeignKeys, depth: 0) else {
                await MainActor.run {
                    if case .foreignKey = environmentState.dataInspectorContent {
                        environmentState.dataInspectorContent = nil
                    }
                }
                return
            }

            await MainActor.run {
                environmentState.dataInspectorContent = .foreignKey(content)
            }
        }
    }

    private func fetchForeignKeyInspectorContent(for selection: QueryResultsTableView.ForeignKeySelection, includeRelated: Bool, depth: Int) async -> ForeignKeyInspectorContent? {
        guard let lookupQuery = makeForeignKeyLookupQuery(for: selection, includeLimit: true) else { return nil }
        let detailQuery = makeForeignKeyLookupQuery(for: selection, includeLimit: false)
        do {
            let result = try await tab.session.simpleQuery(lookupQuery)
            guard let row = result.rows.first else { return nil }

            var fields: [ForeignKeyInspectorContent.Field] = []
            for (column, value) in zip(result.columns, row) {
                let displayValue = value ?? "NULL"
                fields.append(ForeignKeyInspectorContent.Field(label: column.name, value: displayValue))
            }

            let title = selection.reference.referencedTable
            let subtitle = selection.reference.referencedSchema.trimmingCharacters(in: .whitespacesAndNewlines)
            var related: [ForeignKeyInspectorContent] = []

            if includeRelated, depth < 1 {
                let mapping = await loadForeignKeyMapping(schema: selection.reference.referencedSchema, table: selection.reference.referencedTable)
                if !mapping.isEmpty {
                    related = await loadRelatedForeignKeyContent(mapping: mapping, baseRow: row, columns: result.columns, parentDepth: depth)
                }
            }

            return ForeignKeyInspectorContent(
                title: title,
                subtitle: subtitle.isEmpty ? nil : subtitle,
                fields: fields,
                related: related,
                lookupQuerySQL: detailQuery ?? lookupQuery
            )
        } catch {
            return nil
        }
    }

    private func loadRelatedForeignKeyContent(mapping: ForeignKeyMapping, baseRow: [String?], columns: [ColumnInfo], parentDepth: Int) async -> [ForeignKeyInspectorContent] {
        var related: [ForeignKeyInspectorContent] = []
        for (index, column) in columns.enumerated() {
            guard let reference = mapping[column.name.lowercased()] else { continue }
            guard index < baseRow.count, let raw = baseRow[index] else { continue }

            let trimmedValue = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedValue.isEmpty else { continue }

            let selection = QueryResultsTableView.ForeignKeySelection(
                row: 0,
                column: index,
                value: trimmedValue,
                columnName: column.name,
                reference: reference,
                valueKind: ResultGridValueClassifier.kind(forDataType: column.dataType, value: trimmedValue)
            )

            if let nested = await fetchForeignKeyInspectorContent(for: selection, includeRelated: includeRelatedForeignKeys, depth: parentDepth + 1) {
                related.append(nested)
            }
        }
        return related
    }

    private func loadForeignKeyMapping(schema: String, table: String) async -> ForeignKeyMapping {
        do {
            let details = try await tab.session.getTableStructureDetails(schema: schema, table: table)
            return buildForeignKeyMapping(from: details)
        } catch {
            return [:]
        }
    }

    private func makeForeignKeyLookupQuery(for selection: QueryResultsTableView.ForeignKeySelection, includeLimit: Bool) -> String? {
        let databaseType = tab.connection.databaseType
        guard let literal = makeForeignKeyLiteral(for: selection, databaseType: databaseType) else { return nil }
        let reference = selection.reference
        let tableIdentifier = qualifiedTable(schema: reference.referencedSchema, table: reference.referencedTable, databaseType: databaseType)
        let columnIdentifier = quoteIdentifier(reference.referencedColumn, databaseType: databaseType)

        switch databaseType {
        case .microsoftSQL:
            if includeLimit {
                return "SELECT TOP 1 * FROM \(tableIdentifier) WHERE \(columnIdentifier) = \(literal);"
            } else {
                return "SELECT * FROM \(tableIdentifier) WHERE \(columnIdentifier) = \(literal);"
            }
        default:
            if includeLimit {
                return "SELECT * FROM \(tableIdentifier) WHERE \(columnIdentifier) = \(literal) LIMIT 1;"
            } else {
                return "SELECT * FROM \(tableIdentifier) WHERE \(columnIdentifier) = \(literal);"
            }
        }
    }

    private func qualifiedTable(schema: String, table: String, databaseType: DatabaseType) -> String {
        let trimmedSchema = schema.trimmingCharacters(in: .whitespacesAndNewlines)
        let tablePart = quoteIdentifier(table, databaseType: databaseType)
        guard !trimmedSchema.isEmpty else { return tablePart }
        return "\(quoteIdentifier(trimmedSchema, databaseType: databaseType)).\(tablePart)"
    }

    private func quoteIdentifier(_ identifier: String, databaseType: DatabaseType) -> String {
        switch databaseType {
        case .postgresql, .sqlite:
            let escaped = identifier.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        case .mysql:
            let escaped = identifier.replacingOccurrences(of: "`", with: "``")
            return "`\(escaped)`"
        case .microsoftSQL:
            let escaped = identifier.replacingOccurrences(of: "]", with: "]]")
            return "[\(escaped)]"
        }
    }

    private func makeForeignKeyLiteral(for selection: QueryResultsTableView.ForeignKeySelection, databaseType: DatabaseType) -> String? {
        let rawValue = selection.value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch selection.valueKind {
        case .numeric:
            return rawValue.isEmpty ? nil : rawValue
        case .boolean:
            let normalized = rawValue.lowercased()
            let truthy: Set<String> = ["true", "t", "1", "yes", "y"]
            let isTrue = truthy.contains(normalized)
            switch databaseType {
            case .mysql, .microsoftSQL:
                return isTrue ? "1" : "0"
            case .postgresql, .sqlite:
                return isTrue ? "TRUE" : "FALSE"
            }
        default:
            let escaped = rawValue.replacingOccurrences(of: "'", with: "''")
            return "'\(escaped)'"
        }
    }
#endif
}

internal func buildForeignKeyMapping(from details: TableStructureDetails) -> ForeignKeyMapping {
    var mapping: ForeignKeyMapping = [:]
    for foreignKey in details.foreignKeys {
        guard foreignKey.columns.count == foreignKey.referencedColumns.count,
              foreignKey.columns.count == 1,
              let localColumn = foreignKey.columns.first,
              let referencedColumn = foreignKey.referencedColumns.first else { continue }

        let reference = ColumnInfo.ForeignKeyReference(
            constraintName: foreignKey.name,
            referencedSchema: foreignKey.referencedSchema,
            referencedTable: foreignKey.referencedTable,
            referencedColumn: referencedColumn
        )
        mapping[localColumn.lowercased()] = reference
    }
    return mapping
}
