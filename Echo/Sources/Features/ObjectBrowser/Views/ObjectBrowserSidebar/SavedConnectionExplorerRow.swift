import SwiftUI

struct SavedConnectionExplorerRow: View {
    let connection: SavedConnection
    let isConnecting: Bool
    let onConnect: () -> Void

    @Environment(ProjectStore.self) private var projectStore
    @Environment(EnvironmentState.self) private var environmentState

    private var displayName: String {
        let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? connection.host : trimmed
    }

    private var isAlreadyConnected: Bool {
        environmentState.sessionGroup.sessionForConnection(connection.id) != nil
    }

    private var accentColor: Color {
        projectStore.globalSettings.accentColorSource == .connection ? connection.color : ColorTokens.accent
    }

    var body: some View {
        Button {
            onConnect()
        } label: {
            SidebarRow(
                depth: 0,
                icon: .asset(connection.databaseType.iconName),
                label: displayName,
                accentColor: accentColor
            ) {
                if connection.host != displayName {
                    Text(connection.host)
                        .font(SidebarRowConstants.trailingFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .lineLimit(1)
                }

                if isConnecting {
                    ProgressView()
                        .controlSize(.mini)
                } else if isAlreadyConnected {
                    Circle()
                        .fill(ColorTokens.Status.success)
                        .frame(width: SpacingTokens.xxs + 1, height: SpacingTokens.xxs + 1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.plain)
    }
}
