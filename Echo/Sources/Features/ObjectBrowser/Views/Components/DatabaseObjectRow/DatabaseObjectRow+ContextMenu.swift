import SwiftUI

extension DatabaseObjectRow {
    var contextMenuContent: some View {
        let generalItems = computeGeneralMenuItems()
        let scriptActions = scriptActionsForCurrentContext()
        let administrativeItems = computeAdministrativeMenuItems()
        return buildContextMenu(
            generalItems: generalItems,
            scriptActions: scriptActions,
            administrativeItems: administrativeItems
        )
    }

    @ViewBuilder
    private func buildContextMenu(
        generalItems: [ContextMenuActionItem],
        scriptActions: [ScriptAction],
        administrativeItems: [ContextMenuActionItem]
    ) -> some View {
        ForEach(generalItems) { item in
            Button(role: item.role) {
                item.action()
            } label: {
                Label(item.title, systemImage: item.systemImage)
            }
        }

        if !scriptActions.isEmpty {
            Divider()
            Menu("Script as", systemImage: "scroll") {
                ForEach(scriptActions, id: \.identifier) { action in
                    Button {
                        performScriptAction(action)
                    } label: {
                        Label(scriptTitle(for: action), systemImage: scriptSystemImage(for: action))
                    }
                }
            }
        }

        if !administrativeItems.isEmpty {
            Divider()
            ForEach(administrativeItems) { item in
                Button(role: item.role) {
                    item.action()
                } label: {
                    Label(item.title, systemImage: item.systemImage)
                }
            }
        }
    }

    internal struct ContextMenuActionItem: Identifiable {
        let id: String
        let title: String
        let systemImage: String
        let role: ButtonRole?
        let action: () -> Void

        init(
            id: String? = nil,
            title: String,
            systemImage: String,
            role: ButtonRole?,
            action: @escaping () -> Void
        ) {
            self.id = id ?? title
            self.title = title
            self.systemImage = systemImage
            self.role = role
            self.action = action
        }
    }

    internal enum ScriptAction {
        case create
        case createOrReplace
        case alter
        case alterTable
        case drop
        case dropIfExists
        case select
        case selectLimited(Int)
        case execute
        case insert
        case update
        case delete

        var identifier: String {
            switch self {
            case .create: return "create"
            case .createOrReplace: return "createOrReplace"
            case .alter: return "alter"
            case .alterTable: return "alterTable"
            case .drop: return "drop"
            case .dropIfExists: return "dropIfExists"
            case .select: return "select"
            case .selectLimited(let limit): return "selectLimited_\(limit)"
            case .execute: return "execute"
            case .insert: return "insert"
            case .update: return "update"
            case .delete: return "delete"
            }
        }
    }

    private func computeGeneralMenuItems() -> [ContextMenuActionItem] {
        var items: [ContextMenuActionItem] = []

        items.append(
            ContextMenuActionItem(
                id: "newQuery",
                title: "New Query",
                systemImage: "doc.badge.plus",
                role: nil,
                action: { openNewQueryTab() }
            )
        )

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

        items.append(
            ContextMenuActionItem(
                id: "pinToggle",
                title: isPinned ? "Unpin" : "Pin",
                systemImage: isPinned ? "pin.slash" : "pin",
                role: nil,
                action: { onTogglePin() }
            )
        )

        items.append(
            ContextMenuActionItem(
                id: "viewStructure",
                title: "View Structure",
                systemImage: object.type == .extension ? "puzzlepiece.fill" : "square.stack.3d.up",
                role: nil,
                action: { openStructureTab() }
            )
        )

        if object.type == .extension {
            items.append(
                ContextMenuActionItem(
                    id: "newExtension",
                    title: "New Extension",
                    systemImage: "puzzlepiece.plus",
                    role: nil,
                    action: { 
                        let dbName = databaseName ?? connection.database
                        environmentState.openExtensionsManagerTab(connectionID: connection.id, databaseName: dbName)
                    }
                )
            )
        }

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

        // View Dependencies (MSSQL only — uses sys.sql_expression_dependencies)
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

        // Table Properties (MSSQL only)
        if object.type == .table && connection.databaseType == .microsoftSQL {
            items.append(
                ContextMenuActionItem(
                    id: "tableProperties",
                    title: "Properties",
                    systemImage: "info.circle",
                    role: nil,
                    action: { openTablePropertiesQuery() }
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

        return items
    }

    internal var supportsStructure: Bool {
        switch object.type {
        case .table, .view, .materializedView, .extension: return true
        case .function, .trigger, .procedure: return false
        }
    }

    internal var supportsDiagram: Bool {
        object.type == .table
    }

    internal var supportsBulkImport: Bool {
        object.type == .table && connection.databaseType == .microsoftSQL
    }
}
