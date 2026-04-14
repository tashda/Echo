import SwiftUI
import AppKit
import PostgresKit

/// NSMenu builder for DatabaseObjectRow — only called on right-click, never during body evaluation.
extension DatabaseObjectRow {

    @MainActor
    func buildNSMenu() -> NSMenu {
        let menu = NSMenu()
        let dbType = connection.databaseType

        // MARK: - Group 2: New
        menu.addActionItem("New Query", systemImage: "doc.text") { [self] in
            openNewQueryTab()
        }

        if object.type == .extension {
            menu.addActionItem("New Extension", systemImage: "puzzlepiece.extension") { [self] in
                let dbName = databaseName ?? connection.database
                environmentState.openExtensionsManagerTab(connectionID: connection.id, databaseName: dbName)
            }
        }

        menu.addDivider()

        // MARK: - Group 3: Open / View
        if object.type == .table || object.type == .view || object.type == .materializedView {
            menu.addActionItem("Data", systemImage: "tablecells") { [self] in
                openDataPreview()
            }
        }

        if object.type == .table || object.type == .extension {
            menu.addActionItem("Structure", systemImage: object.type == .extension ? "puzzlepiece.fill" : "square.stack.3d.up") { [self] in
                openStructureTab()
            }
        }

        if object.type == .table {
            menu.addActionItem("Diagram", systemImage: "rectangle.connected.to.line.below") { [self] in
                openRelationsDiagram()
            }
        }

        // MARK: - Group 4: Edit / Rename
        if (object.type == .procedure || object.type == .function) && !object.parameters.isEmpty {
            menu.addActionItem("Execute", systemImage: "play.circle") { [self] in
                showExecuteProcedureSheet = true
            }
        }

        if VisualEditorResolver.hasVisualEditor(for: object.type, databaseType: dbType) {
            menu.addActionItem("Edit in Designer", systemImage: "rectangle.and.pencil.and.ellipsis") { [self] in
                openVisualEditor()
            }
        }

        if object.type == .procedure || object.type == .function {
            menu.addActionItem("Modify", systemImage: "pencil.and.outline") { [self] in
                openModifyScript()
            }
        }

        let renameItem = menu.addActionItem(dbType == .sqlite ? "Rename (Limited)" : "Rename", systemImage: "character.cursor.ibeam") { [self] in
            initiateRename()
        }
        renameItem.isEnabled = canModifySchema

        // MARK: - Group 5: Pin
        menu.addActionItem(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin") { [self] in
            onTogglePin()
        }

        // MARK: - Group 6: Script As
        let scriptActions = scriptActionsForCurrentContext()
        if !scriptActions.isEmpty {
            menu.addDivider()

            menu.addSubmenu("Script as", systemImage: "scroll") { [self] sub in
                let readActions = scriptActions.filter { $0.isReadGroup }
                let createActions = scriptActions.filter { $0.isCreateModifyGroup }
                let writeActions = scriptActions.filter { $0.isWriteGroup }
                let executeActions = scriptActions.filter { $0.isExecuteGroup }
                let destroyActions = scriptActions.filter { $0.isDestroyGroup }

                @MainActor
                func addGroup(_ actions: [ScriptAction], to target: NSMenu) {
                    for action in actions {
                        target.addActionItem(scriptTitle(for: action), systemImage: scriptSystemImage(for: action)) { [self] in
                            performScriptAction(action)
                        }
                    }
                }

                addGroup(readActions, to: sub)
                if !readActions.isEmpty && !createActions.isEmpty { sub.addDivider() }
                addGroup(createActions, to: sub)
                if !createActions.isEmpty && !writeActions.isEmpty { sub.addDivider() }
                addGroup(writeActions, to: sub)
                if !writeActions.isEmpty && !executeActions.isEmpty { sub.addDivider() }
                if writeActions.isEmpty && !createActions.isEmpty && !executeActions.isEmpty { sub.addDivider() }
                addGroup(executeActions, to: sub)
                let hasNonDestroy = !executeActions.isEmpty || !writeActions.isEmpty || !createActions.isEmpty || !readActions.isEmpty
                if hasNonDestroy && !destroyActions.isEmpty { sub.addDivider() }
                addGroup(destroyActions, to: sub)
            }
        }

        // MARK: - Group 7: Tasks
        let hasTaskItems = dbType == .microsoftSQL
            || object.type == .table
            || object.type == .view
        if hasTaskItems {
            menu.addDivider()
            menu.addSubmenu("Tasks", systemImage: "checklist") { [self] sub in
                if dbType == .microsoftSQL {
                    sub.addActionItem("Generate Scripts", systemImage: "applescript") { [self] in
                        showGenerateScriptsWizard = true
                    }
                }

                if object.type == .table {
                    sub.addActionItem("Import Data", systemImage: "square.and.arrow.down") { [self] in
                        showBulkImportSheet = true
                    }
                }

                if object.type == .table || object.type == .view {
                    sub.addActionItem("Export Data", systemImage: "square.and.arrow.up") { [self] in
                        showExportSheet = true
                    }
                }

                if object.type == .table && dbType == .postgresql {
                    sub.addActionItem("Cluster", systemImage: "arrow.triangle.2.circlepath") { [self] in
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
                }

                if object.type == .table && dbType == .microsoftSQL {
                    if object.isSystemVersioned == true {
                        sub.addActionItem("Query History", systemImage: "clock.arrow.circlepath") { [self] in
                            let qualified = "[\(object.schema)].[\(object.name)]"
                            let sql = "SELECT * FROM \(qualified) FOR SYSTEM_TIME ALL ORDER BY ValidFrom DESC;"
                            environmentState.openQueryTab(presetQuery: sql)
                        }
                    }
                    if object.isSystemVersioned != true && object.isHistoryTable != true {
                        sub.addActionItem("Enable System Versioning", systemImage: "clock.badge.checkmark") { [self] in
                            sheetState.enableVersioningConnectionID = connection.id
                            sheetState.enableVersioningDatabaseName = databaseName
                            sheetState.enableVersioningSchemaName = object.schema
                            sheetState.enableVersioningTableName = object.name
                            sheetState.showEnableVersioningSheet = true
                        }
                    }
                }
            }
        }

        // MARK: - Group 9: Destructive
        menu.addDivider()

        if supportsTruncateTable {
            let item = menu.addActionItem("Truncate Table", systemImage: "xmark.bin") { [self] in
                initiateTruncate()
            }
            item.isEnabled = canModifySchema
        }

        let dropItem = menu.addActionItem("Drop \(object.type.displayName)", systemImage: "trash") { [self] in
            initiateDrop(includeIfExists: false)
        }
        dropItem.isEnabled = canModifySchema

        // MARK: - Group 10: Properties
        if object.type == .table {
            menu.addDivider()
            menu.addActionItem("Properties", systemImage: "info.circle") { [self] in
                openTableProperties()
            }
        }

        if VisualEditorResolver.hasVisualEditor(for: object.type, databaseType: dbType) {
            menu.addDivider()
            menu.addActionItem("Properties", systemImage: "info.circle") { [self] in
                openVisualEditor()
            }
        }

        return menu
    }
}
