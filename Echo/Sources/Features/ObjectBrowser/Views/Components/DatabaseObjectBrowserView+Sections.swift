import SwiftUI

extension DatabaseObjectBrowserView {
    @ViewBuilder
    func pinnedSection(_ pinnedList: [SchemaObjectInfo]) -> some View {
        let expandedBinding = Binding<Bool>(
            get: { isPinnedSectionExpanded },
            set: { isPinnedSectionExpanded = $0 }
        )

        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isPinnedSectionExpanded.toggle() }
            } label: {
                SidebarRow(
                    depth: 2,
                    icon: .system("pin"),
                    label: "Pinned",
                    isExpanded: expandedBinding,
                    iconColor: ExplorerSidebarPalette.monochrome
                ) {
                    Text("\(pinnedList.count)")
                        .font(SidebarRowConstants.trailingFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }

            if isPinnedSectionExpanded {
                ForEach(pinnedList, id: \.id) { object in
                    DatabaseObjectRow(
                        object: object,
                        displayName: displayName(for: object),
                        connection: connection,
                        databaseName: database.name,
                        showColumns: shouldShowColumns(for: object),
                        isExpanded: expansionBinding(for: object.id),
                        isPinned: true,
                        onTogglePin: { togglePin(for: object) },
                        onTriggerTableTap: object.type == .trigger ? { revealTable(fullName: $0) } : nil
                    )
                    .id("pinned-\(object.id)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    func typeSection(_ type: SchemaObjectInfo.ObjectType, _ objects: [SchemaObjectInfo]) -> some View {
        let isExpanded = expandedObjectGroups.contains(type)
        let colored = projectStore.globalSettings.sidebarColoredIcons
        let expandedBinding = Binding<Bool>(
            get: { isExpanded },
            set: { _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    if isExpanded { expandedObjectGroups.remove(type) }
                    else { expandedObjectGroups.insert(type) }
                }
            }
        )

        VStack(alignment: .leading, spacing: 0) {
            Button {
                expandedBinding.wrappedValue.toggle()
            } label: {
                SidebarRow(
                    depth: 2,
                    icon: .system(type.systemImage),
                    label: type.pluralDisplayName,
                    isExpanded: expandedBinding,
                    iconColor: ExplorerSidebarPalette.objectGroupIconColor(for: type, colored: colored)
                ) {
                    Text("\(objects.count)")
                        .font(SidebarRowConstants.trailingFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .contextMenu {
                typeSectionContextMenu(type)
            }

            if isExpanded {
                ForEach(objects, id: \.id) { object in
                    DatabaseObjectRow(
                        object: object,
                        displayName: displayName(for: object),
                        connection: connection,
                        databaseName: database.name,
                        showColumns: shouldShowColumns(for: object),
                        isExpanded: expansionBinding(for: object.id),
                        isPinned: pinnedObjectIDs.contains(object.id),
                        onTogglePin: { togglePin(for: object) },
                        onTriggerTableTap: object.type == .trigger ? { revealTable(fullName: $0) } : nil
                    )
                    .equatable()
                    .id(object.id)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Folder Context Menu

    @ViewBuilder
    func typeSectionContextMenu(_ type: SchemaObjectInfo.ObjectType) -> some View {
        let creationTitle = creationTitle(for: type)
        if let creationTitle {
            Button {
                let session = environmentState.sessionGroup.activeSessions.first {
                    $0.connection.id == connection.id
                }
                guard let session else { return }
                let schemaName = selectedSchemaName ?? (connection.databaseType == .microsoftSQL ? "dbo" : "public")
                let sql = creationTemplateSQL(for: creationTitle, databaseType: connection.databaseType, schemaName: schemaName)
                environmentState.openQueryTab(for: session, presetQuery: sql, database: database.name)
            } label: {
                Label(creationTitle, systemImage: "plus")
            }
            Divider()
        }

        Button {
            let session = environmentState.sessionGroup.activeSessions.first {
                $0.connection.id == connection.id
            }
            guard let session else { return }
            Task {
                await environmentState.loadSchemaForDatabase(database.name, connectionSession: session)
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
    }

    private func creationTitle(for type: SchemaObjectInfo.ObjectType) -> String? {
        switch type {
        case .table: "New Table"
        case .view: "New View"
        case .materializedView: "New Materialized View"
        case .function: "New Function"
        case .procedure: "New Procedure"
        case .trigger: "New Trigger"
        case .extension: "New Extension"
        }
    }

    private func creationTemplateSQL(for title: String, databaseType: DatabaseType, schemaName: String?) -> String {
        let schema = schemaName ?? "dbo"
        switch (title, databaseType) {
        case ("New Table", .microsoftSQL):
            return "CREATE TABLE [\(schema)].[NewTable] (\n    [Id] INT IDENTITY(1,1) PRIMARY KEY,\n    [Name] NVARCHAR(100) NOT NULL\n);\nGO"
        case ("New Table", .postgresql):
            return "CREATE TABLE \(schema).new_table (\n    id SERIAL PRIMARY KEY,\n    name TEXT NOT NULL\n);"
        case ("New Table", .mysql):
            return "CREATE TABLE new_table (\n    id INT AUTO_INCREMENT PRIMARY KEY,\n    name VARCHAR(100) NOT NULL\n);"
        case ("New View", .microsoftSQL):
            return "CREATE VIEW [\(schema)].[NewView]\nAS\n    SELECT * FROM [\(schema)].[TableName];\nGO"
        case ("New View", .postgresql):
            return "CREATE VIEW \(schema).new_view AS\n    SELECT * FROM \(schema).table_name;"
        case ("New View", .mysql):
            return "CREATE VIEW new_view AS\n    SELECT * FROM table_name;"
        case ("New Materialized View", _):
            return "CREATE MATERIALIZED VIEW \(schema).new_materialized_view AS\n    SELECT * FROM \(schema).table_name;"
        case ("New Function", .microsoftSQL):
            return "CREATE FUNCTION [\(schema)].[NewFunction]\n(\n    @param1 INT\n)\nRETURNS INT\nAS\nBEGIN\n    RETURN @param1;\nEND;\nGO"
        case ("New Function", .postgresql):
            return "CREATE FUNCTION \(schema).new_function(param1 INTEGER)\nRETURNS INTEGER\nLANGUAGE plpgsql\nAS $$\nBEGIN\n    RETURN param1;\nEND;\n$$;"
        case ("New Function", .mysql):
            return "CREATE FUNCTION new_function(param1 INT)\nRETURNS INT\nDETERMINISTIC\nBEGIN\n    RETURN param1;\nEND;"
        case ("New Procedure", .microsoftSQL):
            return "CREATE PROCEDURE [\(schema)].[NewProcedure]\n    @param1 INT\nAS\nBEGIN\n    SET NOCOUNT ON;\n    SELECT @param1;\nEND;\nGO"
        case ("New Procedure", .postgresql):
            return "CREATE PROCEDURE \(schema).new_procedure(param1 INTEGER)\nLANGUAGE plpgsql\nAS $$\nBEGIN\n    -- procedure body\nEND;\n$$;"
        case ("New Trigger", .microsoftSQL):
            return "CREATE TRIGGER [\(schema)].[NewTrigger]\nON [\(schema)].[TableName]\nAFTER INSERT\nAS\nBEGIN\n    SET NOCOUNT ON;\n    -- trigger body\nEND;\nGO"
        case ("New Trigger", .postgresql):
            return "CREATE TRIGGER new_trigger\n    AFTER INSERT ON \(schema).table_name\n    FOR EACH ROW\n    EXECUTE FUNCTION \(schema).trigger_function();"
        case ("New Trigger", .mysql):
            return "CREATE TRIGGER new_trigger\n    AFTER INSERT ON table_name\n    FOR EACH ROW\nBEGIN\n    -- trigger body\nEND;"
        case ("New Extension", _):
            return "CREATE EXTENSION IF NOT EXISTS extension_name;"
        default:
            return "-- New \(title)"
        }
    }
}
