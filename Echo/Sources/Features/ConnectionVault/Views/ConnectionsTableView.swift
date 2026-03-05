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


    var body: some View {
        DoubleClickableTable(
            connections: connections,
            selection: $selection,
            onDoubleClick: onDoubleClick
        ) {
            Table(of: SavedConnection.self, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("") { connection in
                    ConnectionIconCell(connection: connection)
                }
                .width(28)

                TableColumn("Name", value: \.connectionName) { connection in
                    Text(displayName(for: connection))
                }

                TableColumn("Server") { connection in
                    Text(serverLabel(for: connection))
                }

                TableColumn("Database", value: \.database) { connection in
                    Text(connection.database.isEmpty ? "—" : connection.database)
                }

                TableColumn("Credentials") { connection in
                    if let decoration = identityDecorationProvider(connection) {
                        Label {
                            Text(decoration.name)
                        } icon: {
                            Image(systemName: decoration.icon)
                        }
                        .foregroundStyle(.secondary)
                    } else {
                        Text("—")
                            .foregroundStyle(.secondary)
                    }
                }

                TableColumn("Folder") { connection in
                    if let folderID = connection.folderID,
                       let folder = folderLookup[folderID] {
                        Text(folder.displayName)
                    } else {
                        Text("—")
                            .foregroundStyle(.secondary)
                    }
                }

                TableColumn("Type") { connection in
                    Text(connection.databaseType.displayName)
                }
            } rows: {
                ForEach(connections) { connection in
                    TableRow(connection)
                        .itemProvider {
                            NSItemProvider(object: "connection:\(connection.id.uuidString)" as NSString)
                        }
                }
            }
            .contextMenu(forSelectionType: SavedConnection.ID.self) { items in
                if let selectionID = items.first,
                   let connection = connections.first(where: { $0.id == selectionID }) {
                    Button {
                        onConnect(connection)
                    } label: {
                        Text("Connect")
                    }

                    Button {
                        onEdit(connection)
                    } label: {
                        Text("Edit")
                    }

                    Button {
                        onDuplicate(connection)
                    } label: {
                        Text("Duplicate")
                    }

                    Menu("Move to Folder") {
                        ForEach(Array(folderLookup.values).sorted(by: { $0.name < $1.name }), id: \.id) { folder in
                            Button(folder.displayName) {
                                moveConnectionToFolder(connection, folder)
                            }
                        }
                        Divider()
                        Button("Create New Folder...") {
                            createFolderAndMoveConnection(connection)
                        }
                    }

                    Divider()
                    Button("Delete", role: .destructive) { onDelete(connection) }
                }
            }
        }
        .background(ColorTokens.Background.secondary)
    }

    private func displayName(for connection: SavedConnection) -> String {
        let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? connection.host : trimmed
    }

    private func serverLabel(for connection: SavedConnection) -> String {
        if connection.port > 0 {
            return "\(connection.host):\(connection.port)"
        }
        return connection.host.isEmpty ? "—" : connection.host
    }
}
