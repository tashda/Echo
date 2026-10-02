import SwiftUI

/// The connect drawer (round 56, PR3, CD1, CB0, OT0, XB0): the connect circle grows a glass panel
/// beside the trail, over the tree, then receives it back on close. A search field with New Connection,
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

    /// The drawer's glass, over the tree. It grows from the rack button on the house spring and
    /// shrinks back into it with the settling close animation.
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
        .glassEffect(.regular, in: .rect(cornerRadius: SpacingTokens.lg, style: .continuous))
        .glassEffectID("connect-drawer", in: connectDrawerGlass)
        .glassEffectTransition(.matchedGeometry)
        .offset(x: LayoutTokens.Rail.width(itemSize: itemSize) + Self.connectDrawerGap)
    }

    func closeConnectTrail() {
        appState.isConnectTrailOpen = false
    }

    // MARK: Saved connections

    /// The project's saved connections that are not already open, by folder.
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
                    folder: folderPath(of: connection)
                )
            }
    }

    /// "Parent / Child" for the folder the connection is filed in, or nil at the top level.
    private func folderPath(of connection: SavedConnection) -> String? {
        let names = connectionStore.folderPath(to: connectionStore.effectiveFolderID(of: connection)).map(\.displayName)
        return names.isEmpty ? nil : names.joined(separator: " / ")
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
