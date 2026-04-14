import SwiftUI
import EchoSense

struct SavedConnectionsMenuItems: View {
    let parentID: UUID?
    let onConnect: (SavedConnection) -> Void
    
    @Environment(ConnectionStore.self) private var connectionStore

    var body: some View {
        let folders = connectionStore.folders
            .filter { $0.kind == .connections && $0.parentFolderID == parentID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let connections = connectionStore.connections
            .filter { $0.folderID == parentID }
            .sorted { $0.connectionName.localizedCaseInsensitiveCompare($1.connectionName) == .orderedAscending }

        ForEach(folders, id: \.id) { folder in
            Menu(folder.name) {
                SavedConnectionsMenuItems(parentID: folder.id, onConnect: onConnect)
            }
        }

        ForEach(connections, id: \.id) { connection in
            Button(connection.connectionName.isEmpty ? connection.host : connection.connectionName) {
                onConnect(connection)
            }
        }
    }
}
