import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct RecentConnectionItem: Identifiable {
    let id: String
    let record: RecentConnectionRecord
    let name: String
    let server: String
    let database: String?
    let lastConnectedAt: Date
    let databaseType: DatabaseType

    var subtitle: String {
        if let database, !database.isEmpty {
            return "\(database) @ \(server)"
        }
        return server
    }
}

struct RecentConnectionsPlaceholder: View {
    let connections: [RecentConnectionItem]
    let onSelectConnection: (RecentConnectionItem) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text(connections.isEmpty ? "No Recent Connections" : "Recent Connections")
                .font(.title3.weight(.semibold))

            if connections.isEmpty {
                EmptyRecentConnectionsView()
            } else {
                RecentConnectionsList(
                    connections: connections,
                    onSelectConnection: onSelectConnection
                )
            }
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 28)
        .padding(.vertical, 44)
    }
}

private struct RecentConnectionsList: View {
    let connections: [RecentConnectionItem]
    let onSelectConnection: (RecentConnectionItem) -> Void

    var body: some View {
        VStack(spacing: 8) {
            let lastID = connections.last?.id
            ForEach(connections) { connection in
                RecentConnectionRow(
                    item: connection,
                    onTap: { onSelectConnection(connection) }
                )
                .padding(.horizontal, 12)

                if connection.id != lastID {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
    }
}

private struct RecentConnectionRow: View {
    let item: RecentConnectionItem
    let onTap: () -> Void

    private var formattedTimestamp: String {
        item.lastConnectedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                ConnectionIconView(databaseType: item.databaseType)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(item.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(formattedTimestamp)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

private struct ConnectionIconView: View {
    let databaseType: DatabaseType

    var body: some View {
#if os(macOS)
        if let nsImage = NSImage(named: databaseType.iconName) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
        } else {
            fallbackIcon
        }
#else
        if let uiImage = UIImage(named: databaseType.iconName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else {
            fallbackIcon
        }
#endif
    }

    private var fallbackIcon: some View {
        Image(systemName: "server.rack")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.secondary)
    }
}

private struct EmptyRecentConnectionsView: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("You have not connected to any servers yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Use the sidebar to add a server and it will appear here next time.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
