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
        case .insert:
            openInsertScript()
        case .update:
            openUpdateScript()
        case .delete:
            openDeleteScript()
        }
    }
    
    internal func openNewQueryTab() {
        guard let session = environmentState.sessionGroup.sessionForConnection(connection.id) else { return }
        let qualified = qualifiedName(schema: object.schema, name: object.name)
        let sql = "-- Query for \(qualified)\n"
        Task { @MainActor in
            environmentState.openQueryTab(for: session, presetQuery: sql, database: databaseName)
        }
    }

    internal func openDataPreview() {
        guard let session = environmentState.sessionGroup.sessionForConnection(connection.id) else { return }
        Task { @MainActor in
            environmentState.openTableDataTab(
                for: session,
                schema: object.schema,
                table: object.name,
                databaseName: databaseName
            )
        }
    }
    
    internal func openStructureTab() {
        if object.type == .extension {
            openExtensionStructure()
            return
        }
        Task { @MainActor in
            guard let session = environmentState.sessionGroup.sessionForConnection(connection.id) else { return }
            environmentState.openStructureTab(for: session, object: object, databaseName: databaseName)
        }
    }

    internal func openExtensionStructure() {
        guard object.type == .extension else { return }
        guard let session = environmentState.sessionGroup.sessionForConnection(connection.id) else { return }
        let dbName = databaseName ?? connection.database
        session.addExtensionStructureTab(extensionName: object.name, databaseName: dbName)
    }
    
    internal func openRelationsDiagram() {
        guard supportsDiagram else { return }
        Task { @MainActor in
            guard let session = environmentState.sessionGroup.sessionForConnection(connection.id) else { return }
            environmentState.openDiagramTab(for: session, object: object)
        }
    }

    internal func openDependenciesQuery() {
        guard let session = environmentState.sessionGroup.sessionForConnection(connection.id) else { return }
        let schema = object.schema
        let sql = """
        -- Dependencies for [\(schema)].[\(object.name)]
        SELECT
            OBJECT_NAME(d.referencing_id) AS [Referencing Object],
            o1.type_desc AS [Referencing Type],
            COALESCE(d.referenced_entity_name, OBJECT_NAME(d.referenced_id)) AS [Referenced Object],
            COALESCE(o2.type_desc, d.referenced_class_desc) AS [Referenced Type]
        FROM sys.sql_expression_dependencies d
        LEFT JOIN sys.objects o1 ON d.referencing_id = o1.object_id
        LEFT JOIN sys.objects o2 ON d.referenced_id = o2.object_id
        WHERE d.referencing_id = OBJECT_ID('[\(schema)].[\(object.name)]')
           OR d.referenced_id = OBJECT_ID('[\(schema)].[\(object.name)]')
        ORDER BY [Referencing Object], [Referenced Object];
        """
        Task { @MainActor in
            environmentState.openQueryTab(for: session, presetQuery: sql, autoExecute: true, database: databaseName)
        }
    }

    internal func openTableProperties() {
        let value = environmentState.prepareTablePropertiesWindow(
            connectionSessionID: connection.id,
            schemaName: object.schema,
            tableName: object.name,
            databaseType: connection.databaseType
        )
        openWindow(id: TablePropertiesWindow.sceneID, value: value)
    }

    internal func openTablePropertiesQuery() {
        guard let session = environmentState.sessionGroup.sessionForConnection(connection.id) else { return }
        let schema = object.schema
        let sql = """
        -- Properties for [\(schema)].[\(object.name)]
        EXEC sp_spaceused N'[\(schema)].[\(object.name)]';

        SELECT
            o.create_date AS [Created],
            o.modify_date AS [Last Modified],
            o.type_desc AS [Type],
            i.rows AS [Row Count]
        FROM sys.objects o
        LEFT JOIN sys.sysindexes i ON o.object_id = i.id AND i.indid IN (0, 1)
        WHERE o.object_id = OBJECT_ID('[\(schema)].[\(object.name)]');
        """
        Task { @MainActor in
            environmentState.openQueryTab(for: session, presetQuery: sql, autoExecute: true, database: databaseName)
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
