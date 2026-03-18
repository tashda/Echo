import SwiftUI

extension ObjectBrowserSidebarView {

    // MARK: - Sidebar Row Wrapper

    func sidebarListRow<Content: View>(id: AnyHashable? = nil, leading: CGFloat = 0, @ViewBuilder content: () -> Content) -> some View {
        let row = content()
            .padding(.leading, leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .focusEffectDisabled()

        if let id {
            return AnyView(row.id(id))
        }
        return AnyView(row)
    }

    // MARK: - Compact Inline States

    func loadingHint() -> some View {
        HStack(spacing: SpacingTokens.xxs2) {
            ProgressView()
                .controlSize(.small)
            Text("Loading…")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }

    func failureHint(message: String?, session: ConnectionSession) -> some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(TypographyTokens.label)
                .foregroundStyle(ColorTokens.Status.warning)
            Text(message ?? "Failed to load")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(2)
            Button("Retry") {
                Task { await environmentState.refreshDatabaseStructure(for: session.id) }
            }
            .buttonStyle(.plain)
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.accent)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }

    // MARK: - Global Search Filtering

    /// Normalized sidebar search query, nil when empty.
    var sidebarSearchQuery: String? {
        let trimmed = viewModel.debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.lowercased()
    }

    /// Returns true if a server or any of its children match the search.
    func serverMatchesSearch(_ session: ConnectionSession) -> Bool {
        guard let query = sidebarSearchQuery else { return true }
        // Server name match
        if serverDisplayName(session).lowercased().contains(query) { return true }
        // Check databases
        if let structure = session.databaseStructure {
            for db in structure.databases {
                if db.name.lowercased().contains(query) { return true }
                // Check objects in schemas
                for schema in db.schemas {
                    for obj in schema.objects {
                        if obj.name.lowercased().contains(query) || obj.fullName.lowercased().contains(query) { return true }
                    }
                }
            }
        }
        // Check security items
        let connID = session.connection.id
        if let logins = viewModel.securityLoginsBySession[connID] {
            if logins.contains(where: { $0.name.lowercased().contains(query) }) { return true }
        }
        return false
    }

    /// Returns true if a database or its objects match the search.
    func databaseMatchesSearch(_ database: DatabaseInfo, session: ConnectionSession) -> Bool {
        guard let query = sidebarSearchQuery else { return true }
        if database.name.lowercased().contains(query) { return true }
        for schema in database.schemas {
            for obj in schema.objects {
                if obj.name.lowercased().contains(query) || obj.fullName.lowercased().contains(query) { return true }
                if obj.columns.contains(where: { $0.name.lowercased().contains(query) }) { return true }
            }
        }
        return false
    }

    // MARK: - Display Helpers

    func serverDisplayName(_ session: ConnectionSession) -> String {
        let name = session.connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? session.connection.host : name
    }

    /// Extract a short version label from the stored server version string.
    /// e.g. "SQL Server 16.0.1000.5" -> "16.0.1000.5", "PostgreSQL 16.2" -> "16.2"
    func serverVersionLabel(_ session: ConnectionSession) -> String? {
        let raw = session.databaseStructure?.serverVersion
            ?? session.connection.serverVersion
        guard let raw, !raw.isEmpty else { return nil }

        // Strip the engine name prefix to show just the version number
        let prefixes = ["SQL Server ", "PostgreSQL ", "Microsoft SQL Server "]
        for prefix in prefixes {
            if raw.hasPrefix(prefix) {
                let version = String(raw.dropFirst(prefix.count))
                return version.isEmpty ? nil : version
            }
        }
        // If no known prefix, return as-is (but skip if it's just a type name)
        if raw == "PostgreSQL" || raw == "Microsoft SQL Server" || raw == "SQL Server" {
            return nil
        }
        return raw
    }

    func connectToSavedConnection(_ connection: SavedConnection) async {
        await environmentState.connect(to: connection)
        await MainActor.run {
            viewModel.expandedServerIDs.insert(connection.id)
            selectedConnectionID = connection.id
        }
    }

    func resolvedAccentColor(for connection: SavedConnection) -> Color {
        switch projectStore.globalSettings.accentColorSource {
        case .system:
            return Color.accentColor
        case .connection:
            return connection.color
        case .custom:
            return ColorTokens.accent
        }
    }
}
