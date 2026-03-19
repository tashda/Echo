import SwiftUI

extension ObjectBrowserSidebarView {

    // MARK: - Pending Connection Section

    @ViewBuilder
    func pendingConnectionSection(pending: PendingConnection) -> some View {
        let connection = pending.connection
        let displayName = connectionDisplayName(connection)

        PendingConnectionCard(
            pending: pending,
            displayName: displayName,
            subtitle: connection.databaseType.displayName,
            databaseType: connection.databaseType,
            connectionColor: resolvedAccentColor(for: connection),
            isColorful: projectStore.globalSettings.sidebarIconColorMode == .colorful,
            isSecure: connection.useTLS,
            onRetry: { environmentState.retryPendingConnection(for: connection.id) },
            onCancel: { environmentState.cancelPendingConnection(for: connection.id) },
            onRemove: { environmentState.removePendingConnection(for: connection.id) },
            onEditConnection: {
                ManageConnectionsWindowController.shared.present()
            }
        )
    }

    private func connectionDisplayName(_ connection: SavedConnection) -> String {
        let name = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? connection.host : name
    }
}

// MARK: - Pending Connection Card

private struct PendingConnectionCard: View {
    let pending: PendingConnection
    let displayName: String
    let subtitle: String
    let databaseType: DatabaseType
    let connectionColor: Color
    let isColorful: Bool
    let isSecure: Bool
    let onRetry: () -> Void
    let onCancel: () -> Void
    let onRemove: () -> Void
    let onEditConnection: () -> Void

    @State private var failureTrigger = false
    @State private var isConnecting = true

    private var connectionState: ConnectionState {
        switch pending.phase {
        case .connecting: .connecting
        case .failed: .error(.connectionFailed(""))
        }
    }

    private var trailingAccessory: SidebarConnectionHeader.TrailingAccessory {
        switch pending.phase {
        case .connecting: .none
        case .failed: .retryButton(onRetry)
        }
    }

    var body: some View {
        SidebarConnectionHeader(
            connectionName: displayName,
            subtitle: subtitle,
            databaseType: databaseType,
            connectionColor: connectionColor,
            isExpanded: .constant(false),
            isColorful: isColorful,
            isSecure: isSecure,
            connectionState: connectionState,
            onAction: {},
            trailingAccessory: trailingAccessory
        )
        .overlay(
            StatusWaveOverlay(
                color: ColorTokens.accent,
                cornerRadius: SidebarRowConstants.hoverCornerRadius,
                continuous: isConnecting
            )
        )
        .overlay(
            StatusWaveOverlay(
                color: ColorTokens.Status.error,
                cornerRadius: SidebarRowConstants.hoverCornerRadius,
                trigger: failureTrigger
            )
        )
        .contextMenu { contextMenuContent }
        .onChange(of: pending.phase) { _, newPhase in
            switch newPhase {
            case .connecting:
                isConnecting = true
            case .failed:
                isConnecting = false
                failureTrigger.toggle()
            }
        }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        switch pending.phase {
        case .connecting:
            Button {
                onCancel()
            } label: {
                Label("Cancel Connection", systemImage: "xmark.circle")
            }

            Button {
                onEditConnection()
            } label: {
                Label("Edit Connection", systemImage: "pencil")
            }

        case .failed:
            Button {
                onRetry()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }

            Button {
                onEditConnection()
            } label: {
                Label("Edit Connection", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}
