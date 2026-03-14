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
                if autoOpenInspector {
                    performForeignKeyActivation(for: selection, forceOpen: true)
                } else if appState.showInfoSidebar {
                    performForeignKeyActivation(for: selection, forceOpen: false)
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
            performForeignKeyActivation(for: selection, forceOpen: true)
        }
    }

    private func performForeignKeyActivation(for selection: QueryResultsTableView.ForeignKeySelection, forceOpen: Bool = false) {
        fkLog.debug("[FK Inspector] performForeignKeyActivation: column=\(selection.columnName), value=\(selection.value), ref=\(selection.reference.referencedTable).\(selection.reference.referencedColumn), forceOpen=\(forceOpen)")

        foreignKeyFetchTask?.cancel()

        foreignKeyFetchTask = Task {
            let session = await resolveExecutionSession()
            let content = await fetchForeignKeyInspectorContent(for: selection, session: session)

            await MainActor.run {
                if let content {
                    environmentState.dataInspectorContent = .foreignKey(content)
                } else {
                    let errorContent = ForeignKeyInspectorContent(
                        title: selection.reference.referencedTable,
                        subtitle: selection.reference.referencedSchema.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : selection.reference.referencedSchema,
                        fields: [],
                        lookupQuerySQL: makeForeignKeyLookupQuery(for: selection, includeLimit: false),
                        errorMessage: "Could not load referenced row"
                    )
                    environmentState.dataInspectorContent = .foreignKey(errorContent)
                }

                let shouldOpen = forceOpen || autoOpenInspector
                if shouldOpen, !appState.showInfoSidebar {
                    appState.showInfoSidebar = true
                    inspectorAutoOpened = true
                }
            }
        }
    }

    private func fetchForeignKeyInspectorContent(for selection: QueryResultsTableView.ForeignKeySelection, session: DatabaseSession) async -> ForeignKeyInspectorContent? {
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

            var fields: [ForeignKeyInspectorContent.Field] = []
            for (column, value) in zip(result.columns, row) {
                let displayValue = value ?? "NULL"
                fields.append(ForeignKeyInspectorContent.Field(label: column.name, value: displayValue))
            }

            let title = selection.reference.referencedTable
            let subtitle = selection.reference.referencedSchema.trimmingCharacters(in: .whitespacesAndNewlines)

            return ForeignKeyInspectorContent(
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
