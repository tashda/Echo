import SwiftUI
import EchoSense
import os.log
#if os(macOS)
import AppKit
#endif

private let fkLog = Logger(subsystem: "com.echo.app", category: "ForeignKey")

internal typealias ForeignKeyMapping = [String: ColumnInfo.ForeignKeyReference]

extension QueryEditorContainer {
#if os(macOS)
    func handleForeignKeyEvent(_ event: QueryResultsTableView.ForeignKeyEvent) {
        switch event {
        case .selectionChanged(let selection):
            latestForeignKeySelection = selection
            if selection != nil {
                latestJsonSelection = nil
            }
            guard showForeignKeysInInspector else { return }
            if let selection {
                // Selecting is passive (round IC, F1): it opens a closed column only with
                // auto-open on, and never takes another page away.
                if autoOpenInspector || appState.isInspectorVisible {
                    performForeignKeyActivation(for: selection)
                }
            } else {
                foreignKeyFetchTask?.cancel()
                foreignKeyFetchTask = nil
                // Clear FK content if we still own it
                if case .foreignKey = environmentState.dataInspectorContent {
                    environmentState.dataInspectorContent = nil
                }
                // Defer close check to let other handlers (JSON) set content first
                deferredInspectorAutoClose()
            }
        case .requestMetadata:
            guard let context = query.beginForeignKeyMappingFetch() else { return }
            Task(priority: .utility) {
                let session = await resolveExecutionSession()
                let mapping = await loadForeignKeyMapping(session: session, schema: context.schema, table: context.table)
                await MainActor.run {
                    if Task.isCancelled {
                        query.failForeignKeyMappingFetch()
                    } else {
                        query.completeForeignKeyMappingFetch(with: mapping)
                    }
                }
            }

        case .activate(let selection):
            guard showForeignKeysInInspector else { return }
            performForeignKeyActivation(for: selection, deliberate: true)
        }
    }

    private func performForeignKeyActivation(for selection: QueryResultsTableView.ForeignKeySelection, deliberate: Bool = false) {
        fkLog.debug("[FK Inspector] performForeignKeyActivation: column=\(selection.columnName), value=\(selection.value), ref=\(selection.reference.referencedTable).\(selection.reference.referencedColumn), deliberate=\(deliberate)")

        foreignKeyFetchTask?.cancel()

        foreignKeyFetchTask = Task {
            let session = await resolveExecutionSession()
            let content = await fetchDatabaseObjectInspectorContent(for: selection, session: session)

            await MainActor.run {
                if let content {
                    environmentState.dataInspectorContent = .databaseObject(content)
                } else {
                    let errorContent = DatabaseObjectInspectorContent(
                        title: selection.reference.referencedTable,
                        subtitle: selection.reference.referencedSchema.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : selection.reference.referencedSchema,
                        fields: [],
                        lookupQuerySQL: makeForeignKeyLookupQuery(for: selection, includeLimit: false),
                        errorMessage: "Could not load referenced row"
                    )
                    environmentState.dataInspectorContent = .databaseObject(errorContent)
                }

                if deliberate {
                    if !appState.isInspectorVisible { inspectorAutoOpened = true }
                    appState.showInspectorPage(.details)
                } else if appState.noteDetailsChanged(autoOpen: autoOpenInspector) {
                    inspectorAutoOpened = true
                }
            }
        }
    }

    private func fetchDatabaseObjectInspectorContent(for selection: QueryResultsTableView.ForeignKeySelection, session: DatabaseSession) async -> DatabaseObjectInspectorContent? {
        guard let lookupQuery = makeForeignKeyLookupQuery(for: selection, includeLimit: true) else {
            fkLog.debug("[FK Inspector] Failed to build lookup query for \(selection.columnName) = \(selection.value)")
            return nil
        }
        let detailQuery = makeForeignKeyLookupQuery(for: selection, includeLimit: false)
        do {
            let result = try await session.simpleQuery(lookupQuery)
            guard let row = result.rows.first else {
                fkLog.debug("[FK Inspector] Query returned no rows: \(lookupQuery)")
                return nil
            }

            var fields: [DatabaseObjectInspectorContent.Field] = []
            for (column, value) in zip(result.columns, row) {
                let displayValue = value ?? "NULL"
                fields.append(DatabaseObjectInspectorContent.Field(label: column.name, value: displayValue))
            }

            let title = selection.reference.referencedTable
            let subtitle = selection.reference.referencedSchema.trimmingCharacters(in: .whitespacesAndNewlines)

            return DatabaseObjectInspectorContent(
                title: title,
                subtitle: subtitle.isEmpty ? nil : subtitle,
                fields: fields,
                lookupQuerySQL: detailQuery ?? lookupQuery
            )
        } catch {
            fkLog.debug("[FK Inspector] Query failed: \(error) — SQL: \(lookupQuery)")
            return nil
        }
    }

    private func loadForeignKeyMapping(session: DatabaseSession, schema: String, table: String) async -> ForeignKeyMapping {
        do {
            let details = try await session.getTableStructureDetails(schema: schema, table: table)
            return buildForeignKeyMapping(from: details)
        } catch {
            return [:]
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
