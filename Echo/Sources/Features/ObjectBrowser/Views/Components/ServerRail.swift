import AppKit
import SwiftUI

/// The server rail (Design/02-layout.md › Rail): glass on the canvas at the window's leading
/// edge. Connected servers are on top, in a pill that hugs them, grows with a spring as they
/// connect and scrolls when it reaches the window bottom; open servers above minimized ones,
/// under a short hairline (round 55). Below it, recent servers in a pill of their own, and a
/// circle that opens a drawer of saved connections beside the trail (round 56, see
/// ServerRail+ConnectTrail).
///
/// The selected server rests on a white disc that moves with a liquid stretch. It follows the
/// server at the top of the tree while scrolling, and holds on a clicked server while the tree
/// glides to it. Connecting servers breathe and lost ones are dimmed; nothing else is drawn.
struct ServerRail: View {
    let bridge: ServerRailBridge
    let itemSize: CGFloat
    let onSelectSession: (ConnectionSession) -> Void
    let onRetryPending: (PendingConnection) -> Void

    // The rail reads the stores itself so that connection, selection and query-state changes
    // redraw only the rail, never the tree beside it.
    @Environment(EnvironmentState.self) var environmentState
    @Environment(ConnectionStore.self) var connectionStore
    @Environment(ProjectStore.self) var projectStore
    @Environment(TabStore.self) var tabStore
    @Environment(AppState.self) var appState
    @Environment(\.echoMotion) var motion

    /// Keeps the selection on a server the user just clicked while the tree scrolls to it.
    @State var clickedConnectionID: UUID?
    /// The trail item the pointer is on, for the name bubble (round 51, NM1).
    @State var hoveredServerID: UUID?
    /// The trail item whose Customize Appearance popover is open (round 51, WH2).
    @State var customizingServerID: UUID?
    /// Top and bottom edges of the selection disc, animated separately for the liquid stretch.
    @State var selectionTop: CGFloat = 0
    @State var selectionBottom: CGFloat = 0
    /// Lets the servers glide between the connected pill and the recents pill.
    @Namespace var trail

    /// Recent servers the user clicked and that are connecting: they breathe in the recents pill
    /// until they are connected, then glide up into the connected pill (round 55).
    @State var connectingRecentIDs: Set<UUID> = []

    /// The rail's height, so the connected pill knows when it has to scroll.
    @State var railHeight: CGFloat = .infinity
    /// The rack button's frame, used to make the connect drawer grow from and return to it.
    @State var connectButtonFrame: CGRect = .zero

    var body: some View {
        let allEntries = self.entries
        let layout = self.layout(for: allEntries)
        let entries = orderedEntries(allEntries, in: layout)
        let highlightedID = highlightedConnectionID(in: entries)
        let isOpen = appState.isConnectTrailOpen

        ZStack(alignment: .topLeading) {
            // Beside the trail, over the tree, under the pills so it emerges from beneath them
            // (round 56, PR3); nothing is there when it is closed.
            if isOpen { connectDrawer }

            // One container for every glass shape, so they render together while items glide
            // between them. Its spacing is below the gap between pills, so they never blend.
            GlassEffectContainer(spacing: SpacingTokens.xxs) {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    if !entries.isEmpty {
                        serverPill(entries: entries, layout: layout, highlightedID: highlightedID)
                    }
                    if !layout.recentIDs.isEmpty {
                        recentsPill(ids: layout.recentIDs)
                            .transition(.opacity)
                    }
                    connectCircle
                    Spacer(minLength: LayoutTokens.Rail.minimumPillGap)
                }
            }
        }
        // The drawer overflows the column to the right, over the tree.
        .frame(width: LayoutTokens.Rail.width(itemSize: itemSize), alignment: .leading)
        .frame(maxHeight: .infinity)
        .coordinateSpace(name: "server-rail")
        // Outside the drawer and the column, a click dismisses it (the pills and the circle are inside).
        .background(alignment: .topLeading) {
            if isOpen {
                ConnectTrailOutsideClick(onOutsideClick: closeConnectTrail)
                    .frame(width: connectDrawerReach)
            }
        }
        // Beside the hovered item, over the tree (round 51).
        .overlayPreferenceValue(ServerRailItemBoundsKey.self) { nameBubble(for: $0, entries: entries, recentIDs: layout.recentIDs) }
        .animation(motion.standard, value: layout)
        // Opening springs; closing settles with no overshoot, so the shrinking glass never passes
        // under the server circles it returns to.
        .animation(isOpen ? motion.standard : motion.settle, value: isOpen)
        .onAppear { placeSelection(on: highlightedID, in: layout, animated: false) }
        .onChange(of: highlightedID) { oldID, newID in
            moveSelection(from: oldID, to: newID, in: layout)
        }
        .onChange(of: layout) { _, newLayout in
            placeSelection(on: highlightedID, in: newLayout, animated: true)
            pruneConnectingRecents(in: allEntries)
        }
        .onChange(of: itemSize) { _, _ in
            placeSelection(on: highlightedID, in: layout, animated: false)
        }
        .onPreferenceChange(ConnectButtonFrameKey.self) { connectButtonFrame = $0 }
    }

}

extension TabStore {
    /// Number of query tabs currently executing, keyed by connection ID.
    var runningQueryCountsByConnection: [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for tab in tabs where tab.query?.isExecuting == true {
            counts[tab.connection.id, default: 0] += 1
        }
        return counts
    }
}

#if DEBUG
#Preview("Server rail items") {
    HStack(spacing: SpacingTokens.lg) {
        ServerRailItem(monogram: "18", color: .blue, status: .ready, isSelected: true, size: 34)
        ServerRailItem(monogram: "TI", color: .green, status: .ready, isSelected: false, size: 34)
        ServerRailItem(monogram: "16", color: .orange, status: .connecting, isSelected: false, size: 34)
        ServerRailItem(monogram: "WH", color: .purple, status: .failed, isSelected: false, size: 34)
    }
    .padding(SpacingTokens.xl)
    .glassEffect(.regular, in: .capsule)
    .padding(SpacingTokens.xl)
    .background(ColorTokens.Workspace.canvas)
}
#endif
