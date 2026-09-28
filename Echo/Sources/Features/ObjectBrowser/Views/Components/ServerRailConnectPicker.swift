import SwiftUI

/// Popover opened from the rail's + button: type to find a saved server, Return connects.
struct ServerRailConnectPicker: View {
    let connections: [SavedConnection]
    let connectedIDs: Set<UUID>
    let onConnect: (SavedConnection) -> Void
    let onManage: () -> Void

    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ColorTokens.Text.secondary)
                TextField("Connect to…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($isSearchFocused)
                    .onSubmit {
                        if let first = filtered.first { onConnect(first) }
                    }
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xs2)

            Divider()

            if filtered.isEmpty {
                Text(connections.isEmpty ? "No saved connections" : "No matches")
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                ScrollView {
                    LazyVStack(spacing: SpacingTokens.xxxs) {
                        ForEach(filtered) { connection in
                            row(connection)
                        }
                    }
                    .padding(SpacingTokens.xxs)
                }
                .frame(maxHeight: 320)
            }

            Divider()

            Button("Manage Connections…", action: onManage)
                .buttonStyle(.plain)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SpacingTokens.sm)
                .padding(.vertical, SpacingTokens.xs)
        }
        .frame(width: 300)
        .onAppear { isSearchFocused = true }
    }

    private var filtered: [SavedConnection] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let sorted = connections.sorted {
            $0.connectionName.localizedStandardCompare($1.connectionName) == .orderedAscending
        }
        guard !trimmed.isEmpty else { return sorted }
        return sorted.filter {
            $0.connectionName.localizedCaseInsensitiveContains(trimmed)
                || $0.host.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private func row(_ connection: SavedConnection) -> some View {
        ServerRailConnectRow(
            connection: connection,
            isConnected: connectedIDs.contains(connection.id),
            action: { onConnect(connection) }
        )
    }
}

private struct ServerRailConnectRow: View {
    let connection: SavedConnection
    let isConnected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.xs) {
                DatabaseTypeIcon(databaseType: connection.databaseType)
                    .frame(width: 16, height: 16)

                VStack(alignment: .leading, spacing: SpacingTokens.none) {
                    Text(displayName)
                        .font(TypographyTokens.standard)
                        .foregroundStyle(ColorTokens.Text.primary)
                        .lineLimit(1)
                    Text(connection.host)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: SpacingTokens.xs)

                if isConnected {
                    Text("Connected")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, SpacingTokens.xxs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isHovering ? ColorTokens.Sidebar.hoverFill : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var displayName: String {
        let name = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? connection.host : name
    }
}
