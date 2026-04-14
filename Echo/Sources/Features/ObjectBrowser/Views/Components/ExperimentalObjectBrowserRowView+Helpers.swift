import SwiftUI

extension ExperimentalObjectBrowserRowView {
    func serverDisplayName(_ connection: SavedConnection) -> String {
        let name = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? connection.host : name
    }

    func serverDisplayName(_ session: ConnectionSession) -> String {
        serverDisplayName(session.connection)
    }

    func serverSubtitle(_ session: ConnectionSession) -> String {
        if let version = serverVersionLabel(session) {
            return "\(session.connection.databaseType.displayName) (\(version))"
        }
        return session.connection.databaseType.displayName
    }

    func serverVersionLabel(_ session: ConnectionSession) -> String? {
        let raw = session.databaseStructure?.serverVersion ?? session.connection.serverVersion
        guard let raw, !raw.isEmpty else { return nil }
        let prefixes = ["SQL Server ", "PostgreSQL ", "Microsoft SQL Server "]
        for prefix in prefixes where raw.hasPrefix(prefix) {
            let version = String(raw.dropFirst(prefix.count))
            return version.isEmpty ? nil : version
        }
        if ["PostgreSQL", "Microsoft SQL Server", "SQL Server"].contains(raw) {
            return nil
        }
        return raw
    }

    func databaseIconColor(_ database: DatabaseInfo, session: ConnectionSession) -> Color {
        if !database.isOnline || !database.isAccessible {
            return ColorTokens.Text.quaternary
        }
        if isSelected {
            return resolvedAccentColor(for: session.connection)
        }
        return projectStore.globalSettings.sidebarIconColorMode == .colorful
            ? ExplorerSidebarPalette.databaseInstance
            : ExplorerSidebarPalette.monochrome
    }

    func resolvedAccentColor(for connection: SavedConnection) -> Color {
        switch projectStore.globalSettings.accentColorSource {
        case .system:
            Color.accentColor
        case .connection:
            connection.color
        case .custom:
            ColorTokens.accent
        }
    }

    func objectIconName(_ type: SchemaObjectInfo.ObjectType) -> String {
        switch type {
        case .table: "tablecells"
        case .view, .materializedView: "eye"
        case .function: "function"
        case .trigger: "bolt"
        case .procedure: "terminal"
        case .extension: "puzzlepiece"
        case .sequence: "number"
        case .type: "t.square"
        case .synonym: "arrow.triangle.branch"
        }
    }

    func objectSubtitle(_ object: SchemaObjectInfo) -> String? {
        guard object.type == .trigger, let table = object.triggerTable, !table.isEmpty else { return nil }
        return "on \(table)"
    }
}
