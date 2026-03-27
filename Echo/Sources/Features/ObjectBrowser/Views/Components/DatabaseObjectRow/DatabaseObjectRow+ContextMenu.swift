import SwiftUI
import PostgresKit

extension DatabaseObjectRow {
    var contextMenuContent: some View {
        buildCanonicalContextMenu()
    }

    @ViewBuilder
    private func buildCanonicalContextMenu() -> some View {
        // Group 2: New actions
        let newItems = computeNewItems()
        ForEach(newItems) { item in
            contextMenuButton(item)
        }

        // Divider between New and Open/View
        let openItems = computeOpenViewItems()
        let editItems = computeEditItems()
        let copyItems = computeCopyItems()
        if !newItems.isEmpty && (!openItems.isEmpty || !editItems.isEmpty || !copyItems.isEmpty) {
            Divider()
        }

        // Group 3: Open / View
        ForEach(openItems) { item in
            contextMenuButton(item)
        }

        // Group 4: Edit / Rename
        ForEach(editItems) { item in
            contextMenuButton(item)
        }

        // Group 5: Copy / Pin
        ForEach(copyItems) { item in
            contextMenuButton(item)
        }

        // Divider between Open/Edit/Copy and Script as
        let scriptActions = scriptActionsForCurrentContext()
        if (!openItems.isEmpty || !editItems.isEmpty || !copyItems.isEmpty) && !scriptActions.isEmpty {
            Divider()
        }
        if newItems.isEmpty && openItems.isEmpty && editItems.isEmpty && copyItems.isEmpty && !scriptActions.isEmpty {
            // no divider needed before script-as if nothing above
        }

        // Group 6: Script as
        if !scriptActions.isEmpty {
            Menu("Script as", systemImage: "scroll") {
                scriptAsMenuContent(scriptActions)
            }
        }

        // Divider between Script as and Maintenance
        let maintenanceItems = computeMaintenanceItems()
        if !scriptActions.isEmpty && !maintenanceItems.isEmpty {
            Divider()
        }

        // Group 7: Maintenance
        ForEach(maintenanceItems) { item in
            contextMenuButton(item)
        }

        // Divider before Destructive
        let destructiveItems = computeDestructiveItems()
        let propertiesItems = computePropertiesItems()
        let previousBeforeDestructive = !scriptActions.isEmpty || !maintenanceItems.isEmpty
            || !openItems.isEmpty || !editItems.isEmpty || !copyItems.isEmpty || !newItems.isEmpty
        if previousBeforeDestructive && !destructiveItems.isEmpty {
            Divider()
        }

        // Group 9: Destructive
        ForEach(destructiveItems) { item in
            contextMenuButton(item)
        }

        // Divider before Properties — ALWAYS last
        let previousBeforeProps = previousBeforeDestructive || !destructiveItems.isEmpty
        if previousBeforeProps && !propertiesItems.isEmpty {
            Divider()
        }

        // Group 10: Properties — ALWAYS last
        ForEach(propertiesItems) { item in
            contextMenuButton(item)
        }
    }

    private func contextMenuButton(_ item: ContextMenuActionItem) -> some View {
        Button(role: item.role) {
            item.action()
        } label: {
            Label(item.title, systemImage: item.systemImage)
        }
        .disabled(item.isDisabled)
    }

    @ViewBuilder
    private func scriptAsMenuContent(_ actions: [ScriptAction]) -> some View {
        let readActions = actions.filter { $0.isReadGroup }
        let createActions = actions.filter { $0.isCreateModifyGroup }
        let writeActions = actions.filter { $0.isWriteGroup }
        let executeActions = actions.filter { $0.isExecuteGroup }
        let destroyActions = actions.filter { $0.isDestroyGroup }

        ForEach(readActions, id: \.identifier) { action in
            scriptActionButton(action)
        }
        if !readActions.isEmpty && !createActions.isEmpty {
            Divider()
        }
        ForEach(createActions, id: \.identifier) { action in
            scriptActionButton(action)
        }
        if !createActions.isEmpty && !writeActions.isEmpty {
            Divider()
        }
        ForEach(writeActions, id: \.identifier) { action in
            scriptActionButton(action)
        }
        if !writeActions.isEmpty && !executeActions.isEmpty {
            Divider()
        }
        if writeActions.isEmpty && !createActions.isEmpty && !executeActions.isEmpty {
            Divider()
        }
        ForEach(executeActions, id: \.identifier) { action in
            scriptActionButton(action)
        }

        let lastNonDestroyGroup = !executeActions.isEmpty || !writeActions.isEmpty
            || !createActions.isEmpty || !readActions.isEmpty
        if lastNonDestroyGroup && !destroyActions.isEmpty {
            Divider()
        }
        ForEach(destroyActions, id: \.identifier) { action in
            scriptActionButton(action)
        }
    }

    private func scriptActionButton(_ action: ScriptAction) -> some View {
        Button {
            performScriptAction(action)
        } label: {
            Label(scriptTitle(for: action), systemImage: scriptSystemImage(for: action))
        }
    }

    // MARK: - Canonical Group Computation

    /// Group 2: New actions
    private func computeNewItems() -> [ContextMenuActionItem] {
        var items: [ContextMenuActionItem] = []

        items.append(
            ContextMenuActionItem(
                id: "newQuery",
                title: "New Query",
                systemImage: "doc.text",
                role: nil,
                action: { openNewQueryTab() }
            )
        )

        if object.type == .extension {
            items.append(
                ContextMenuActionItem(
                    id: "newExtension",
                    title: "New Extension",
                    systemImage: "puzzlepiece.extension",
                    role: nil,
                    action: {
                        let dbName = databaseName ?? connection.database
                        environmentState.openExtensionsManagerTab(connectionID: connection.id, databaseName: dbName)
                    }
                )
            )
        }

        return items
    }

    /// Group 3: Open / View
    private func computeOpenViewItems() -> [ContextMenuActionItem] {
        var items: [ContextMenuActionItem] = []

        if object.type == .table || object.type == .view || object.type == .materializedView {
            items.append(
                ContextMenuActionItem(
                    id: "openData",
                    title: "Open Data",
                    systemImage: "tablecells",
                    role: nil,
                    action: { openDataPreview() }
                )
            )
        }

        if object.type == .table || object.type == .extension {
            items.append(
                ContextMenuActionItem(
                    id: "viewStructure",
                    title: "View Structure",
                    systemImage: object.type == .extension ? "puzzlepiece.fill" : "square.stack.3d.up",
                    role: nil,
                    action: { openStructureTab() }
                )
            )
        }

        if connection.databaseType == .microsoftSQL {
            items.append(
                ContextMenuActionItem(
                    id: "viewDependencies",
                    title: "View Dependencies",
                    systemImage: "arrow.triangle.branch",
                    role: nil,
                    action: { openDependenciesQuery() }
                )
            )
        }

        if supportsDiagram {
            items.append(
                ContextMenuActionItem(
                    id: "showDiagram",
                    title: "Show Diagram",
                    systemImage: "rectangle.connected.to.line.below",
                    role: nil,
                    action: { openRelationsDiagram() }
                )
            )
        }

        return items
    }

    /// Group 4: Edit / Rename
    private func computeEditItems() -> [ContextMenuActionItem] {
        var items: [ContextMenuActionItem] = []

        if object.type == .procedure || object.type == .function {
            items.append(
                ContextMenuActionItem(
                    id: "modify",
                    title: "Modify",
                    systemImage: "pencil.and.outline",
                    role: nil,
                    action: { openModifyScript() }
                )
            )
        }

        items.append(
            ContextMenuActionItem(
                id: "renameObject",
                title: connection.databaseType == .sqlite ? "Rename (Limited)" : "Rename",
                systemImage: "character.cursor.ibeam",
                role: nil,
                isDisabled: !canModifySchema,
                action: { initiateRename() }
            )
        )

        return items
    }

    /// Group 5: Copy / Pin
    private func computeCopyItems() -> [ContextMenuActionItem] {
        [
            ContextMenuActionItem(
                id: "pinToggle",
                title: isPinned ? "Unpin" : "Pin",
                systemImage: isPinned ? "pin.slash" : "pin",
                role: nil,
                action: { onTogglePin() }
            )
        ]
    }

    /// Group 7: Maintenance
    private func computeMaintenanceItems() -> [ContextMenuActionItem] {
        var items: [ContextMenuActionItem] = []

        if connection.databaseType == .microsoftSQL {
            items.append(
                ContextMenuActionItem(
                    id: "generateScripts",
                    title: "Generate Scripts...",
                    systemImage: "script.badge.plus",
                    role: nil,
                    action: { showGenerateScriptsWizard = true }
                )
            )
        }

        if supportsBulkImport {
            items.append(
                ContextMenuActionItem(
                    id: "importData",
                    title: "Import Data",
                    systemImage: "square.and.arrow.down",
                    role: nil,
                    action: { showBulkImportSheet = true }
                )
            )
        }

        if object.type == .table || object.type == .view {
            items.append(
                ContextMenuActionItem(
                    id: "exportData",
                    title: "Export Data",
                    systemImage: "square.and.arrow.up",
                    role: nil,
                    action: { showExportSheet = true }
                )
            )
        }

        // Cluster (PostgreSQL tables only)
        if object.type == .table && connection.databaseType == .postgresql {
            items.append(
                ContextMenuActionItem(
                    id: "cluster",
                    title: "Cluster",
                    systemImage: "arrow.triangle.2.circlepath",
                    role: nil,
                    action: { clusterTable() }
                )
            )
        }

        // Temporal table actions
        if object.type == .table && connection.databaseType == .microsoftSQL {
            if object.isSystemVersioned == true {
                items.append(
                    ContextMenuActionItem(
                        id: "queryHistory",
                        title: "Query History...",
                        systemImage: "clock.arrow.circlepath",
                        role: nil,
                        action: { openTemporalHistoryQuery() }
                    )
                )
            }
            if object.isSystemVersioned != true && object.isHistoryTable != true {
                items.append(
                    ContextMenuActionItem(
                        id: "enableVersioning",
                        title: "Enable System Versioning...",
                        systemImage: "clock.badge.checkmark",
                        role: nil,
                        action: {
                            sheetState.enableVersioningConnectionID = connection.id
                            sheetState.enableVersioningDatabaseName = databaseName
                            sheetState.enableVersioningSchemaName = object.schema
                            sheetState.enableVersioningTableName = object.name
                            sheetState.showEnableVersioningSheet = true
                        }
                    )
                )
            }
        }

        return items
    }

    private func clusterTable() {
        guard let session = environmentState.sessionGroup.sessionForConnection(connection.id) else { return }
        Task {
            let handle = AppDirector.shared.activityEngine.begin("Clustering \(object.name)", connectionSessionID: session.id)
            do {
                guard let pg = session.session as? PostgresSession else { return }
                try await pg.client.admin.clusterTable(table: object.name, index: nil, schema: object.schema)
                handle.succeed()
            } catch {
                handle.fail(error.localizedDescription)
            }
        }
    }

    private func openTemporalHistoryQuery() {
        let qualified = "[\(object.schema)].[\(object.name)]"
        let sql = "SELECT * FROM \(qualified) FOR SYSTEM_TIME ALL ORDER BY ValidFrom DESC;"
        environmentState.openQueryTab(presetQuery: sql)
    }

    /// Group 9: Properties
    private func computePropertiesItems() -> [ContextMenuActionItem] {
        var items: [ContextMenuActionItem] = []

        if object.type == .table {
            items.append(
                ContextMenuActionItem(
                    id: "tableProperties",
                    title: "Properties",
                    systemImage: "info.circle",
                    role: nil,
                    action: { openTableProperties() }
                )
            )
        }

        return items
    }

    /// Group 10: Destructive
    private func computeDestructiveItems() -> [ContextMenuActionItem] {
        var items: [ContextMenuActionItem] = []

        if supportsTruncateTable {
            items.append(
                ContextMenuActionItem(
                    id: "truncateTable",
                    title: "Truncate Table",
                    systemImage: "xmark.bin",
                    role: .destructive,
                    isDisabled: !canModifySchema,
                    action: { initiateTruncate() }
                )
            )
        }

        items.append(
            ContextMenuActionItem(
                id: "dropObject",
                title: "Drop",
                systemImage: "trash",
                role: .destructive,
                isDisabled: !canModifySchema,
                action: { initiateDrop(includeIfExists: false) }
            )
        )

        return items
    }

}
