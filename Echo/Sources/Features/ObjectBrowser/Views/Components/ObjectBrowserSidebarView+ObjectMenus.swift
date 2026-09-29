import AppKit
import SwiftUI
import SQLServerKit

/// Menus for object folders (Tables, Views…) and the objects in them.
extension ObjectBrowserSidebarView {
    func objectGroupMenu(
        for type: SchemaObjectInfo.ObjectType,
        databaseName: String,
        session: ConnectionSession
    ) -> NSMenu {
        let menu = NSMenu()

        menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
            Task {
                let handle = AppDirector.shared.activityEngine.begin("Refreshing \(type.pluralDisplayName)", connectionSessionID: session.id)
                await environmentState.loadSchemaForDatabase(databaseName, connectionSession: session)
                handle.succeed()
            }
        }

        if let title = experimentalObjectGroupCreationTitle(for: type) {
            menu.addDivider()
            let hasDesigner = VisualEditorResolver.hasVisualEditor(for: type, databaseType: session.connection.databaseType)

            if hasDesigner {
                menu.addActionItem(title, systemImage: experimentalObjectGroupCreationIcon(for: type)) {
                    openNewObjectInDesigner(type: type, session: session)
                }
                menu.addActionItem(title + " (SQL)", systemImage: "scroll") {
                    let schemaName = session.connection.databaseType == .microsoftSQL ? "dbo" : "public"
                    let sql = experimentalObjectGroupCreationSQL(
                        for: title,
                        databaseType: session.connection.databaseType,
                        schemaName: schemaName
                    )
                    environmentState.openQueryTab(for: session, presetQuery: sql, database: databaseName)
                }
            } else if type == .extension {
                menu.addActionItem(title, systemImage: experimentalObjectGroupCreationIcon(for: type)) {
                    environmentState.openExtensionsManagerTab(connectionID: session.connection.id, databaseName: databaseName)
                }
            } else {
                menu.addActionItem(title, systemImage: experimentalObjectGroupCreationIcon(for: type)) {
                    let schemaName = session.connection.databaseType == .microsoftSQL ? "dbo" : "public"
                    let sql = experimentalObjectGroupCreationSQL(
                        for: title,
                        databaseType: session.connection.databaseType,
                        schemaName: schemaName
                    )
                    environmentState.openQueryTab(for: session, presetQuery: sql, database: databaseName)
                }
            }
        }

        return menu
    }

    func objectMenu(
        for object: SchemaObjectInfo,
        databaseName: String,
        session: ConnectionSession
    ) -> NSMenu {
        let menu = NSMenu()
        let databaseType = session.connection.databaseType

        menu.addActionItem("New Query", systemImage: "doc.text") {
            environmentState.openQueryTab(for: session, database: databaseName)
        }

        if object.type == .extension {
            menu.addActionItem("New Extension", systemImage: "puzzlepiece.extension") {
                environmentState.openExtensionsManagerTab(connectionID: session.connection.id, databaseName: databaseName)
            }
        }

        menu.addDivider()

        if object.type == .table || object.type == .view || object.type == .materializedView {
            menu.addActionItem("Data", systemImage: "tablecells") {
                let sql = previewQuery(for: object, databaseType: databaseType)
                environmentState.openQueryTab(for: session, presetQuery: sql, database: databaseName)
            }
        }

        if object.type == .table || object.type == .extension {
            menu.addActionItem("Structure", systemImage: object.type == .extension ? "puzzlepiece.fill" : "square.stack.3d.up") {
                environmentState.openStructureTab(for: session, object: object, databaseName: databaseName)
            }
        }

        if object.type == .table {
            menu.addActionItem("Diagram", systemImage: "rectangle.connected.to.line.below") {
                environmentState.openDiagramTab(for: session, object: object, activeDatabaseName: databaseName)
            }
        }

        if [.view, .materializedView, .function, .procedure, .trigger, .sequence, .type].contains(object.type) {
            menu.addActionItem("Definition", systemImage: "doc.text") {
                openDefinition(for: object, databaseName: databaseName, session: session)
            }
        }

        if object.type == .function || object.type == .procedure {
            menu.addActionItem("Execute", systemImage: "play.circle") {
                let sql = executeStatement(for: object, databaseType: databaseType)
                environmentState.openQueryTab(for: session, presetQuery: sql, database: databaseName)
            }
        }

        if VisualEditorResolver.hasVisualEditor(for: object.type, databaseType: databaseType) {
            menu.addActionItem("Edit in Designer", systemImage: "rectangle.and.pencil.and.ellipsis") {
                openObjectInDesigner(object, session: session)
            }
        }

        if object.type == .procedure || object.type == .function {
            menu.addActionItem("Modify", systemImage: "pencil.and.outline") {
                openAlterDefinition(for: object, databaseName: databaseName, session: session)
            }
        }

        let scriptActions = ScriptActionResolver.actions(for: object.type, databaseType: databaseType)
        if !scriptActions.isEmpty {
            menu.addDivider()
            menu.addSubmenu("Script as", systemImage: "scroll") { submenu in
                let readActions = scriptActions.filter(\.isReadGroup)
                let createActions = scriptActions.filter(\.isCreateModifyGroup)
                let writeActions = scriptActions.filter(\.isWriteGroup)
                let executeActions = scriptActions.filter(\.isExecuteGroup)
                let destroyActions = scriptActions.filter(\.isDestroyGroup)

                addScriptActions(readActions, to: submenu, object: object, databaseName: databaseName, session: session)
                if !readActions.isEmpty && !createActions.isEmpty { submenu.addDivider() }
                addScriptActions(createActions, to: submenu, object: object, databaseName: databaseName, session: session)
                if !createActions.isEmpty && !writeActions.isEmpty { submenu.addDivider() }
                addScriptActions(writeActions, to: submenu, object: object, databaseName: databaseName, session: session)
                if !writeActions.isEmpty && !executeActions.isEmpty { submenu.addDivider() }
                if writeActions.isEmpty && !createActions.isEmpty && !executeActions.isEmpty { submenu.addDivider() }
                addScriptActions(executeActions, to: submenu, object: object, databaseName: databaseName, session: session)
                let hasNonDestroy = !executeActions.isEmpty || !writeActions.isEmpty || !createActions.isEmpty || !readActions.isEmpty
                if hasNonDestroy && !destroyActions.isEmpty { submenu.addDivider() }
                addScriptActions(destroyActions, to: submenu, object: object, databaseName: databaseName, session: session)
            }
        }

        if databaseType == .microsoftSQL || object.type == .table || object.type == .view {
            menu.addDivider()
            menu.addSubmenu("Tasks", systemImage: "checklist") { submenu in
                if databaseType == .microsoftSQL {
                    submenu.addActionItem("Generate Scripts", systemImage: "applescript") {
                        sheetState.generateScriptsDatabaseName = databaseName
                        sheetState.generateScriptsConnectionID = session.connection.id
                        sheetState.showGenerateScriptsWizard = true
                    }
                }
                if object.type == .table {
                    submenu.addActionItem("Import Data", systemImage: "square.and.arrow.down") {
                        sheetState.quickImportDatabaseName = databaseName
                        sheetState.quickImportConnectionID = session.connection.id
                        sheetState.showQuickImportSheet = true
                    }
                }
                if object.type == .table && databaseType == .microsoftSQL && object.isSystemVersioned != true && object.isHistoryTable != true {
                    submenu.addActionItem("Enable System Versioning", systemImage: "clock.badge.checkmark") {
                        sheetState.enableVersioningConnectionID = session.connection.id
                        sheetState.enableVersioningDatabaseName = databaseName
                        sheetState.enableVersioningSchemaName = object.schema
                        sheetState.enableVersioningTableName = object.name
                        sheetState.showEnableVersioningSheet = true
                    }
                }
            }
        }

        menu.addDivider()
        menu.addActionItem("Drop \(object.type.displayName)", systemImage: "trash") {
            let sql = dropStatement(for: object, databaseType: databaseType, includeIfExists: false)
            environmentState.openQueryTab(for: session, presetQuery: sql, database: databaseName)
        }

        if object.type == .table {
            menu.addDivider()
            menu.addActionItem("Properties", systemImage: "info.circle") {
                let value = environmentState.prepareTablePropertiesWindow(
                    connectionSessionID: session.connection.id,
                    schemaName: object.schema,
                    tableName: object.name,
                    databaseType: databaseType
                )
                openWindow(id: TablePropertiesWindow.sceneID, value: value)
            }
        } else if VisualEditorResolver.hasVisualEditor(for: object.type, databaseType: databaseType) {
            menu.addDivider()
            menu.addActionItem("Properties", systemImage: "info.circle") {
                openObjectInDesigner(object, session: session)
            }
        }

        return menu
    }

    func addScriptActions(
        _ actions: [ScriptAction],
        to menu: NSMenu,
        object: SchemaObjectInfo,
        databaseName: String,
        session: ConnectionSession
    ) {
        for action in actions {
            menu.addActionItem(action.title(for: session.connection.databaseType), systemImage: action.systemImage) {
                performScriptAction(action, object: object, databaseName: databaseName, session: session)
            }
        }
    }
}

fileprivate func experimentalObjectGroupCreationTitle(for type: SchemaObjectInfo.ObjectType) -> String? {
    switch type {
    case .table: "New Table"
    case .view: "New View"
    case .materializedView: "New Materialized View"
    case .function: "New Function"
    case .procedure: "New Procedure"
    case .trigger: "New Trigger"
    case .extension: "New Extension"
    case .sequence: "New Sequence"
    case .type: "New Type"
    case .synonym: "New Synonym"
    }
}

fileprivate func experimentalObjectGroupCreationIcon(for type: SchemaObjectInfo.ObjectType) -> String {
    switch type {
    case .table: "tablecells"
    case .view: "eye"
    case .materializedView: "eye"
    case .function: "function"
    case .procedure: "gearshape"
    case .trigger: "bolt"
    case .extension: "puzzlepiece.extension"
    case .sequence: "number"
    case .type: "t.square"
    case .synonym: "arrow.triangle.swap"
    }
}

fileprivate func experimentalObjectGroupCreationSQL(
    for title: String,
    databaseType: DatabaseType,
    schemaName: String
) -> String {
    switch (title, databaseType) {
    case ("New Table", .microsoftSQL):
        "CREATE TABLE [\(schemaName)].[NewTable] (\n    [Id] INT IDENTITY(1,1) PRIMARY KEY,\n    [Name] NVARCHAR(100) NOT NULL\n);\nGO"
    case ("New Table", .postgresql):
        "CREATE TABLE \(schemaName).new_table (\n    id SERIAL PRIMARY KEY,\n    name TEXT NOT NULL\n);"
    case ("New Table", .mysql):
        "CREATE TABLE new_table (\n    id INT AUTO_INCREMENT PRIMARY KEY,\n    name VARCHAR(100) NOT NULL\n);"
    case ("New Table", .sqlite):
        "CREATE TABLE new_table (\n    id INTEGER PRIMARY KEY AUTOINCREMENT,\n    name TEXT NOT NULL\n);"
    case ("New View", .microsoftSQL):
        "CREATE VIEW [\(schemaName)].[NewView]\nAS\n    SELECT * FROM [\(schemaName)].[TableName];\nGO"
    case ("New View", .postgresql):
        "CREATE VIEW \(schemaName).new_view AS\n    SELECT * FROM \(schemaName).table_name;"
    case ("New View", _):
        "CREATE VIEW new_view AS\n    SELECT * FROM table_name;"
    case ("New Materialized View", _):
        "CREATE MATERIALIZED VIEW \(schemaName).new_materialized_view AS\n    SELECT * FROM \(schemaName).table_name;"
    case ("New Function", .microsoftSQL):
        "CREATE FUNCTION [\(schemaName)].[NewFunction]\n(\n    @param1 INT\n)\nRETURNS INT\nAS\nBEGIN\n    RETURN @param1;\nEND;\nGO"
    case ("New Function", .postgresql):
        "CREATE FUNCTION \(schemaName).new_function(param1 INTEGER)\nRETURNS INTEGER\nLANGUAGE plpgsql\nAS $$\nBEGIN\n    RETURN param1;\nEND;\n$$;"
    case ("New Function", _):
        "CREATE FUNCTION new_function(param1 INT)\nRETURNS INT\nDETERMINISTIC\nBEGIN\n    RETURN param1;\nEND;"
    case ("New Procedure", .microsoftSQL):
        "CREATE PROCEDURE [\(schemaName)].[NewProcedure]\n    @param1 INT\nAS\nBEGIN\n    SET NOCOUNT ON;\n    SELECT @param1;\nEND;\nGO"
    case ("New Procedure", _):
        "CREATE PROCEDURE \(schemaName).new_procedure(param1 INTEGER)\nLANGUAGE plpgsql\nAS $$\nBEGIN\n    -- procedure body\nEND;\n$$;"
    case ("New Trigger", .microsoftSQL):
        "CREATE TRIGGER [\(schemaName)].[NewTrigger]\nON [\(schemaName)].[TableName]\nAFTER INSERT\nAS\nBEGIN\n    SET NOCOUNT ON;\n    -- trigger body\nEND;\nGO"
    case ("New Trigger", .postgresql):
        "CREATE TRIGGER new_trigger\n    AFTER INSERT ON \(schemaName).table_name\n    FOR EACH ROW\n    EXECUTE FUNCTION \(schemaName).trigger_function();"
    case ("New Trigger", _):
        "CREATE TRIGGER new_trigger\n    AFTER INSERT ON table_name\n    FOR EACH ROW\nBEGIN\n    -- trigger body\nEND;"
    case ("New Sequence", .microsoftSQL):
        "CREATE SEQUENCE [\(schemaName)].[NewSequence]\n    AS INT\n    START WITH 1\n    INCREMENT BY 1;\nGO"
    case ("New Sequence", _):
        "CREATE SEQUENCE \(schemaName).new_sequence\n    START WITH 1\n    INCREMENT BY 1;"
    case ("New Type", .microsoftSQL):
        "CREATE TYPE [\(schemaName)].[NewType] AS TABLE (\n    [Id] INT,\n    [Name] NVARCHAR(100)\n);\nGO"
    case ("New Type", _):
        "CREATE TYPE \(schemaName).new_type AS (\n    field1 TEXT,\n    field2 INTEGER\n);"
    case ("New Synonym", .microsoftSQL):
        "CREATE SYNONYM [\(schemaName)].[NewSynonym]\n    FOR [\(schemaName)].[TargetObject];\nGO"
    default:
        "-- \(title)"
    }
}
