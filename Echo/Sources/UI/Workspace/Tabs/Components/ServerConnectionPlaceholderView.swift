import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct RecentConnectionItem: Identifiable {
    let id: UUID
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
                EmptyServerConnectionPlaceholderView()
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
            ForEach(connections) { connection in
                RecentConnectionRow(
                    connection: connection,
                    action: { onSelectConnection(connection) }
                )
            }
        }
    }
}

private struct RecentConnectionRow: View {
    let connection: RecentConnectionItem
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                icon
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(connection.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    
                    Text(connection.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.05) : Color.primary.opacity(0.02))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 32, height: 32)
            Image(connection.databaseType.iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .foregroundStyle(Color.accentColor)
        }
    }
}

private struct EmptyServerConnectionPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No connections yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
    }
}
