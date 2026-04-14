import SwiftUI

extension DatabaseObjectRow {
    internal func scriptActionsForCurrentContext() -> [ScriptAction] {
        ScriptActionResolver.actions(for: object.type, databaseType: connection.databaseType)
    }

    internal var shouldIncludeSelectScript: Bool {
        switch object.type {
        case .table, .view, .materializedView: return true
        default: return false
        }
    }

    internal func scriptTitle(for action: ScriptAction) -> String {
        action.title(for: connection.databaseType)
    }

    internal func scriptSystemImage(for action: ScriptAction) -> String {
        action.systemImage
    }
}
