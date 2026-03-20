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
        var actions: [ScriptAction] = []

        // Read group
        if shouldIncludeSelectScript || object.type == .function || object.type == .procedure {
            if shouldIncludeSelectScript {
                actions.append(.selectLimited(1000))
            }
            actions.append(.select)
        }

        // Create/Modify group
        actions.append(.create)
        if supportsCreateOrReplaceInPostgres {
            actions.append(.createOrReplace)
        }

        // Write group
        if shouldIncludeSelectScript {
            actions.append(contentsOf: [.insert, .update, .delete])
        }

        // Execute group
        if object.type == .function || object.type == .procedure {
            actions.append(.execute)
        }

        // Destroy group
        actions.append(.dropIfExists)

        return actions
    }

    private func scriptActionsMySQL() -> [ScriptAction] {
        var actions: [ScriptAction] = []

        // Read group
        if shouldIncludeSelectScript {
            actions.append(.selectLimited(1000))
            actions.append(.select)
        }

        // Create/Modify group
        actions.append(.create)
        if supportsCreateOrReplaceInMySQL {
            actions.append(.createOrReplace)
        }
        if object.type == .table {
            actions.append(.alterTable)
        } else {
            actions.append(.alter)
        }

        // Execute group
        if object.type == .function || object.type == .procedure {
            actions.append(.execute)
        }

        // Destroy group
        actions.append(.drop)

        return actions
    }

    private func scriptActionsSQLite() -> [ScriptAction] {
        var actions: [ScriptAction] = []

        // Read group
        if shouldIncludeSelectScript {
            actions.append(contentsOf: [.selectLimited(1000), .select])
        }

        // Create/Modify group
        actions.append(.create)

        // Destroy group
        actions.append(.drop)

        return actions
    }

    private func scriptActionsMSSQL() -> [ScriptAction] {
        var actions: [ScriptAction] = []

        // Read group
        if shouldIncludeSelectScript {
            actions.append(contentsOf: [.selectLimited(1000), .select])
        }

        // Create/Modify group
        actions.append(.create)
        actions.append(.alter)

        // Write group
        if shouldIncludeSelectScript {
            actions.append(contentsOf: [.insert, .update, .delete])
        }

        // Execute group
        if object.type == .function || object.type == .procedure {
            actions.append(.execute)
        }

        // Destroy group
        actions.append(.dropIfExists)

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
        case .function, .trigger, .procedure, .extension, .sequence, .type, .synonym:
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
        case .insert:
            return "INSERT"
        case .update:
            return "UPDATE"
        case .delete:
            return "DELETE"
        }
    }

    internal func scriptSystemImage(for action: ScriptAction) -> String {
        switch action {
        case .create:
            return "plus.rectangle.on.rectangle"
        case .createOrReplace:
            return "plus.rectangle.on.rectangle"
        case .alter, .alterTable:
            return "pencil.line"
        case .drop:
            return "trash"
        case .dropIfExists:
            return "trash"
        case .select:
            return "magnifyingglass"
        case .selectLimited:
            return "magnifyingglass"
        case .execute:
            return "play"
        case .insert:
            return "plus.square"
        case .update:
            return "arrow.triangle.2.circlepath"
        case .delete:
            return "minus.square"
        }
    }

}
