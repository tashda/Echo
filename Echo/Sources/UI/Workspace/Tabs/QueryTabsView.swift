import SwiftUI
import Foundation
import UniformTypeIdentifiers
import EchoSense
#if os(macOS)
import AppKit
#else
import UIKit
#endif

#if os(macOS)
func tabHairlineWidth() -> CGFloat {
    let scale = NSScreen.main?.backingScaleFactor ?? 2
    return max(1.0 / scale, 0.5)
}
#else
func tabHairlineWidth() -> CGFloat { 1 }
#endif

fileprivate typealias ForeignKeyMapping = [String: ColumnInfo.ForeignKeyReference]

#if os(macOS)
private func buildForeignKeyMapping(from details: TableStructureDetails) -> ForeignKeyMapping {
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
#endif

@MainActor
fileprivate func applyForeignKeyMapping(to update: QueryStreamUpdate, mapping: ForeignKeyMapping) -> QueryStreamUpdate {
    guard !mapping.isEmpty else { return update }
    let columns = applyForeignKeyMapping(to: update.columns, mapping: mapping)
    return QueryStreamUpdate(
        columns: columns,
        appendedRows: update.appendedRows,
        encodedRows: update.encodedRows,
        totalRowCount: update.totalRowCount,
        metrics: update.metrics
    )
}

@MainActor
fileprivate func applyForeignKeyMapping(to columns: [ColumnInfo], mapping: ForeignKeyMapping) -> [ColumnInfo] {
    guard !mapping.isEmpty else { return columns }
    return columns.map { column in
        var updated = column
        if updated.foreignKey == nil, let reference = mapping[column.name.lowercased()] {
            updated.foreignKey = reference
        }
        return updated
    }
}

struct QueryTabsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.hostedWorkspaceTabID) private var hostedWorkspaceTabID


    var showsTabStrip: Bool = true
    var tabBarLeadingPadding: CGFloat = 6
    var tabBarTrailingPadding: CGFloat = 6
    private var recentConnectionItems: [RecentConnectionItem] {
        appModel.recentConnections.compactMap { record in
            guard let connection = appModel.connections.first(where: { $0.id == record.connectionID }) else {
                return nil
            }

            let trimmedName = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = trimmedName.isEmpty ? connection.host : trimmedName
            let trimmedDatabase = record.databaseName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let database = (trimmedDatabase?.isEmpty == false) ? trimmedDatabase : nil

            return RecentConnectionItem(
                id: record.id,
                record: record,
                name: displayName,
                server: connection.host,
                database: database,
                lastConnectedAt: record.lastConnectedAt,
                databaseType: connection.databaseType
            )
        }
    }
    private var currentWorkspaceTab: WorkspaceTab? {
        if let hostedWorkspaceTabID,
           let hostedTab = appModel.tabManager.getTab(id: hostedWorkspaceTabID) {
            return hostedTab
        }

        return appModel.tabManager.activeTab
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsTabStrip {
                QueryTabStrip(
                    leadingPadding: tabBarLeadingPadding,
                    trailingPadding: tabBarTrailingPadding
                )
            }

            if appState.showTabOverview {
                TabOverviewView(
                    tabs: appModel.tabManager.tabs,
                    activeTabId: appModel.tabManager.activeTabId,
                    onSelectTab: { tabId in
                        appModel.tabManager.activeTabId = tabId
                        appState.showTabOverview = false
                    },
                    onCloseTab: { tabId in
                        appModel.tabManager.closeTab(id: tabId)
                    }
                )
            } else if let currentTab = currentWorkspaceTab {
                WorkspaceContentView(
                    tab: currentTab,
                    runQuery: { sql in await runQuery(tabId: currentTab.id, sql: sql) },
                    cancelQuery: { cancelQuery(tabId: currentTab.id) },
                    gridStateProvider: { currentTab.resultsGridState }
                )
            } else {
                RecentConnectionsPlaceholder(
                    connections: recentConnectionItems,
                    onSelectConnection: connectToRecentConnection
                )
            }
        }
        .onAppear(perform: createInitialTabIfNeeded)
        .onChange(of: appModel.selectedConnection) { _, _ in
            createInitialTabIfNeeded()
        }
        .onChange(of: appModel.tabManager.activeTabId) { _, _ in
            if appState.showTabOverview {
                appState.showTabOverview = false
            }
        }
    }

    private func createInitialTabIfNeeded() {
        guard appModel.tabManager.tabs.isEmpty,
              let activeSession = appModel.sessionManager.activeSession else { return }

        appModel.openQueryTab(for: activeSession)
    }

    private func runQuery(tabId: UUID, sql: String) async {
        guard let tab = appModel.tabManager.getTab(id: tabId),
              let queryState = tab.query else { return }

        let trimmedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        var effectiveSQL = trimmedSQL.isEmpty ? sql : trimmedSQL
        while effectiveSQL.last == ";" {
            effectiveSQL.removeLast()
        }
        effectiveSQL = effectiveSQL.trimmingCharacters(in: .whitespacesAndNewlines)
        if effectiveSQL.isEmpty {
            effectiveSQL = trimmedSQL.isEmpty ? sql : trimmedSQL
        }
        let inferredObject = inferPrimaryObjectName(from: effectiveSQL)
        await MainActor.run {
            queryState.updateClipboardObjectName(inferredObject)
        }
        let foreignKeyMode = await MainActor.run { appModel.globalSettings.foreignKeyDisplayMode }
        let shouldResolveForeignKeys = foreignKeyMode != .disabled

        let task = Task { [weak queryState] in
            guard let state = await MainActor.run(body: { queryState }) else { return }

            do {
                await MainActor.run {
                    state.recordQueryDispatched()
                }
                let result = try await tab.session.simpleQuery(effectiveSQL) { [weak state] update in
                    guard let state else { return }

                    Task { @MainActor in
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            state.applyStreamUpdate(update)
                        }
                    }
                }
                try Task.checkCancellation()
                let mapping: ForeignKeyMapping
                if shouldResolveForeignKeys {
                    mapping = await loadForeignKeyMapping(for: tab, inferredObject: inferredObject)
                } else {
                    mapping = [:]
                }
                try Task.checkCancellation()
                var enrichedResult = result
                if !mapping.isEmpty {
                    enrichedResult.columns = await MainActor.run {
                        applyForeignKeyMapping(to: result.columns, mapping: mapping)
                    }
                }
                await MainActor.run {
                    state.consumeFinalResult(enrichedResult)
                    state.finishExecution()

                    var metadata: [String: String] = [
                        "rows": "\(enrichedResult.rows.count)"
                    ]
                    let columnNames = enrichedResult.columns.map(\.name).joined(separator: ", ")
                    if !columnNames.isEmpty {
                        metadata["columns"] = columnNames
                    }
                    if let commandTag = enrichedResult.commandTag, !commandTag.isEmpty {
                        metadata["commandTag"] = commandTag
                    }

                    state.appendMessage(
                        message: "Returned \(enrichedResult.rows.count) row\(enrichedResult.rows.count == 1 ? "" : "s")",
                        severity: .info,
                        metadata: metadata
                    )
                    appState.addToQueryHistory(effectiveSQL, resultCount: enrichedResult.rows.count, duration: state.lastExecutionTime ?? 0)
                }
            } catch is CancellationError {
                await MainActor.run {
                    state.markCancellationCompleted()
                }
            } catch {
                await MainActor.run {
                    state.errorMessage = error.localizedDescription
                    state.failExecution(with: "Query execution failed: \(error.localizedDescription)")
                }
            }
        }

        await MainActor.run {
            queryState.errorMessage = nil
            queryState.startExecution()
            queryState.setExecutingTask(task)
            appModel.dataInspectorContent = nil
        }
    }

    private func cancelQuery(tabId: UUID) {
        guard let tab = appModel.tabManager.getTab(id: tabId),
              let queryState = tab.query else { return }
        queryState.cancelExecution()
    }

    private func connectToRecentConnection(_ item: RecentConnectionItem) {
        Task {
            await appModel.connectToRecentConnection(item.record)
        }
    }

    private func inferPrimaryObjectName(from sql: String) -> String? {
        let cleanedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedSQL.isEmpty else { return nil }

        let patterns = [
            #"(?i)\bfrom\s+([A-Za-z0-9_\.\"`]+)"#,
            #"(?i)\binto\s+([A-Za-z0-9_\.\"`]+)"#,
            #"(?i)\bupdate\s+([A-Za-z0-9_\.\"`]+)"#,
            #"(?i)\bdelete\s+from\s+([A-Za-z0-9_\.\"`]+)"#
        ]

        for pattern in patterns {
            if let match = firstMatch(in: cleanedSQL, pattern: pattern) {
                return normalizeIdentifier(match)
            }
        }

        return nil
    }

    private func firstMatch(in sql: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: (sql as NSString).length)
        guard let match = regex.firstMatch(in: sql, options: [], range: range), match.numberOfRanges > 1 else { return nil }
        let matchRange = match.range(at: 1)
        guard let rangeInString = Range(matchRange, in: sql) else { return nil }
        return String(sql[rangeInString])
    }

    private func normalizeIdentifier(_ identifier: String) -> String {
        let trimmed = identifier.trimmingCharacters(in: CharacterSet(charactersIn: "`\"'[]"))
        return trimmed
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "].[", with: ".")
    }
    private func loadForeignKeyMapping(for tab: WorkspaceTab, inferredObject: String?) async -> ForeignKeyMapping {
        guard let components = resolveSchemaAndTable(for: inferredObject, connection: tab.connection) else { return [:] }
        do {
            let details = try await tab.session.getTableStructureDetails(schema: components.schema, table: components.table)
            return buildForeignKeyMapping(from: details)
        } catch {
            return [:]
        }
    }

    private func resolveSchemaAndTable(for identifier: String?, connection: SavedConnection) -> (schema: String, table: String)? {
        guard let identifier, !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let components = parseQualifiedIdentifier(identifier)
        guard let table = components.last, !table.isEmpty else { return nil }
        let schemaCandidate = components.count >= 2 ? components[components.count - 2] : nil
        let effectiveSchema: String?
        if let schemaCandidate, !schemaCandidate.isEmpty {
            effectiveSchema = schemaCandidate
        } else {
            effectiveSchema = defaultSchema(for: connection.databaseType, connection: connection)
        }

        switch connection.databaseType {
        case .mysql, .sqlite:
            let schema = effectiveSchema ?? connection.database.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !schema.isEmpty else { return nil }
            return (schema: schema, table: table)
        default:
            guard let schema = effectiveSchema, !schema.isEmpty else { return nil }
            return (schema: schema, table: table)
        }
    }

    private func parseQualifiedIdentifier(_ identifier: String) -> [String] {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let sanitized = trimmed
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
        return sanitized.split(separator: ".").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func defaultSchema(for type: DatabaseType, connection: SavedConnection) -> String? {
        switch type {
        case .microsoftSQL:
            return "dbo"
        case .postgresql:
            return "public"
        case .mysql:
            let database = connection.database.trimmingCharacters(in: .whitespacesAndNewlines)
            return database.isEmpty ? nil : database
        case .sqlite:
            return "main"
        }
    }

}
