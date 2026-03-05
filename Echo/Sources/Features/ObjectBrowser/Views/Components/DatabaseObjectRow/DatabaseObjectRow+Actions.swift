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
            environmentState.openQueryTab(for: session, presetQuery: sql)
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
            environmentState.openQueryTab(for: session, presetQuery: sql)
        }
    }
    
    internal func openStructureTab() {
        Task { @MainActor in
            guard let session = environmentState.sessionCoordinator.sessionForConnection(connection.id) else { return }
            environmentState.openStructureTab(for: session, object: object)
        }
    }
    
    internal func openRelationsDiagram() {
        guard supportsDiagram else { return }
        Task { @MainActor in
            guard let session = environmentState.sessionCoordinator.sessionForConnection(connection.id) else { return }
            environmentState.openDiagramTab(for: session, object: object)
        }
    }

    internal func initiateTruncate() {
#if os(macOS)
        if object.type == .table {
            Task { await presentTruncatePrompt() }
            return
        }
#endif
        let statement = truncateStatement()
        openScriptTab(with: statement)
    }
    
    internal func initiateRename() {
#if os(macOS)
        Task { await presentRenamePrompt() }
#else
        if let template = renameStatement() {
            openScriptTab(with: template)
        }
#endif
    }

    internal func initiateDrop(includeIfExists: Bool) {
#if os(macOS)
        if object.type == .table {
            Task { await presentDropPrompt(includeIfExists: includeIfExists) }
            return
        }
#endif
        let statement = dropStatement(includeIfExists: includeIfExists)
        openScriptTab(with: statement)
    }
}
