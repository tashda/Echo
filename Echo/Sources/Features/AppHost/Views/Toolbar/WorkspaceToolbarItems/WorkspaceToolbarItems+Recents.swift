import SwiftUI
import EchoSense

extension WorkspaceToolbarItems {

    // MARK: - Recent Connections Menu

    @ViewBuilder
    internal var recentConnectionsMenu: some View {
        Menu {
            Section("Recent") {
                let allRecents = environmentState.recentConnections
                let visibleRecents = Array(allRecents.prefix(10))
                
                if visibleRecents.isEmpty {
                    Text("No Recent Connections")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(visibleRecents) { record in
                        Button {
                            if let connection = connectionStore.connections.first(where: { $0.id == record.id }) {
                                Task { await environmentState.connectToNewSession(to: connection) }
                            }
                        } label: {
                            HStack {
                                if let image = NSImage(named: record.databaseType.iconName) {
                                    Image(nsImage: image)
                                } else {
                                    Image(systemName: "server.rack")
                                }
                                
                                let baseName = record.connectionName.isEmpty ? record.host : record.connectionName
                                
                                // Only show username suffix if there's a duplicate NAME within the visible set
                                let isDuplicate = visibleRecents.filter { 
                                    let otherName = $0.connectionName.isEmpty ? $0.host : $0.connectionName
                                    return otherName.localizedCaseInsensitiveCompare(baseName) == .orderedSame 
                                }.count > 1
                                
                                Text(baseName + (isDuplicate ? " (\(record.username ?? "default"))" : ""))
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            Button("Clear Recents") {
                environmentState.recentConnections.removeAll()
            }
        } label: {
            Label("Recent Connections", systemImage: "clock")
                .labelStyle(.iconOnly)
        }
        .menuStyle(.button)
        .help("Recent Connections")
        .menuIndicator(.hidden)
    }
}
