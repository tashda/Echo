import SwiftUI

/// The connect drawer (round 56, PR3, CD1, CB0, OT0, XB0): the connect circle opens a glass panel
/// beside the trail, the height of the rail, over the tree. A search field with New Connection,
/// Manage Connections, Quick Connect and × beside it, then the saved connections by folder. The
/// pills stay as they are and stay usable while it is open (this replaces round 52's widening pill).
extension ServerRail {
    /// Wide enough for a search field and four icon buttons, narrower than the tree.
    static let connectDrawerWidth = SpacingTokens.xxxl * 3.9
    /// The gap between the rail's trailing edge and the drawer.
    static let connectDrawerGap = SpacingTokens.sm - SpacingTokens.xxs

    /// How far the drawer reaches from the rail's leading edge: the column, the gap and the drawer.
    var connectDrawerReach: CGFloat {
        LayoutTokens.Rail.width(itemSize: itemSize) + Self.connectDrawerGap + Self.connectDrawerWidth
    }

    /// The drawer's glass, over the tree. It slides in from the rail with its opacity; closing is
    /// set by the rail's animation (no overshoot).
    var connectDrawer: some View {
        ConnectTrailList(
            entries: connectTrailEntries,
            markColor: { connectTrailColor(for: $0) },
            onConnect: connectFromTrail,
            onNewConnection: {
                closeConnectTrail()
                ManageConnectionsWindowController.shared.present(startingNewConnection: true)
            },
            onManageConnections: {
                closeConnectTrail()
                ManageConnectionsWindowController.shared.present()
            },
            onQuickConnect: {
                closeConnectTrail()
                appState.showSheet(.quickConnect)
            },
            onClose: closeConnectTrail
        )
        .frame(width: Self.connectDrawerWidth)
        .frame(maxHeight: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: SpacingTokens.lg, style: .continuous))
        .offset(x: LayoutTokens.Rail.width(itemSize: itemSize) + Self.connectDrawerGap)
        // Its own width from under the trail, with a fade; closing is the same in reverse. The
        // distance is explicit, so it never depends on the container the transition is in.
        .transition(.modifier(
            active: ConnectDrawerSlide(distance: Self.connectDrawerWidth, isHidden: true),
            identity: ConnectDrawerSlide(distance: Self.connectDrawerWidth, isHidden: false)
        ))
    }

    func closeConnectTrail() {
        appState.isConnectTrailOpen = false
    }

    // MARK: Saved connections

    /// The project's saved connections that are not already open (round MC: no folders).
    var connectTrailEntries: [ConnectTrailEntry] {
        let projectID = projectStore.selectedProject?.id
        let openIDs = Set(environmentState.sessionGroup.activeSessions.map { $0.connection.id })

        return connectionStore.connections
            .filter { $0.projectID == projectID && !openIDs.contains($0.id) }
            .map { connection in
                ConnectTrailEntry(
                    id: connection.id,
                    name: connection.connectionName.isEmpty ? connection.host : connection.connectionName,
                    host: connection.host,
                    database: connection.database,
                    folder: nil
                )
            }
    }

    private func connectTrailColor(for id: UUID) -> Color {
        guard let connection = connectionStore.connections.first(where: { $0.id == id }) else { return ColorTokens.Text.secondary }
        return connectionStore.currentColor(of: connection)
    }

    private func connectFromTrail(_ id: UUID) {
        guard let connection = connectionStore.connections.first(where: { $0.id == id }) else { return }
        closeConnectTrail()
        environmentState.connectToNewSession(to: connection)
    }
}

/// The connect drawer's entry and exit: it travels its own width, from under the trail, fading in;
/// removing it plays the same in reverse.
struct ConnectDrawerSlide: ViewModifier {
    let distance: CGFloat
    let isHidden: Bool

    func body(content: Content) -> some View {
        content
            .offset(x: isHidden ? -distance : 0)
            .opacity(isHidden ? 0 : 1)
    }
}
