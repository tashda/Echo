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

    private struct ContextMenuActionItem: Identifiable {
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
        
        if supportsDataPreview {
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
                systemImage: "square.stack.3d.up",
                role: nil,
                action: { openStructureTab() }
            )
        )
        
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

    private func computeAdministrativeMenuItems() -> [ContextMenuActionItem] {
        var items: [ContextMenuActionItem] = []
        
        switch connection.databaseType {
        case .postgresql, .mysql, .microsoftSQL:
            items.append(renameMenuItem)
            if supportsTruncateTable {
                items.append(
                    ContextMenuActionItem(
                        id: "truncateTable",
                        title: "Truncate Table",
                        systemImage: "scissors",
                        role: .destructive,
                        action: { initiateTruncate() }
                    )
                )
            }
            items.append(dropMenuItem)
            
        case .sqlite:
            items.append(renameMenuItem)
            items.append(dropMenuItem)
        }
        
        return items
    }
    
    private var renameMenuItem: ContextMenuActionItem {
        ContextMenuActionItem(
            id: "renameObject",
            title: connection.databaseType == .sqlite ? "Rename (Limited)" : "Rename",
            systemImage: "textformat.alt",
            role: nil,
            action: { initiateRename() }
        )
    }
    
    private var dropMenuItem: ContextMenuActionItem {
        ContextMenuActionItem(
            id: "dropObject",
            title: "Drop",
            systemImage: "trash",
            role: .destructive,
            action: { initiateDrop(includeIfExists: false) }
        )
    }
    
    private var supportsDataPreview: Bool {
        switch object.type {
        case .table, .view, .materializedView:
            return true
        case .function, .trigger, .procedure:
            return false
        }
    }
    
    internal var supportsDiagram: Bool {
        object.type == .table
    }
    
    private var supportsTruncateTable: Bool {
        guard object.type == .table else { return false }
        switch connection.databaseType {
        case .postgresql, .mysql, .microsoftSQL:
            return true
        case .sqlite:
            return false
        }
    }
    
    private func scriptActionsForCurrentContext() -> [ScriptAction] {
        switch connection.databaseType {
        case .postgresql:
            var actions: [ScriptAction] = [.create]
            if supportsCreateOrReplaceInPostgres {
                actions.append(.createOrReplace)
            }
            actions.append(.dropIfExists)
            if shouldIncludeSelectScript || object.type == .function || object.type == .procedure {
                actions.append(.select)
                if shouldIncludeSelectScript {
                    actions.append(.selectLimited(1000))
                }
            }
            if object.type == .function || object.type == .procedure {
                actions.append(.execute)
            }
            return actions
            
        case .mysql:
            var actions: [ScriptAction] = [.create]
            if supportsCreateOrReplaceInMySQL {
                actions.append(.createOrReplace)
            }
            if object.type == .table {
                actions.append(.alterTable)
            } else {
                actions.append(.alter)
            }
            actions.append(.drop)
            if shouldIncludeSelectScript {
                actions.append(.select)
                actions.append(.selectLimited(1000))
            }
            if object.type == .function || object.type == .procedure {
                actions.append(.execute)
            }
            return actions
            
        case .sqlite:
            var actions: [ScriptAction] = [.create, .drop]
            if shouldIncludeSelectScript {
                actions.append(contentsOf: [.select, .selectLimited(1000)])
            }
            return actions
            
        case .microsoftSQL:
            var actions: [ScriptAction] = [.create, .alter, .dropIfExists]
            if object.type == .function || object.type == .procedure {
                actions.append(.execute)
            } else if shouldIncludeSelectScript {
                actions.append(contentsOf: [.select, .selectLimited(1000)])
            }
            return actions
        }
    }
    
    private var supportsCreateOrReplaceInPostgres: Bool {
        switch object.type {
        case .table:
            return false
        default:
            return true
        }
    }
    
    private var supportsCreateOrReplaceInMySQL: Bool {
        object.type == .view
    }
    
    private var shouldIncludeSelectScript: Bool {
        switch object.type {
        case .table, .view, .materializedView:
            return true
        case .function, .trigger, .procedure:
            return false
        }
    }
    
    private func scriptTitle(for action: ScriptAction) -> String {
        switch action {
        case .create:
            return "CREATE"
        case .createOrReplace:
            return "CREATE OR REPLACE"
        case .alterTable:
            return "ALTER TABLE"
        case .alter:
            return "ALTER"
        case .drop:
            return "DROP"
        case .dropIfExists:
            return "DROP IF EXISTS"
        case .select:
            return "SELECT"
        case .selectLimited(let limit):
            return "SELECT \(limit)"
        case .execute:
            return connection.databaseType == .microsoftSQL ? "SELECT / EXEC" : "EXECUTE"
        }
    }
    
    private func scriptSystemImage(for action: ScriptAction) -> String {
        switch action {
        case .create:
            return "plus.rectangle.on.rectangle"
        case .createOrReplace:
            return "arrow.triangle.2.circlepath"
        case .alter, .alterTable:
            return "wrench"
        case .drop:
            return "trash"
        case .dropIfExists:
            return "trash.slash"
        case .select:
            return "text.magnifyingglass"
        case .selectLimited:
            return "text.magnifyingglass"
        case .execute:
            return "play.circle"
        }
    }
}
