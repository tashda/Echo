import SwiftUI
import AppKit

struct RecentConnectionItem: Identifiable {
    let id: String
    let record: RecentConnectionRecord
    let name: String
    let server: String
    let database: String?
    let lastConnectedAt: Date
    let databaseType: DatabaseType
    let connectionColorHex: String?
    let accentColorSource: AccentColorSource
    let customAccentColorHex: String?

    var subtitle: String { server }
}

struct RecentConnectionsPlaceholder: View {
    let connections: [RecentConnectionItem]
    let onSelectConnection: (RecentConnectionItem) -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            if connections.isEmpty {
                welcomeHeader
            } else {
                recentHeader
                RecentConnectionsList(
                    connections: connections,
                    onSelectConnection: onSelectConnection
                )
            }
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, SpacingTokens.xl)
        .padding(.vertical, SpacingTokens.xl2)
    }

    private var welcomeHeader: some View {
        VStack(spacing: SpacingTokens.xs) {
            Image(systemName: "externaldrive.connected.to.line.below")
                .font(TypographyTokens.hero.weight(.light))
                .foregroundStyle(ColorTokens.Text.tertiary)

            Text("Connect to get started")
                .font(TypographyTokens.standard.weight(.medium))
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    private var recentHeader: some View {
        HStack {
            Text("Recent")
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(ColorTokens.Text.tertiary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.leading, SpacingTokens.xxs)
    }
}

private struct RecentConnectionsList: View {
    let connections: [RecentConnectionItem]
    let onSelectConnection: (RecentConnectionItem) -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.xxs) {
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
            HStack(spacing: SpacingTokens.sm) {
                icon

                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    Text(connection.name)
                        .font(TypographyTokens.standard.weight(.medium))
                        .foregroundStyle(ColorTokens.Text.primary)

                    Text(connection.subtitle)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(TypographyTokens.label.weight(.bold))
                    .foregroundStyle(ColorTokens.Text.quaternary)
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xs2)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered ? ColorTokens.Text.primary.opacity(0.05) : ColorTokens.Text.primary.opacity(0.02))
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
        DatabaseTypeIcon(
            databaseType: connection.databaseType,
            tint: iconColor,
            presentation: .landingRecent
        )
    }
}
