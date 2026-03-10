import SwiftUI

struct SavedConnectionExplorerRow: View {
    let connection: SavedConnection
    let isConnecting: Bool
    let onConnect: () -> Void

    @EnvironmentObject private var environmentState: EnvironmentState
    private var displayName: String {
        let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? connection.host : trimmed
    }

    private var isAlreadyConnected: Bool {
        environmentState.sessionCoordinator.sessionForConnection(connection.id) != nil
    }

    var body: some View {
        Button {
            onConnect()
        } label: {
            HStack(spacing: 8) {
                Image(connection.databaseType.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: SidebarRowConstants.iconFrame, height: SidebarRowConstants.iconFrame)

                Text(displayName)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(connection.host)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if isConnecting {
                    ProgressView()
                        .controlSize(.mini)
                } else if isAlreadyConnected {
                    Circle()
                        .fill(ColorTokens.Status.success)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
            .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

}
