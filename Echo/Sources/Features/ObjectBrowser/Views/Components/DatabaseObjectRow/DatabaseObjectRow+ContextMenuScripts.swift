import SwiftUI

extension DatabaseObjectRow {
    internal func scriptActionsForCurrentContext() -> [ScriptAction] {
        switch connection.databaseType {
        case .postgresql:
            return scriptActionsPostgres()
        case .mysql:
            return scriptActionsMySQL()
        case .sqlite:
            return scriptActionsSQLite()
        case .microsoftSQL:
            return scriptActionsMSSQL()
        }
    }

    private func scriptActionsPostgres() -> [ScriptAction] {
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
    }

    private func scriptActionsMySQL() -> [ScriptAction] {
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
    }

    private func scriptActionsSQLite() -> [ScriptAction] {
        var actions: [ScriptAction] = [.create, .drop]
        if shouldIncludeSelectScript {
            actions.append(contentsOf: [.select, .selectLimited(1000)])
        }
        return actions
    }

    private func scriptActionsMSSQL() -> [ScriptAction] {
        var actions: [ScriptAction] = [.create, .alter, .dropIfExists]
        if object.type == .function || object.type == .procedure {
            actions.append(.execute)
        } else if shouldIncludeSelectScript {
            actions.append(contentsOf: [.select, .selectLimited(1000)])
        }
        return actions
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

    internal var shouldIncludeSelectScript: Bool {
        switch object.type {
        case .table, .view, .materializedView:
            return true
        case .function, .trigger, .procedure, .extension:
            return false
        }
    }

    internal func scriptTitle(for action: ScriptAction) -> String {
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

    internal func scriptSystemImage(for action: ScriptAction) -> String {
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

    internal func computeAdministrativeMenuItems() -> [ContextMenuActionItem] {
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

    private var supportsTruncateTable: Bool {
        guard object.type == .table else { return false }
        switch connection.databaseType {
        case .postgresql, .mysql, .microsoftSQL: return true
        case .sqlite: return false
        }
    }
}
