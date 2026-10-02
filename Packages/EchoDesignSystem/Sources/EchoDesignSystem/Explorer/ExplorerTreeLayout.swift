import CoreGraphics
import Foundation

/// The Explorer tree's layout, worked out from the visible rows alone (Design/swiftui-tree.md).
///
/// Every row has a fixed height for its kind, so the position of every row and every server card
/// is known without measuring anything. The tree view uses that to place the cards, reveal a row
/// by scrolling to its exact offset, and find which server and database sit at the top.
@MainActor
public struct ExplorerTreeLayout<Node: ExplorerTreeNode> {
    public struct Row: Identifiable {
        public let id: String
        public let node: Node
        public let role: ExplorerTreeRole
        public let depth: Int
        public let minY: CGFloat
        public let height: CGFloat
    }

    /// One server's rows, drawn on one card.
    public typealias Card = ExplorerTreeCard

    public let rows: [Row]
    public let cards: [Card]
    /// Height of all rows plus the room below the last card.
    public let contentHeight: CGFloat

    /// `serverHeaderExtraHeight` is added to every server header row: the header's own extra
    /// height when its look (the title banner's large name) needs more room than an ordinary row.
    public init(roots: [Node], expandedNodeIDs: Set<String>, baseRowHeight: CGFloat, serverHeaderExtraHeight: CGFloat = 0) {
        var rows: [Row] = []
        var y: CGFloat = 0
        func append(_ nodes: [Node], depth: Int) {
            for node in nodes {
                let role = node.treeRole
                var height = Self.height(of: role, baseRowHeight: baseRowHeight)
                if case .server = role.kind { height += serverHeaderExtraHeight }
                rows.append(Row(id: node.id, node: node, role: role, depth: depth, minY: y, height: height))
                y += height
                guard expandedNodeIDs.contains(node.id) else { continue }
                append(node.children, depth: Self.childDepth(for: role, depth: depth))
            }
        }
        append(roots, depth: 0)
        self.rows = rows

        let bottomPadding = LayoutTokens.Workspace.treeCardBottomPadding
        self.cards = Self.cardRanges(in: rows).map { range in
            let first = rows[range.lowerBound]
            let last = rows[range.upperBound]
            return Card(id: first.id, minY: first.minY, height: last.minY + last.height - first.minY + bottomPadding)
        }
        self.contentHeight = y + bottomPadding
    }

    // MARK: - Heights

    public static func height(of role: ExplorerTreeRole, baseRowHeight: CGFloat) -> CGFloat {
        switch role.kind {
        case .spacer(let height): max(height, SpacingTokens.micro)
        case .loading(let slots): baseRowHeight * CGFloat(slots)
        default: baseRowHeight + role.extraSlotHeight
        }
    }

    public static func childDepth(for role: ExplorerTreeRole, depth: Int) -> Int {
        switch role.kind {
        // Server-level sections are headings: their children start at the card's left edge.
        case .spacer, .pendingConnection, .server, .section: depth
        default: depth + 1
        }
    }

    // MARK: - Cards

    /// Each server's rows share one card: a card is a run of rows between spacers, and a server
    /// or pending-connection row always starts a new one.
    public static func cardRanges(in rows: [Row]) -> [ClosedRange<Int>] {
        var ranges: [ClosedRange<Int>] = []
        var start: Int?
        for (index, row) in rows.enumerated() {
            let spacer = row.role.isSpacer
            if spacer || row.role.startsCard, let open = start {
                ranges.append(open ... index - 1)
                start = nil
            }
            if !spacer, start == nil {
                start = index
            }
        }
        if let open = start, open < rows.count {
            ranges.append(open ... rows.count - 1)
        }
        return ranges
    }

    // MARK: - Lookups

    /// The row covering a vertical offset, found by binary search.
    public func rowIndex(at y: CGFloat) -> Int? {
        guard !rows.isEmpty else { return nil }
        var low = 0
        var high = rows.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if rows[mid].minY <= y { low = mid } else { high = mid - 1 }
        }
        return low
    }

    /// Where to scroll to bring a row to the top: the spacer above it, if any, so a server's
    /// card lands with its gap.
    public func revealOffset(for nodeID: String) -> CGFloat? {
        guard var index = rows.firstIndex(where: { $0.id == nodeID }) else { return nil }
        if index > 0, rows[index - 1].role.isSpacer { index -= 1 }
        return rows[index].minY
    }

    /// The server and database at the top of the view, for the rail and the pinned header.
    public func topVisibleContext(atOffset offset: CGFloat, baseRowHeight: CGFloat) -> ExplorerTreeTopContext? {
        guard let index = rowIndex(at: offset + baseRowHeight / 2) else { return nil }
        let top = rows[index].role
        return ExplorerTreeTopContext(
            connectionID: connectionID(nearRow: index),
            databaseName: databaseName(nearRow: index),
            isScrolledPastServerHeader: offset > 1 && top.kind != .server && !top.isSpacer
        )
    }

    /// Columns carry no database, so they take the object row above them. Server-level rows
    /// (Security, Agent Jobs…) have none.
    private func databaseName(nearRow row: Int) -> String? {
        for index in stride(from: row, through: 0, by: -1) {
            let role = rows[index].role
            if let name = role.databaseName { return name }
            if role.kind == .column { continue }
            return nil
        }
        return nil
    }

    /// Rows without a connection (spacers, columns, messages) take the nearest owner above,
    /// falling back to the first owner below.
    private func connectionID(nearRow row: Int) -> UUID? {
        for index in stride(from: row, through: 0, by: -1) {
            if let id = rows[index].role.connectionID { return id }
        }
        for index in row ..< rows.count {
            if let id = rows[index].role.connectionID { return id }
        }
        return nil
    }
}
