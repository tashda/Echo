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

    // MARK: - Server Separator

    /// A thin divider line between server sections for clear visual boundaries.
    var serverSeparator: some View {
        Divider()
            .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding + SidebarRowConstants.rowLeadingPadding)
            .padding(.vertical, SpacingTokens.xxs)
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

    func connectToSavedConnection(_ connection: SavedConnection) {
        environmentState.connect(to: connection)
        viewModel.expandedServerIDs.insert(connection.id)
        selectedConnectionID = connection.id
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
