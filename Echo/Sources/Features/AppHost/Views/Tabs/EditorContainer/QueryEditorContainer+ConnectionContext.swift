import SwiftUI
import EchoSense

extension QueryEditorContainer {
    var connectionSession: ConnectionSession? {
        environmentState.sessionGroup.activeSessions.first { $0.id == tab.connectionSessionID }
    }

    var connectionServerName: String? {
        let name = (connectionSession?.connection.connectionName ?? tab.connection.connectionName)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        let host = (connectionSession?.connection.host ?? tab.connection.host)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return host.isEmpty ? nil : host
    }

    var connectionDatabaseName: String? {
        QueryEditorConnectionContextResolver.resolveDatabaseName(
            tabDatabaseName: tab.activeDatabaseName,
            sessionDatabaseName: connectionSession?.selectedDatabaseName,
            connectionDatabaseName: tab.connection.database
        )
    }

#if os(macOS)
    var showForeignKeysInInspector: Bool {
        projectStore.globalSettings.showForeignKeysInInspector
    }

    var showJsonInInspector: Bool {
        projectStore.globalSettings.showJsonInInspector
    }

    var autoOpenInspector: Bool {
        projectStore.globalSettings.autoOpenInspectorOnSelection
    }

    /// Defers the auto-close check to the next run loop tick,
    /// giving other handlers (FK, JSON) a chance to set new content first.
    func deferredInspectorAutoClose() {
        guard inspectorAutoOpened else { return }
        Task { @MainActor in
            // Don't close if another selection is active (content pending async load)
            guard inspectorAutoOpened,
                  environmentState.dataInspectorContent == nil,
                  latestForeignKeySelection == nil,
                  latestJsonSelection == nil,
                  appState.showInfoSidebar else { return }
            inspectorAutoOpened = false
            appState.showInfoSidebar = false
        }
    }

    func resolveExecutionSession() async -> DatabaseSession {
        if tab.connection.databaseType == .postgresql,
           let activeDB = tab.activeDatabaseName, !activeDB.isEmpty {
            return (try? await tab.session.sessionForDatabase(activeDB)) ?? tab.session
        }
        return tab.session
    }
#endif

    func updateClipboardContext() {
        query.updateClipboardContext(
            serverName: connectionServerName,
            databaseName: connectionDatabaseName,
            connectionColorHex: connectionColorHex
        )
    }

    var connectionForDisplay: SavedConnection {
        var snapshot = connectionSession?.connection ?? tab.connection
        snapshot.serverVersion = connectionServerVersion
        return snapshot
    }

    var connectionColorHex: String? {
        if let sessionHex = connectionSession?.connection.metadataColorHex {
            return sessionHex
        }
        return tab.connection.metadataColorHex
    }

    var editorCompletionContext: SQLEditorCompletionContext? {
        let session = connectionSession
        let baseConnection = session?.connection ?? tab.connection
        let databaseType = EchoSenseDatabaseType(baseConnection.databaseType)
        let selectedDatabase = QueryEditorConnectionContextResolver.resolveDatabaseName(
            tabDatabaseName: tab.activeDatabaseName,
            sessionDatabaseName: session?.selectedDatabaseName,
            connectionDatabaseName: baseConnection.database
        )
        let structure = session?.databaseStructure
            ?? session?.connection.cachedStructure
            ?? tab.connection.cachedStructure
        let defaultSchema = defaultSchema(for: databaseType)
        let completionStructure = QueryEditorConnectionContextResolver.completionStructure(
            from: structure,
            selectedDatabase: selectedDatabase
        )

        return SQLEditorCompletionContext(
            databaseType: databaseType,
            selectedDatabase: selectedDatabase,
            defaultSchema: defaultSchema,
            structure: completionStructure.flatMap { EchoSenseBridge.makeStructure(from: $0) }
        )
    }

    func handleBookmarkRequest(_ sql: String) {
        Task {
            await environmentState.addBookmark(
                for: tab.connection,
                databaseName: connectionDatabaseName,
                title: tabTitleForBookmark,
                query: sql,
                source: .queryEditorSelection
            )
        }
    }

    var connectionServerVersion: String? {
        let candidates: [String?] = [
            connectionSession?.databaseStructure?.serverVersion,
            connectionSession?.connection.serverVersion,
            tab.connection.serverVersion
        ]
        for candidate in candidates {
            if let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    func defaultSchema(for type: EchoSenseDatabaseType) -> String? {
        switch type {
        case .microsoftSQL:
            return "dbo"
        case .postgresql:
            return "public"
        case .mysql, .sqlite:
            return nil
        }
    }

    // MARK: - Schema Loading

    /// Triggers a targeted schema load for the tab's active database if its schemas
    /// are not yet present in the session structure. Called when the tab first appears.
    func ensureCurrentDatabaseStructureLoaded() {
        guard let activeDB = tab.activeDatabaseName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !activeDB.isEmpty,
              let session = connectionSession else { return }
        ensureSchemaLoaded(forDatabase: activeDB, in: session)
    }

    /// Triggers a targeted schema load for the named database if its schemas are not
    /// yet in the session structure. Called when the user types a cross-DB prefix (e.g. "employees.").
    func ensureSchemaLoaded(forDatabase databaseName: String) {
        guard let session = connectionSession else { return }
        ensureSchemaLoaded(forDatabase: databaseName, in: session)
    }

    private func ensureSchemaLoaded(forDatabase databaseName: String, in session: ConnectionSession) {
        guard let normalizedDatabase = normalized(databaseName) else { return }
        guard !session.hasLoadedSchema(forDatabase: normalizedDatabase) else { return }
        guard session.beginSchemaLoad(forDatabase: normalizedDatabase) else { return }

        Task {
            defer { session.finishSchemaLoad(forDatabase: normalizedDatabase) }
            guard !session.hasLoadedSchema(forDatabase: normalizedDatabase) else { return }
            await environmentState.loadSchemaForDatabase(normalizedDatabase, connectionSession: session)
        }
    }

    func normalized(_ value: String?) -> String? {
        QueryEditorConnectionContextResolver.normalize(value)
    }

    var tabTitleForBookmark: String? {
        let trimmed = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
