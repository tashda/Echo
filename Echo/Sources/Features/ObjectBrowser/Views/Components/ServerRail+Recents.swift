import SwiftUI

/// The recents pill and the connect circle (round 55): saved servers that are not connected,
/// dimmed in a glass capsule of their own, and the button that opens the connect drawer.
extension ServerRail {
    func recentsPill(ids: [UUID]) -> some View {
        VStack(spacing: LayoutTokens.Rail.itemSpacing) {
            ForEach(ids, id: \.self) { id in
                if let connection = connectionStore.connections.first(where: { $0.id == id }) {
                    recentItem(connection)
                }
            }
        }
        .padding(LayoutTokens.Rail.pillPadding)
        .glassEffect(.regular, in: .capsule)
    }

    /// A disconnected server, at 38% of its colour. A click connects it: it breathes while it
    /// connects, then glides up into the connected pill.
    private func recentItem(_ connection: SavedConnection) -> some View {
        let isConnecting = connectingRecentIDs.contains(connection.id)
        let name = connection.connectionName.isEmpty ? connection.host : connection.connectionName

        return Button {
            connectRecent(connection)
        } label: {
            ServerRailItem(
                monogram: ServerRailMonogram.make(from: name),
                glyph: connectionStore.currentGlyph(of: connection),
                color: connectionStore.currentColor(of: connection),
                status: isConnecting ? .connecting : .ready,
                isSelected: false,
                size: itemSize,
                isAlwaysColored: projectStore.globalSettings.serverHeaderColorSource == .server
            )
            // The separate pill already says “recent”; a full-strength mark on hover is the
            // immediate, local confirmation that clicking here reconnects this server.
            .opacity(hoveredServerID == connection.id ? 1 : LayoutTokens.Rail.recentOpacity)
            .animation(motion.hover, value: hoveredServerID == connection.id)
        }
        .buttonStyle(.plain)
        .matchedGeometryEffect(id: connection.id, in: trail)
        .focusable(false)
        // The same glass name bubble as a connected server's, saying it is not connected.
        .onHover(perform: trackHover(of: connection.id, isActive: true))
        .anchorPreference(key: ServerRailItemBoundsKey.self, value: .bounds) { [connection.id: $0] }
        .popover(isPresented: customizingBinding(forID: connection.id), arrowEdge: .trailing) {
            appearancePopover(forID: connection.id)
        }
        .lazyContextMenu { recentMenu(for: connection) }
        .accessibilityLabel(name)
        .accessibilityValue(isConnecting ? "Connecting" : "Disconnected")
        .accessibilityHint("Connects to this server")
    }

    func connectRecent(_ connection: SavedConnection) {
        guard !connectingRecentIDs.contains(connection.id) else { return }
        connectingRecentIDs.insert(connection.id)
        // The pointer is still on the item; a bubble open there would redraw with every update
        // while the server connects.
        hoveredServerID = nil
        environmentState.connectToNewSession(to: connection)
    }

    /// Connect to a Server (round 55, FM0, CI1): its own glass circle under the pills. It opens the
    /// connect drawer, and while that is open it is the close button: the rack turns to an ×
    /// (round 56, CB0).
    var connectCircle: some View {
        Button {
            appState.isConnectTrailOpen.toggle()
        } label: {
            ServerRailToolLabel(
                symbol: appState.isConnectTrailOpen ? "xmark" : LayoutTokens.Rail.connectSymbol,
                isSelected: false,
                width: itemSize,
                height: itemSize,
                restsInPrimary: true
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .padding(LayoutTokens.Rail.pillPadding)
        .glassEffect(.regular, in: .circle)
        .glassEffectID("connect-drawer", in: connectDrawerGlass)
        .help(appState.isConnectTrailOpen ? "Close" : "Connect to a Server")
        .accessibilityLabel(appState.isConnectTrailOpen ? "Close" : "Connect to a Server")
    }
}
