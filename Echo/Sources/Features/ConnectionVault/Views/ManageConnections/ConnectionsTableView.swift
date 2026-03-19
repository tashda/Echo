import SwiftUI

struct ConnectionsTableView: View {
    let connections: [SavedConnection]
    @Binding var selection: Set<SavedConnection.ID>
    @Binding var sortOrder: [KeyPathComparator<SavedConnection>]
    let folderLookup: [UUID: SavedFolder]
    let onConnect: (SavedConnection) -> Void
    let onEdit: (SavedConnection) -> Void
    let onDuplicate: (SavedConnection) -> Void
    let onDelete: (SavedConnection) -> Void
    let identityDecorationProvider: (SavedConnection) -> (name: String, icon: String)?
    let onDoubleClick: (SavedConnection) -> Void
    let moveConnectionToFolder: (SavedConnection, SavedFolder) -> Void
    let createFolderAndMoveConnection: (SavedConnection) -> Void
    let onNewConnection: () -> Void
    let onNewFolder: () -> Void

    var body: some View {
        Table(of: SavedConnection.self, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Type") { connection in
                ConnectionIconCell(connection: connection)
            }
            .width(32)

            TableColumn("Name", value: \.connectionName) { connection in
                Text(displayName(for: connection))
                    .font(TypographyTokens.Table.name)
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
                            .font(TypographyTokens.Table.name)
                    } icon: {
                        Image(systemName: decoration.icon)
                    }
                    .foregroundStyle(ColorTokens.Text.secondary)
                } else {
                    Text("—")
                        .font(TypographyTokens.Table.name)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }

            TableColumn("Folder") { connection in
                if let folderID = connection.folderID,
                   let folder = folderLookup[folderID] {
                    Text(folder.displayName)
                        .font(TypographyTokens.Table.name)
                } else {
                    Text("—")
                        .font(TypographyTokens.Table.name)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
        } rows: {
            ForEach(connections) { connection in
                TableRow(connection)
                    .itemProvider {
                        NSItemProvider(object: "connection:\(connection.id.uuidString)" as NSString)
                    }
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: SavedConnection.ID.self) { items in
            if let selectionID = items.first,
               let connection = connections.first(where: { $0.id == selectionID }) {
                Button("Connect") { onConnect(connection) }
                Button("Edit") { onEdit(connection) }
                Button("Duplicate") { onDuplicate(connection) }

                Menu("Move to Folder") {
                    ForEach(Array(folderLookup.values).sorted(by: { $0.name < $1.name }), id: \.id) { folder in
                        Button(folder.displayName) {
                            moveConnectionToFolder(connection, folder)
                        }
                    }
                    Divider()
                    Button("Create New Folder") {
                        createFolderAndMoveConnection(connection)
                    }
                }

                Divider()
                Button("Delete", role: .destructive) { onDelete(connection) }
            } else {
                Button("New Connection") { onNewConnection() }
                Button("New Folder") { onNewFolder() }
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
