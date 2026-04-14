import SwiftUI
import EchoSense

/// Standalone view that properly observes `@Observable` state changes.
/// Toolbar inline `@ViewBuilder` computed properties inside `CustomizableToolbarContent`
/// do not re-evaluate when `@Observable` state changes — wrapping in a proper `View`
/// ensures SwiftUI's observation tracking triggers re-renders.
struct RecentConnectionsMenuButton: View {
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(EnvironmentState.self) private var environmentState

    var body: some View {
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
                                environmentState.connectToNewSession(to: connection)
                            }
                        } label: {
                            HStack {
                                DatabaseTypeIcon(databaseType: record.databaseType, presentation: .menu)

                                let baseName = record.connectionName.isEmpty ? record.host : record.connectionName

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
