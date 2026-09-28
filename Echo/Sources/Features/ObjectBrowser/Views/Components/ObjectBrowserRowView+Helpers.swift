import SwiftUI

extension ObjectBrowserRowView {
    func serverDisplayName(_ connection: SavedConnection) -> String {
        let name = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? connection.host : name
    }

    func serverDisplayName(_ session: ConnectionSession) -> String {
        serverDisplayName(session.connection)
    }

    func serverSubtitle(_ session: ConnectionSession) -> String {
        let typeLabel: String
        if let version = serverVersionLabel(session) {
            typeLabel = "\(session.connection.databaseType.displayName) (\(version))"
        } else {
            typeLabel = session.connection.databaseType.displayName
        }

        let displayName = serverDisplayName(session)
        let host = session.connection.host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, displayName.caseInsensitiveCompare(host) != .orderedSame else {
            return typeLabel
        }
        return "\(host) - \(typeLabel)"
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

    /// Right-aligned tertiary detail rendered in the row's trailing slot.
    /// For triggers, this is the parent table name (no "on " prefix — that
    /// reads like CLI output; the trailing position alone communicates the
    /// relationship).
    func objectTrailingDetail(_ object: SchemaObjectInfo) -> String? {
        guard object.type == .trigger,
              let table = object.triggerTable,
              !table.isEmpty
        else { return nil }
        return table
    }

    /// Renders an object's qualified name with the schema prefix dimmed to
    /// tertiary, matching Xcode's namespace dimming for symbols like `Foo.Bar`.
    /// Falls back to a single primary-colored Text when there's no schema dot.
    func dimmedSchemaLabel(for fullName: String) -> Text? {
        guard let dotIndex = fullName.firstIndex(of: "."),
              dotIndex != fullName.startIndex
        else { return nil }
        let schemaPart = String(fullName[..<fullName.index(after: dotIndex)])
        let namePart = String(fullName[fullName.index(after: dotIndex)...])
        return Text("\(Text(schemaPart).foregroundStyle(ColorTokens.Text.tertiary))\(Text(namePart).foregroundStyle(ColorTokens.Text.primary))")
    }
}
