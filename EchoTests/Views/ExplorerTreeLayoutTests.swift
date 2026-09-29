import CoreGraphics
import Testing
@testable import Echo

@MainActor
@Suite("Explorer Tree Layout")
struct ExplorerTreeLayoutTests {
    private let base: CGFloat = 24

    private func leaf(_ id: String) -> ObjectBrowserNode {
        ObjectBrowserNode(id: id, row: .infoLeaf(id, systemImage: "circle", paletteTitle: "", depth: 0))
    }

    private func spacer(_ id: String, _ height: CGFloat) -> ObjectBrowserNode {
        ObjectBrowserNode(id: id, row: .topSpacer(height))
    }

    @Test func rowsStackWithFixedHeights() {
        let layout = ExplorerTreeLayout(
            roots: [spacer("top", 1), leaf("a"), leaf("b")],
            expandedNodeIDs: [],
            baseRowHeight: base
        )
        #expect(layout.rows.map(\.minY) == [0, 1, 25])
        #expect(layout.contentHeight == 49 + LayoutTokens.Workspace.treeCardBottomPadding)
    }

    @Test func loadingRowReservesRoomForItsShimmerRows() {
        let loading = ObjectBrowserNode(id: "loading", row: .loading("Loading objects", depth: 1))
        let layout = ExplorerTreeLayout(roots: [leaf("a"), loading, leaf("b")], expandedNodeIDs: [], baseRowHeight: base)
        let shimmerHeight = base * CGFloat(LayoutTokens.Shimmer.explorerRowCount)
        #expect(layout.rows[1].height == shimmerHeight)
        #expect(layout.rows[2].minY == base + shimmerHeight)
    }

    @Test func spacersSplitCards() {
        let layout = ExplorerTreeLayout(
            roots: [spacer("top", 1), leaf("a"), leaf("b"), spacer("gap", 10), leaf("c")],
            expandedNodeIDs: [],
            baseRowHeight: base
        )
        #expect(layout.cards.map(\.id) == ["a", "c"])
        #expect(layout.cards[0].minY == 1)
        #expect(layout.cards[0].height == base * 2 + LayoutTokens.Workspace.treeCardBottomPadding)
    }

    @Test func expandedChildrenAreIndented() {
        let parent = ObjectBrowserNode(
            id: "parent",
            row: .infoLeaf("parent", systemImage: "folder", paletteTitle: "", depth: 0),
            children: [leaf("child")]
        )
        let collapsed = ExplorerTreeLayout(roots: [parent], expandedNodeIDs: [], baseRowHeight: base)
        let expanded = ExplorerTreeLayout(roots: [parent], expandedNodeIDs: ["parent"], baseRowHeight: base)
        #expect(collapsed.rows.count == 1)
        #expect(expanded.rows.map(\.depth) == [0, 1])
    }

    @Test func rowIndexFindsTheRowAtAnOffset() {
        let layout = ExplorerTreeLayout(
            roots: [spacer("top", 1), leaf("a"), leaf("b")],
            expandedNodeIDs: [],
            baseRowHeight: base
        )
        #expect(layout.rowIndex(at: 0) == 0)
        #expect(layout.rowIndex(at: 12) == 1)
        #expect(layout.rowIndex(at: 30) == 2)
        #expect(layout.rowIndex(at: 999) == 2)
    }

    @Test func revealLandsOnTheGapAboveACard() {
        let layout = ExplorerTreeLayout(
            roots: [spacer("top", 1), leaf("a"), spacer("gap", 10), leaf("c")],
            expandedNodeIDs: [],
            baseRowHeight: base
        )
        #expect(layout.revealOffset(for: "c") == 25)
        #expect(layout.revealOffset(for: "missing") == nil)
    }
}
