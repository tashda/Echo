import AppKit
import SwiftUI

/// The server rail (Design/02-layout.md › Rail): one glass pill on the canvas at the window's
/// leading edge. Servers are on top, in a pill that hugs them, grows with a spring as they
/// connect and scrolls when it reaches the window bottom; its last item is the + that opens the
/// pill itself into the saved connections (round 52, see ServerRail+ConnectTrail).
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
    /// Lets the servers glide from the column into the opened trail's row, and the + into its ×.
    @Namespace var trail

    var body: some View {
        let entries = self.entries
        let highlightedID = highlightedConnectionID(in: entries)
        let entryIDs = entries.map(\.connectionID)

        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            serverPill(entries: entries, highlightedID: highlightedID)
                // Takes all the height it needs within the window.
                .layoutPriority(1)
            Spacer(minLength: LayoutTokens.Rail.minimumPillGap)
        }
        // The opened trail is wider than the column: it overflows to the right over the tree.
        .frame(width: LayoutTokens.Rail.width(itemSize: itemSize), alignment: .leading)
        .frame(maxHeight: .infinity)
        // Beside the hovered item, over the tree (round 51).
        .overlayPreferenceValue(ServerRailItemBoundsKey.self) { nameBubble(for: $0, entries: entries) }
        .animation(motion.standard, value: entryIDs)
        // Opening springs; closing settles with no overshoot, so the shrinking glass never passes
        // under the server circles it returns to.
        .animation(appState.isConnectTrailOpen ? motion.standard : motion.settle, value: appState.isConnectTrailOpen)
        .onAppear { placeSelection(on: highlightedID, in: entryIDs, animated: false) }
        .onChange(of: highlightedID) { oldID, newID in
            moveSelection(from: oldID, to: newID, in: entryIDs)
        }
        .onChange(of: entryIDs) { _, ids in
            placeSelection(on: highlightedID, in: ids, animated: true)
        }
        .onChange(of: itemSize) { _, _ in
            placeSelection(on: highlightedID, in: entryIDs, animated: false)
        }
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
