import SwiftUI
import EchoSense

extension ObjectBrowserSidebarView {

    // MARK: - Object Group Context Menu

    @ViewBuilder
    func objectGroupContextMenu(type: SchemaObjectInfo.ObjectType, database: DatabaseInfo, session: ConnectionSession) -> some View {
        let connID = session.connection.id

        // Group 1: Refresh
        Button {
            viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: true)
            Task {
                let handle = AppDirector.shared.activityEngine.begin("Refreshing \(type.pluralDisplayName)", connectionSessionID: session.id)
                await environmentState.loadSchemaForDatabase(database.name, connectionSession: session)
                handle.succeed()
                viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: false)
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }

        // Group 2: New
        if let title = objectGroupCreationTitle(for: type) {
            Button {
                if type == .extension {
                    environmentState.openExtensionsManagerTab(connectionID: connID, databaseName: database.name)
                } else {
                    let schemaName = session.connection.databaseType == .microsoftSQL ? "dbo" : "public"
                    let sql = objectGroupCreationSQL(for: title, databaseType: session.connection.databaseType, schemaName: schemaName)
                    environmentState.openQueryTab(for: session, presetQuery: sql, database: database.name)
                }
            } label: {
                Label(title, systemImage: objectGroupCreationIcon(for: type))
            }
        }
    }

    func objectGroupCreationTitle(for type: SchemaObjectInfo.ObjectType) -> String? {
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

    func objectGroupCreationIcon(for type: SchemaObjectInfo.ObjectType) -> String {
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

    func objectGroupCreationSQL(for title: String, databaseType: DatabaseType, schemaName: String) -> String {
        switch (title, databaseType) {
        case ("New Table", .microsoftSQL):
            return "CREATE TABLE [\(schemaName)].[NewTable] (\n    [Id] INT IDENTITY(1,1) PRIMARY KEY,\n    [Name] NVARCHAR(100) NOT NULL\n);\nGO"
        case ("New Table", .postgresql):
            return "CREATE TABLE \(schemaName).new_table (\n    id SERIAL PRIMARY KEY,\n    name TEXT NOT NULL\n);"
        case ("New Table", .mysql):
            return "CREATE TABLE new_table (\n    id INT AUTO_INCREMENT PRIMARY KEY,\n    name VARCHAR(100) NOT NULL\n);"
        case ("New Table", .sqlite):
            return "CREATE TABLE new_table (\n    id INTEGER PRIMARY KEY AUTOINCREMENT,\n    name TEXT NOT NULL\n);"
        case ("New View", .microsoftSQL):
            return "CREATE VIEW [\(schemaName)].[NewView]\nAS\n    SELECT * FROM [\(schemaName)].[TableName];\nGO"
        case ("New View", .postgresql):
            return "CREATE VIEW \(schemaName).new_view AS\n    SELECT * FROM \(schemaName).table_name;"
        case ("New View", _):
            return "CREATE VIEW new_view AS\n    SELECT * FROM table_name;"
        case ("New Materialized View", _):
            return "CREATE MATERIALIZED VIEW \(schemaName).new_materialized_view AS\n    SELECT * FROM \(schemaName).table_name;"
        case ("New Function", .microsoftSQL):
            return "CREATE FUNCTION [\(schemaName)].[NewFunction]\n(\n    @param1 INT\n)\nRETURNS INT\nAS\nBEGIN\n    RETURN @param1;\nEND;\nGO"
        case ("New Function", .postgresql):
            return "CREATE FUNCTION \(schemaName).new_function(param1 INTEGER)\nRETURNS INTEGER\nLANGUAGE plpgsql\nAS $$\nBEGIN\n    RETURN param1;\nEND;\n$$;"
        case ("New Function", _):
            return "CREATE FUNCTION new_function(param1 INT)\nRETURNS INT\nDETERMINISTIC\nBEGIN\n    RETURN param1;\nEND;"
        case ("New Procedure", .microsoftSQL):
            return "CREATE PROCEDURE [\(schemaName)].[NewProcedure]\n    @param1 INT\nAS\nBEGIN\n    SET NOCOUNT ON;\n    SELECT @param1;\nEND;\nGO"
        case ("New Procedure", _):
            return "CREATE PROCEDURE \(schemaName).new_procedure(param1 INTEGER)\nLANGUAGE plpgsql\nAS $$\nBEGIN\n    -- procedure body\nEND;\n$$;"
        case ("New Trigger", .microsoftSQL):
            return "CREATE TRIGGER [\(schemaName)].[NewTrigger]\nON [\(schemaName)].[TableName]\nAFTER INSERT\nAS\nBEGIN\n    SET NOCOUNT ON;\n    -- trigger body\nEND;\nGO"
        case ("New Trigger", .postgresql):
            return "CREATE TRIGGER new_trigger\n    AFTER INSERT ON \(schemaName).table_name\n    FOR EACH ROW\n    EXECUTE FUNCTION \(schemaName).trigger_function();"
        case ("New Trigger", _):
            return "CREATE TRIGGER new_trigger\n    AFTER INSERT ON table_name\n    FOR EACH ROW\nBEGIN\n    -- trigger body\nEND;"
        case ("New Sequence", .microsoftSQL):
            return "CREATE SEQUENCE [\(schemaName)].[NewSequence]\n    AS INT\n    START WITH 1\n    INCREMENT BY 1;\nGO"
        case ("New Sequence", _):
            return "CREATE SEQUENCE \(schemaName).new_sequence\n    START WITH 1\n    INCREMENT BY 1;"
        case ("New Type", .microsoftSQL):
            return "CREATE TYPE [\(schemaName)].[NewType] AS TABLE (\n    [Id] INT,\n    [Name] NVARCHAR(100)\n);\nGO"
        case ("New Type", _):
            return "CREATE TYPE \(schemaName).new_type AS (\n    field1 TEXT,\n    field2 INTEGER\n);"
        case ("New Synonym", .microsoftSQL):
            return "CREATE SYNONYM [\(schemaName)].[NewSynonym]\n    FOR [\(schemaName)].[TargetObject];\nGO"
        case ("New Schema", _):
            return "CREATE SCHEMA new_schema;"
        default:
            return "-- \(title)"
        }
    }

    // MARK: - Databases Folder Context Menu

    @ViewBuilder
    func databasesFolderContextMenu(session: ConnectionSession) -> some View {
        // Group 1: Refresh
        Button {
            Task {
                let handle = AppDirector.shared.activityEngine.begin("Refreshing databases", connectionSessionID: session.id)
                await environmentState.refreshDatabaseStructure(for: session.id, scope: .full)
                handle.succeed()
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }

        // Group 2: New
        Button {
            viewModel.newDatabaseConnectionID = session.connection.id
            viewModel.showNewDatabaseSheet = true
        } label: {
            Label("New Database", systemImage: "cylinder")
        }
        .disabled(!(session.permissions?.canCreateDatabases ?? true))

        if session.connection.databaseType == .microsoftSQL {
            Divider()

            Button {
                viewModel.attachConnectionID = session.connection.id
                viewModel.showAttachSheet = true
            } label: {
                Label("Attach Database...", systemImage: "externaldrive.badge.plus")
            }
        }
    }

    // MARK: - Server Context Menu

    @ViewBuilder
    func serverContextMenu(session: ConnectionSession) -> some View {
        // Group 1: Refresh
        Button {
            Task {
                let handle = AppDirector.shared.activityEngine.begin("Refreshing all databases", connectionSessionID: session.id)
                await environmentState.refreshDatabaseStructure(for: session.id, scope: .full)
                handle.succeed()
            }
        } label: {
            Label("Refresh All", systemImage: "arrow.clockwise")
        }

        // Group 2: New
        Button {
            environmentState.openQueryTab(for: session)
        } label: {
            Label("New Query", systemImage: "doc.text")
        }

        Divider()

        // Group 3: Open / View
        Button {
            environmentState.openActivityMonitorTab(connectionID: session.connection.id)
        } label: {
            Label("Activity Monitor", systemImage: "gauge.with.dots.needle.33percent")
        }

        Divider()

        // Group 7: Maintenance
        Button {
            environmentState.openMaintenanceTab(connectionID: session.connection.id)
        } label: {
            Label("Maintenance", systemImage: "wrench.and.screwdriver")
        }

        if session.connection.databaseType == .microsoftSQL {
            Button {
                viewModel.databaseMailConnectionID = session.connection.id
                viewModel.showDatabaseMailSheet = true
            } label: {
                Label("Database Mail", systemImage: "envelope")
            }

            Button {
                viewModel.cmsConnectionID = session.connection.id
                viewModel.showCMSSheet = true
            } label: {
                Label("Central Management Servers", systemImage: "server.rack")
            }

            Button {
                environmentState.openExtendedEventsTab(connectionID: session.connection.id)
            } label: {
                Label("Extended Events", systemImage: "waveform.path.ecg")
            }

            Button {
                environmentState.openAvailabilityGroupsTab(connectionID: session.connection.id)
            } label: {
                Label("Availability Groups", systemImage: "server.rack")
            }
        }

        Divider()

        // Group 9: Properties
        if session.connection.databaseType == .microsoftSQL {
            Button {
                let value = environmentState.prepareServerEditorWindow(
                    connectionSessionID: session.connection.id
                )
                openWindow(id: ServerEditorWindow.sceneID, value: value)
            } label: {
                Label("Properties", systemImage: "info.circle")
            }
        }

        Divider()

        // Group 10: Destructive
        Button(role: .destructive) {
            Task {
                await environmentState.disconnectSession(withID: session.id)
            }
        } label: {
            Label("Disconnect", systemImage: "xmark.circle")
        }
    }

}
