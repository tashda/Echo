import SwiftUI

/// What the rail draws and in which order (round 55): the connected servers in two groups, open
/// ones (their card is in the tree) above minimized ones with a short hairline between, and the
/// recent servers in a pill of their own below.
///
/// Order inside each group is the connection order. A recent is a saved connection that is not
/// connected and not connecting, most recently used first, and at most `recentLimit` of them; one
/// that the user just clicked stays in the recents, breathing, until it is connected.
nonisolated struct ServerRailLayout: Equatable, Sendable {
    let openIDs: [UUID]
    let minimizedIDs: [UUID]
    let recentIDs: [UUID]

    /// - Parameters:
    ///   - sessionIDs: servers with a live session, in connection order.
    ///   - pendingIDs: servers being connected, after the sessions.
    ///   - minimizedIDs: servers whose card is minimized.
    ///   - recentCandidates: saved connections, most recently used first (may hold duplicates).
    ///   - connectingFromRecents: recents the user clicked; they stay in the recents pill while
    ///     their connection is pending, and move up once it has a session.
    ///   - recentLimit: the most recents shown; 0 or `showsRecents == false` shows none.
    init(
        sessionIDs: [UUID],
        pendingIDs: [UUID],
        minimizedIDs: Set<UUID>,
        recentCandidates: [UUID],
        connectingFromRecents: Set<UUID> = [],
        showsRecents: Bool,
        recentLimit: Int
    ) {
        let sessionSet = Set(sessionIDs)
        let stayingInRecents = connectingFromRecents.intersection(pendingIDs).subtracting(sessionSet)
        let connected = sessionIDs + pendingIDs.filter { !sessionSet.contains($0) && !stayingInRecents.contains($0) }

        var seenConnected = Set<UUID>()
        let uniqueConnected = connected.filter { seenConnected.insert($0).inserted }
        openIDs = uniqueConnected.filter { !minimizedIDs.contains($0) || !sessionSet.contains($0) }
        self.minimizedIDs = uniqueConnected.filter { minimizedIDs.contains($0) && sessionSet.contains($0) }

        guard showsRecents, recentLimit > 0 else {
            recentIDs = []
            return
        }
        let connectedSet = Set(uniqueConnected)
        var seen = Set<UUID>()
        recentIDs = Array(
            recentCandidates
                .filter { !connectedSet.contains($0) && seen.insert($0).inserted }
                .prefix(recentLimit)
        )
    }

    /// The connected servers top to bottom: open, then minimized.
    var connectedIDs: [UUID] { openIDs + minimizedIDs }

    /// The hairline shows only when both groups have a server.
    var showsHairline: Bool { !openIDs.isEmpty && !minimizedIDs.isEmpty }

    /// The hairline and the padding above and below it.
    static var hairlineBlockHeight: CGFloat { LayoutTokens.Rail.hairlineHeight + SpacingTokens.xxs * 2 }

    /// Where an item starts inside the connected column, counted from its top.
    func offset(of id: UUID?, itemSize: CGFloat, spacing: CGFloat) -> CGFloat? {
        guard let id, let index = connectedIDs.firstIndex(of: id) else { return nil }
        var offset = CGFloat(index) * (itemSize + spacing)
        if showsHairline, index >= openIDs.count { offset += Self.hairlineBlockHeight + spacing }
        return offset
    }

    /// The connected column's height, padding excluded.
    func connectedHeight(itemSize: CGFloat, spacing: CGFloat) -> CGFloat {
        let count = CGFloat(connectedIDs.count)
        guard count > 0 else { return 0 }
        let items = count * itemSize + (count - 1) * spacing
        return showsHairline ? items + Self.hairlineBlockHeight + spacing : items
    }

    /// Whether the connected pill outgrows the rail and has to scroll. While it fits it is drawn
    /// without a scroll view, so servers gliding between it and the recents pill are never clipped
    /// (round 55): everything below it (the recents pill and the connect circle, each with its
    /// padding, and the gaps) is subtracted from the rail's height.
    func connectedPillOverflows(
        itemSize: CGFloat,
        spacing: CGFloat,
        padding: CGFloat,
        pillGap: CGFloat,
        minimumGap: CGFloat,
        railHeight: CGFloat
    ) -> Bool {
        let connected = connectedHeight(itemSize: itemSize, spacing: spacing) + padding * 2
        let circle = itemSize + padding * 2
        var below = pillGap + circle + minimumGap
        if !recentIDs.isEmpty {
            let count = CGFloat(recentIDs.count)
            below += pillGap + count * itemSize + (count - 1) * spacing + padding * 2
        }
        return connected > railHeight - below
    }
}
