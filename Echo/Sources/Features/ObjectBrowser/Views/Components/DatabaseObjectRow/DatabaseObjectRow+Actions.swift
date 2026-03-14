import SwiftUI
import EchoSense

extension DatabaseObjectRow {
    internal func performScriptAction(_ action: ScriptAction) {
        switch action {
        case .create:
            if object.type == .table {
                openCreateTableScript()
            } else {
                openCreateDefinition(insertOrReplace: false)
            }
        case .createOrReplace:
            openCreateDefinition(insertOrReplace: true)
        case .alter:
            openAlterStatement()
        case .alterTable:
            openAlterTableStatement()
        case .drop:
            openDropStatement(includeIfExists: false)
        case .dropIfExists:
            openDropStatement(includeIfExists: true)
        case .select:
            openSelectScript(limit: nil)
        case .selectLimited(let limit):
            openSelectScript(limit: limit)
        case .execute:
            openExecuteScript()
        }
    }
    
    internal func openNewQueryTab() {
        guard let session = environmentState.sessionCoordinator.sessionForConnection(connection.id) else { return }
        let qualified = qualifiedName(schema: object.schema, name: object.name)
        let sql = "-- Query for \(qualified)\n"
        Task { @MainActor in
            environmentState.openQueryTab(for: session, presetQuery: sql, database: databaseName)
        }
    }

    internal func openDataPreview() {
        guard let session = environmentState.sessionCoordinator.sessionForConnection(connection.id) else { return }
        let qualified = qualifiedName(schema: object.schema, name: object.name)
        let columns = object.columns.isEmpty ? ["*"] : object.columns.map { quoteIdentifier($0.name) }
        let columnLines = columns.joined(separator: ",\n    ")
        let databaseType = connection.databaseType
        let sql = makeSelectStatement(
            qualifiedName: qualified,
            columnLines: columnLines,
            databaseType: databaseType,
            limit: 200,
            offset: 0
        )
        Task { @MainActor in
            environmentState.openQueryTab(for: session, presetQuery: sql, database: databaseName)
        }
    }
    
    internal func openStructureTab() {
        if object.type == .extension {
            openExtensionStructure()
            return
        }
        Task { @MainActor in
            guard let session = environmentState.sessionCoordinator.sessionForConnection(connection.id) else { return }
            environmentState.openStructureTab(for: session, object: object, databaseName: databaseName)
        }
    }

    internal func openExtensionStructure() {
        guard object.type == .extension else { return }
        guard let session = environmentState.sessionCoordinator.sessionForConnection(connection.id) else { return }
        let dbName = databaseName ?? connection.database
        session.addExtensionStructureTab(extensionName: object.name, databaseName: dbName)
    }
    
    internal func openRelationsDiagram() {
        guard supportsDiagram else { return }
        Task { @MainActor in
            guard let session = environmentState.sessionCoordinator.sessionForConnection(connection.id) else { return }
            environmentState.openDiagramTab(for: session, object: object)
        }
    }

    internal func initiateTruncate() {
        if object.type == .table {
            showTruncateAlert = true
            return
        }
        let statement = truncateStatement()
        openScriptTab(with: statement)
    }

    internal func initiateRename() {
        renameText = object.name
        showRenameAlert = true
    }

    internal func initiateDrop(includeIfExists: Bool) {
        if object.type == .table {
            pendingDropIncludeIfExists = includeIfExists
            showDropAlert = true
            return
        }
        let statement = dropStatement(includeIfExists: includeIfExists)
        openScriptTab(with: statement)
    }
}
