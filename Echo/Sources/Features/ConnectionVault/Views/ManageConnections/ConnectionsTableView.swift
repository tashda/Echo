import SwiftUI

struct ConnectionsTableView: View {
    let connections: [SavedConnection]
    @Binding var selection: Set<SavedConnection.ID>
    @Binding var sortOrder: [KeyPathComparator<SavedConnection>]
    let onConnect: (SavedConnection) -> Void
    let onEdit: (SavedConnection) -> Void
    let onDuplicate: (SavedConnection) -> Void
    let onDelete: (SavedConnection) -> Void
    let identityDecorationProvider: (SavedConnection) -> (name: String, icon: String)?
    let onDoubleClick: (SavedConnection) -> Void
    let onNewConnection: () -> Void

    var body: some View {
        Table(of: SavedConnection.self, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Type") { connection in
                ConnectionIconCell(connection: connection)
            }
            .width(32)

            TableColumn("Name", value: \.connectionName) { connection in
                HStack(spacing: SpacingTokens.xs) {
                    // Round 51 (WS0): the server's look, as in the trail.
                    ServerRailMark(
                        monogram: ServerRailMonogram.make(from: displayName(for: connection)),
                        glyph: connection.railGlyph,
                        color: connection.color,
                        weight: .bold,
                        size: SpacingTokens.lg
                    )
                    .accessibilityHidden(true)
                    Text(displayName(for: connection))
                        .font(TypographyTokens.Table.name)
                }
            }

            TableColumn("Server", value: \.host) { connection in
                Text(connection.host.isEmpty ? "—" : connection.host)
                    .font(TypographyTokens.Table.name)
                    .foregroundStyle(connection.host.isEmpty ? ColorTokens.Text.tertiary : ColorTokens.Text.primary)
            }

            TableColumn("Port") { connection in
                Text(connection.port > 0 ? String(connection.port) : "—")
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle(connection.port > 0 ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
            }
            .width(ideal: 50, max: 70)

            TableColumn("Credentials") { connection in
                if let decoration = identityDecorationProvider(connection) {
                    Label {
                        Text(decoration.name)
                            .font(TypographyTokens.Table.secondaryName)
                    } icon: {
                        Image(systemName: decoration.icon)
                    }
                    .foregroundStyle(ColorTokens.Text.secondary)
                } else {
                    Text("\u{2014}")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
        } rows: {
            ForEach(connections) { connection in
                TableRow(connection)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: SavedConnection.ID.self) { items in
            if let selectionID = items.first,
               let connection = connections.first(where: { $0.id == selectionID }) {
                Button { onConnect(connection) } label: { Label("Connect", systemImage: "bolt.fill") }
                Button { onEdit(connection) } label: { Label("Edit", systemImage: "pencil") }
                Button { onDuplicate(connection) } label: { Label("Duplicate", systemImage: "doc.on.doc") }

                Divider()
                Button(role: .destructive) { onDelete(connection) } label: { Label("Delete", systemImage: "trash") }
            } else {
                Button { onNewConnection() } label: { Label("New Connection", systemImage: "plus.circle") }
            }
        } primaryAction: { items in
            if let selectionID = items.first,
               let connection = connections.first(where: { $0.id == selectionID }) {
                onDoubleClick(connection)
            }
        }
    }

    private func displayName(for connection: SavedConnection) -> String {
        let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? connection.host : trimmed
    }
}
