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
    let connectionColorHex: String?
    let accentColorSource: AccentColorSource
    let customAccentColorHex: String?

    var subtitle: String {
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
                        .font(TypographyTokens.standard.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    Text(connection.subtitle)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(TypographyTokens.label.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xs2)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.05) : Color.primary.opacity(0.02))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var iconColor: Color {
        switch connection.accentColorSource {
        case .system:
            return .accentColor
        case .connection:
            if let hex = connection.connectionColorHex, !hex.isEmpty, hex != "default" {
                return Color(hex: hex) ?? .accentColor
            }
            return .accentColor
        case .custom:
            if let hex = connection.customAccentColorHex, !hex.isEmpty {
                return Color(hex: hex) ?? .accentColor
            }
            return .accentColor
        }
    }

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(iconColor.opacity(0.12))
                .frame(width: 32, height: 32)
            Image(connection.databaseType.iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .foregroundStyle(iconColor)
        }
    }
}

private struct EmptyServerConnectionPlaceholderView: View {
    var body: some View {
        EmptyStatePlaceholder(icon: "clock.arrow.circlepath", title: "No connections yet")
            .padding(.vertical, SpacingTokens.md2)
    }
}
