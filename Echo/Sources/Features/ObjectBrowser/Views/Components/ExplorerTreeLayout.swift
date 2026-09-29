import CoreGraphics
import Foundation

/// The Explorer tree's layout, worked out from the visible rows alone (Design/swiftui-tree.md).
///
/// Every row has a fixed height for its kind, so the position of every row and every server card
/// is known without measuring anything. The tree view uses that to place the cards, reveal a row
/// by scrolling to its exact offset, and find which server and database sit at the top.
@MainActor
struct ExplorerTreeLayout {
    struct Row: Identifiable {
        let node: ObjectBrowserNode
        let depth: Int
        let minY: CGFloat
        let height: CGFloat

        var id: String { node.id }
    }

    /// One server's rows, drawn on one card.
    struct Card: Identifiable {
        let id: String
        let minY: CGFloat
        let height: CGFloat
    }

    let rows: [Row]
    let cards: [Card]
    /// Height of all rows plus the room below the last card.
    let contentHeight: CGFloat

    init(roots: [ObjectBrowserNode], expandedNodeIDs: Set<String>, baseRowHeight: CGFloat) {
        var flattened: [(ObjectBrowserNode, Int)] = []
        func append(_ nodes: [ObjectBrowserNode], depth: Int) {
            for node in nodes {
                flattened.append((node, depth))
                guard expandedNodeIDs.contains(node.id) else { continue }
                append(node.children, depth: Self.childDepth(for: node, depth: depth))
            }
        }
        append(roots, depth: 0)

        var rows: [Row] = []
        rows.reserveCapacity(flattened.count)
        var y: CGFloat = 0
        for (node, depth) in flattened {
            let height = Self.height(of: node.row, baseRowHeight: baseRowHeight)
            rows.append(Row(node: node, depth: depth, minY: y, height: height))
            y += height
        }
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

    static func height(of row: ObjectBrowserNode.Row, baseRowHeight: CGFloat) -> CGFloat {
        if case .topSpacer(let height) = row {
            return max(height, SpacingTokens.micro)
        }
        return baseRowHeight + row.groupTopPadding + row.extraSlotHeight
    }

    private static func childDepth(for node: ObjectBrowserNode, depth: Int) -> Int {
        switch node.row {
        case .topSpacer, .pendingConnection, .server:
            depth
        default:
            depth + 1
        }
    }

    // MARK: - Cards

    /// Each server's rows share one card: a card is a run of rows between spacers, and a server
    /// or pending-connection row always starts a new one.
    static func cardRanges(in rows: [Row]) -> [ClosedRange<Int>] {
        var ranges: [ClosedRange<Int>] = []
        var start: Int?
        for (index, row) in rows.enumerated() {
            let spacer = Self.isSpacer(row.node.row)
            let startsCard: Bool
            switch row.node.row {
            case .server, .pendingConnection: startsCard = true
            default: startsCard = false
            }
            if spacer || startsCard, let open = start {
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

    static func isSpacer(_ row: ObjectBrowserNode.Row) -> Bool {
        if case .topSpacer = row { return true }
        return false
    }

    // MARK: - Lookups

    /// The row covering a vertical offset, found by binary search.
    func rowIndex(at y: CGFloat) -> Int? {
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
    func revealOffset(for nodeID: String) -> CGFloat? {
        guard var index = rows.firstIndex(where: { $0.id == nodeID }) else { return nil }
        if index > 0, Self.isSpacer(rows[index - 1].node.row) { index -= 1 }
        return rows[index].minY
    }

    /// The server and database at the top of the view, for the rail and the pinned header.
    func topVisibleContext(atOffset offset: CGFloat, baseRowHeight: CGFloat) -> ObjectBrowserTopVisibleContext? {
        guard let index = rowIndex(at: offset + baseRowHeight / 2) else { return nil }
        let topRow = rows[index].node.row
        return ObjectBrowserTopVisibleContext(
            connectionID: connectionID(nearRow: index),
            databaseName: databaseName(nearRow: index),
            isScrolledPastServerHeader: offset > 1 && !topRow.isServerHeader && !Self.isSpacer(topRow)
        )
    }

    /// Columns carry no database, so they take the object row above them. Server-level rows
    /// (Security, Agent Jobs…) have none.
    private func databaseName(nearRow row: Int) -> String? {
        for index in stride(from: row, through: 0, by: -1) {
            let candidate = rows[index].node.row
            if let name = candidate.databaseName { return name }
            if case .column = candidate { continue }
            return nil
        }
        return nil
    }

    /// Rows without a connection (spacers, columns, messages) take the nearest owner above,
    /// falling back to the first owner below.
    private func connectionID(nearRow row: Int) -> UUID? {
        for index in stride(from: row, through: 0, by: -1) {
            if let id = rows[index].node.row.connectionID { return id }
        }
        for index in row ..< rows.count {
            if let id = rows[index].node.row.connectionID { return id }
        }
        return nil
    }
}
