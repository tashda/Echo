import Foundation

/// Script action types shared between the Object Browser context menu and Search sidebar context menu.
enum ScriptAction: Hashable {
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

    var isReadGroup: Bool {
        switch self {
        case .select, .selectLimited: return true
        default: return false
        }
    }

    var isCreateModifyGroup: Bool {
        switch self {
        case .create, .createOrReplace, .alter, .alterTable: return true
        default: return false
        }
    }

    var isWriteGroup: Bool {
        switch self {
        case .insert, .update, .delete: return true
        default: return false
        }
    }

    var isExecuteGroup: Bool {
        switch self {
        case .execute: return true
        default: return false
        }
    }

    var isDestroyGroup: Bool {
        switch self {
        case .drop, .dropIfExists: return true
        default: return false
        }
    }

    func title(for databaseType: DatabaseType) -> String {
        switch self {
        case .create: return "CREATE"
        case .createOrReplace: return "CREATE OR REPLACE"
        case .alterTable: return "ALTER TABLE"
        case .alter: return "ALTER"
        case .drop: return "DROP"
        case .dropIfExists: return "DROP IF EXISTS"
        case .select: return "SELECT"
        case .selectLimited(let limit): return "SELECT \(limit)"
        case .execute: return databaseType == .microsoftSQL ? "SELECT / EXEC" : "EXECUTE"
        case .insert: return "INSERT"
        case .update: return "UPDATE"
        case .delete: return "DELETE"
        }
    }

    var systemImage: String {
        switch self {
        case .create, .createOrReplace: return "plus.rectangle.on.rectangle"
        case .alter, .alterTable: return "pencil.line"
        case .drop, .dropIfExists: return "trash"
        case .select, .selectLimited: return "magnifyingglass"
        case .execute: return "play"
        case .insert: return "plus.square"
        case .update: return "arrow.triangle.2.circlepath"
        case .delete: return "minus.square"
        }
    }
}

/// Computes the available script actions for a given object type and database type.
enum ScriptActionResolver {

    static func actions(for objectType: SchemaObjectInfo.ObjectType, databaseType: DatabaseType) -> [ScriptAction] {
        switch databaseType {
        case .postgresql: return postgresActions(for: objectType)
        case .mysql: return mysqlActions(for: objectType)
        case .sqlite: return sqliteActions(for: objectType)
        case .microsoftSQL: return mssqlActions(for: objectType)
        }
    }

    private static func includesSelect(_ objectType: SchemaObjectInfo.ObjectType) -> Bool {
        switch objectType {
        case .table, .view, .materializedView: return true
        default: return false
        }
    }

    private static func postgresActions(for objectType: SchemaObjectInfo.ObjectType) -> [ScriptAction] {
        var actions: [ScriptAction] = []

        if includesSelect(objectType) || objectType == .function || objectType == .procedure {
            if includesSelect(objectType) { actions.append(.selectLimited(1000)) }
            actions.append(.select)
        }

        actions.append(.create)
        if objectType != .table { actions.append(.createOrReplace) }

        if includesSelect(objectType) {
            actions.append(contentsOf: [.insert, .update, .delete])
        }
        if objectType == .function || objectType == .procedure {
            actions.append(.execute)
        }
        actions.append(.dropIfExists)
        return actions
    }

    private static func mysqlActions(for objectType: SchemaObjectInfo.ObjectType) -> [ScriptAction] {
        var actions: [ScriptAction] = []

        if includesSelect(objectType) {
            actions.append(contentsOf: [.selectLimited(1000), .select])
        }

        actions.append(.create)
        if objectType == .view { actions.append(.createOrReplace) }
        if objectType == .table {
            actions.append(.alterTable)
        } else {
            actions.append(.alter)
        }

        if objectType == .function || objectType == .procedure {
            actions.append(.execute)
        }
        actions.append(.drop)
        return actions
    }

    private static func sqliteActions(for objectType: SchemaObjectInfo.ObjectType) -> [ScriptAction] {
        var actions: [ScriptAction] = []
        if includesSelect(objectType) {
            actions.append(contentsOf: [.selectLimited(1000), .select])
        }
        actions.append(.create)
        actions.append(.drop)
        return actions
    }

    private static func mssqlActions(for objectType: SchemaObjectInfo.ObjectType) -> [ScriptAction] {
        var actions: [ScriptAction] = []

        if includesSelect(objectType) {
            actions.append(contentsOf: [.selectLimited(1000), .select])
        }

        actions.append(.create)
        actions.append(.alter)

        if includesSelect(objectType) {
            actions.append(contentsOf: [.insert, .update, .delete])
        }
        if objectType == .function || objectType == .procedure {
            actions.append(.execute)
        }
        actions.append(.dropIfExists)
        return actions
    }
}
