import SwiftUI

/// The opened server trail (round 52, PR4, OP1 and CX1): the pill itself widens into the list of
/// saved connections. The connected servers lie in a row at the top, built from the same items as
/// the closed trail, with New Connection, Manage Connections, Quick Connect and × at the right.
extension ServerRail {
    /// The widened pill: wide enough for a search field and four icon buttons, narrower than the tree.
    static let connectTrailWidth = SpacingTokens.xxxl * 3.9
    /// The list under the header; it scrolls when there are more connections.
    static let connectTrailListHeight = SpacingTokens.xxxl * 5

    /// The list is gone before the glass starts to shrink under it, so it never shows through the
    /// server circles the pill is returning to.
    private var connectTrailListFade: AnyTransition {
        .asymmetric(insertion: .opacity, removal: .opacity.animation(.easeOut(duration: 0.12)))
    }

    func openTrail(entries: [ServerRailEntry], highlightedID: UUID?) -> some View {
        let runningCounts = tabStore.runningQueryCountsByConnection

        return VStack(spacing: SpacingTokens.xxs) {
            connectTrailHeader(entries: entries, highlightedID: highlightedID, runningCounts: runningCounts)
            ConnectTrailList(
                entries: connectTrailEntries,
                markColor: { connectTrailColor(for: $0) },
                onConnect: connectFromTrail,
                onClose: closeConnectTrail
            )
            .frame(height: Self.connectTrailListHeight)
            .transition(connectTrailListFade)
        }
        .padding(LayoutTokens.Rail.pillPadding)
    }

    private func connectTrailHeader(
        entries: [ServerRailEntry],
        highlightedID: UUID?,
        runningCounts: [UUID: Int]
    ) -> some View {
        HStack(spacing: SpacingTokens.xxs) {
            // Sideways under a soft edge when there are more servers than room.
            ScrollView(.horizontal) {
                HStack(spacing: LayoutTokens.Rail.itemSpacing) {
                    ForEach(entries, id: \.connectionID) { entry in
                        item(
                            for: entry,
                            isSelected: entry.connectionID == highlightedID,
                            runningQueryCount: runningCounts[entry.connectionID] ?? 0,
                            drawsOwnDisc: true
                        )
                    }
                }
            }
            .scrollIndicators(.never)
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeEffectStyle(.soft, for: .horizontal)

            HStack(spacing: SpacingTokens.xxxs) {
                ConnectTrailIconButton(symbol: "plus", title: "New Connection") {
                    closeConnectTrail()
                    ManageConnectionsWindowController.shared.present(startingNewConnection: true)
                }
                ConnectTrailIconButton(symbol: "gearshape", title: "Manage Connections") {
                    closeConnectTrail()
                    ManageConnectionsWindowController.shared.present()
                }
                ConnectTrailIconButton(symbol: "bolt.fill", title: "Quick Connect") {
                    closeConnectTrail()
                    appState.showSheet(.quickConnect)
                }
                ConnectTrailIconButton(
                    symbol: "xmark",
                    title: "Close",
                    font: TypographyTokens.detail.weight(.semibold),
                    action: closeConnectTrail
                )
                // The + glides here as the trail opens, and back as it closes.
                .matchedGeometryEffect(id: "toggle", in: trail)
            }
        }
    }

    /// The selection disc drawn behind one item of the opened trail's row, as the closed trail's.
    var ownSelectionDisc: some View {
        Capsule()
            .fill(ColorTokens.Workspace.railSelection)
            .shadow(ShadowTokens.railSelection)
            .padding(LayoutTokens.Rail.selectionInset)
    }

    /// The + at the foot of the closed trail. It opens the trail and glides to the ×.
    var connectButton: some View {
        Button {
            appState.isConnectTrailOpen = true
        } label: {
            ServerRailToolLabel(symbol: "plus", isSelected: false, width: itemSize, height: itemSize)
        }
        .buttonStyle(.plain)
        .matchedGeometryEffect(id: "toggle", in: trail)
        .focusable(false)
        .help("Connect to a Server")
        .accessibilityLabel("Connect to a Server")
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
