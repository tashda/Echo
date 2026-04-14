import SwiftUI

extension DatabaseObjectRow {

    internal struct ContextMenuActionItem: Identifiable {
        let id: String
        let title: String
        let systemImage: String
        let role: ButtonRole?
        let isDisabled: Bool
        let action: () -> Void

        init(
            id: String? = nil,
            title: String,
            systemImage: String,
            role: ButtonRole?,
            isDisabled: Bool = false,
            action: @escaping () -> Void
        ) {
            self.id = id ?? title
            self.title = title
            self.systemImage = systemImage
            self.role = role
            self.isDisabled = isDisabled
            self.action = action
        }
    }

    // ScriptAction is now a shared type in SharedScriptMenu/ScriptMenuTypes.swift

    /// Whether schema-modifying operations (drop, truncate, rename) are allowed based on permissions.
    internal var canModifySchema: Bool {
        guard let session = environmentState.sessionGroup.sessionForConnection(connection.id) else { return true }
        return session.permissions?.canCreateSchemas ?? true
    }

    internal var supportsStructure: Bool {
        switch object.type {
        case .table, .view, .materializedView, .extension: return true
        case .function, .trigger, .procedure, .sequence, .type, .synonym: return false
        }
    }

    internal var supportsDiagram: Bool {
        object.type == .table
    }

    internal var supportsBulkImport: Bool {
        object.type == .table
    }

    internal var supportsTruncateTable: Bool {
        guard object.type == .table else { return false }
        switch connection.databaseType {
        case .postgresql, .mysql, .microsoftSQL: return true
        case .sqlite: return false
        }
    }
}
