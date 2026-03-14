import SwiftUI

struct SavedConnectionExplorerRow: View {
    let connection: SavedConnection
    let isConnecting: Bool
    let onConnect: () -> Void

    @Environment(ProjectStore.self) private var projectStore
    @EnvironmentObject private var environmentState: EnvironmentState

    private var displayName: String {
        let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? connection.host : trimmed
    }

    private var isAlreadyConnected: Bool {
        environmentState.sessionCoordinator.sessionForConnection(connection.id) != nil
    }

    private var accentColor: Color {
        projectStore.globalSettings.accentColorSource == .connection ? connection.color : ColorTokens.accent
    }

    var body: some View {
        Button {
            onConnect()
        } label: {
            ExplorerSidebarRowChrome(isSelected: false, accentColor: accentColor, style: .plain) {
                HStack(spacing: SidebarRowConstants.iconTextSpacing) {
                    Image(connection.databaseType.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: SidebarRowConstants.iconFrame, height: SidebarRowConstants.iconFrame)

                    Text(displayName)
                        .font(TypographyTokens.standard)
                        .foregroundStyle(ColorTokens.Text.primary)
                        .lineLimit(1)

                    Spacer(minLength: SpacingTokens.xxxs)

                    if connection.host != displayName {
                        Text(connection.host)
                            .font(TypographyTokens.detail)
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
                .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
                .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
                .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.plain)
    }

}
