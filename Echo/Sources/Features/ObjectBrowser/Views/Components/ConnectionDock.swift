import AppKit
import SwiftUI

struct ConnectionDock: View {
    let sessions: [ConnectionSession]
    let pendingConnections: [PendingConnection]
    let selectedConnectionID: UUID?
    let iconColorMode: SidebarIconColorMode
    let density: SidebarDensity
    let accentColorForConnection: (SavedConnection) -> Color
    let contextMenuForSession: (ConnectionSession) -> NSMenu
    let contextMenuForPending: (PendingConnection) -> NSMenu
    let onSelectSession: (ConnectionSession) -> Void
    let onRetryPending: (PendingConnection) -> Void

    @State internal var showsAllConnections = false

    var body: some View {
        if !isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                dockHeader

                LazyVGrid(columns: columns, alignment: .leading, spacing: SpacingTokens.xxxs) {
                    ForEach(visibleEntries) { entry in
                        switch entry {
                        case .session(let session):
                            sessionItem(session)
                        case .pending(let pending):
                            pendingItem(pending)
                        }
                    }
                }
                .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
            }
            .padding(.bottom, SpacingTokens.xxs)
            .glassEffect(.regular, in: dockShape)
            .onChange(of: connectionCount) { _, newCount in
                if newCount <= LayoutTokens.ConnectionDock.collapsedItemLimit {
                    showsAllConnections = false
                }
            }
            .onChange(of: selectedConnectionID) { oldID, newID in
                if oldID != newID {
                    collapseDock()
                }
            }
        }
    }

    @ViewBuilder
    private var dockHeader: some View {
        if canExpandDock {
            Button(action: toggleDock) {
                dockHeaderContent
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .accessibilityLabel(
                showsAllConnections ? "Collapse Connections" : "Expand Connections"
            )
            .accessibilityValue(showsAllConnections ? "Expanded" : "Collapsed")
            .help(
                showsAllConnections
                    ? "Show only the selected connection and its neighbor"
                    : "Show all connections"
            )
        } else {
            dockHeaderContent
        }
    }

    private var dockHeaderContent: some View {
        SidebarSectionHeader(title: "Connections") {
            HStack(spacing: SpacingTokens.xxs) {
                CountBadge(count: connectionCount)

                if canExpandDock {
                    Image(systemName: showsAllConnections ? "chevron.down" : "chevron.right")
                        .font(TypographyTokens.compact.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.quaternary)
                        .contentTransition(.identity)
                        .frame(width: SidebarRowConstants.chevronWidth)
                        .padding(SpacingTokens.xxs)
                }
            }
        }
    }

    private var dockShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: LayoutTokens.ConnectionDock.cornerRadius,
            style: .continuous
        )
    }

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: LayoutTokens.ConnectionDock.minimumColumnWidth),
                spacing: SpacingTokens.xxxs
            )
        ]
    }

    private func sessionItem(_ session: ConnectionSession) -> some View {
        let isSelected = selectedConnectionID == session.connection.id

        return ConnectionDockItem(
            databaseType: session.connection.databaseType,
            title: displayName(for: session.connection),
            helpText: session.connection.host,
            stateDescription: stateDescription(for: session.connectionState),
            isSelected: isSelected,
            isColorful: iconColorMode == .colorful,
            iconTint: isSelected
                ? accentColorForConnection(session.connection)
                : ColorTokens.Sidebar.symbol,
            statusColor: statusColor(for: session.connectionState),
            isStatusPulsing: isConnecting(session.connectionState),
            density: density,
            contextMenuBuilder: { contextMenuForSession(session) },
            trailing: { EmptyView() },
            action: {
                onSelectSession(session)
                collapseDock()
            }
        )
    }

    private func pendingItem(_ pending: PendingConnection) -> some View {
        ConnectionDockItem(
            databaseType: pending.connection.databaseType,
            title: displayName(for: pending.connection),
            helpText: pendingHelpText(pending),
            stateDescription: pendingStateDescription(pending),
            isSelected: false,
            isColorful: iconColorMode == .colorful,
            iconTint: accentColorForConnection(pending.connection),
            statusColor: pendingStatusColor(pending),
            isStatusPulsing: pendingIsConnecting(pending),
            density: density,
            contextMenuBuilder: { contextMenuForPending(pending) },
            trailing: {
                switch pending.phase {
                case .connecting:
                    EmptyView()
                case .failed:
                    Image(systemName: "arrow.clockwise")
                        .font(TypographyTokens.detail.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            },
            action: {
                if case .failed = pending.phase {
                    onRetryPending(pending)
                }
            }
        )
    }

    private func toggleDock() {
        withAnimation(.smooth(duration: 0.24, extraBounce: 0)) {
            showsAllConnections.toggle()
        }
    }

    private func collapseDock() {
        guard showsAllConnections else { return }
        withAnimation(.smooth(duration: 0.24, extraBounce: 0)) {
            showsAllConnections = false
        }
    }
}
