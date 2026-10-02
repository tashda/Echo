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
        .offset(x: LayoutTokens.Rail.width(itemSize: itemSize) + Self.connectDrawerGap)
        // The transition's source is the visible rack circle, not an arbitrary drawer edge. This
        // keeps opening and closing as the same gesture even when the rail above it changes height.
        .transition(.modifier(
            active: ConnectDrawerMorph(
                progress: 0,
                source: connectButtonFrame.midpoint,
                destination: CGPoint(x: LayoutTokens.Rail.width(itemSize: itemSize) + Self.connectDrawerGap, y: 0),
                sourceSize: itemSize
            ),
            identity: ConnectDrawerMorph(
                progress: 1,
                source: connectButtonFrame.midpoint,
                destination: CGPoint(x: LayoutTokens.Rail.width(itemSize: itemSize) + Self.connectDrawerGap, y: 0),
                sourceSize: itemSize
            )
        ))
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

/// Maps the drawer's rectangle to the rack button, then interpolates it back to the drawer. As a
/// `GeometryEffect`, this affects rendering only: the rail and tree never relayout during motion.
struct ConnectDrawerMorph: GeometryEffect {
    var progress: CGFloat
    let source: CGPoint
    let destination: CGPoint
    let sourceSize: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let widthScale = min(sourceSize / max(size.width, 1), 1)
        let heightScale = min(sourceSize / max(size.height, 1), 1)
        let scaleX = widthScale + (1 - widthScale) * progress
        let scaleY = heightScale + (1 - heightScale) * progress
        let collapsedOrigin = CGPoint(
            x: source.x - size.width * widthScale / 2,
            y: source.y - size.height * heightScale / 2
        )
        let origin = CGPoint(
            x: collapsedOrigin.x + (destination.x - collapsedOrigin.x) * progress,
            y: collapsedOrigin.y + (destination.y - collapsedOrigin.y) * progress
        )
        let transform = CGAffineTransform(
            a: scaleX, b: 0,
            c: 0, d: scaleY,
            tx: origin.x - destination.x,
            ty: origin.y - destination.y
        )
        return ProjectionTransform(transform)
    }
}

private extension CGRect {
    var midpoint: CGPoint { CGPoint(x: midX, y: midY) }
}
