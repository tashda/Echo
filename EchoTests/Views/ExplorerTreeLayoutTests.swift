import CoreGraphics
import Foundation
import Testing
@testable import Echo

@MainActor
@Suite("Explorer Tree Layout")
struct ExplorerTreeLayoutTests {
    private let base: CGFloat = 24

    private func leaf(_ id: String) -> ObjectBrowserNode {
        ObjectBrowserNode(id: id, row: .placeholder(id, kind: nil))
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
        let loading = ObjectBrowserNode(id: "loading", row: .loading("Loading objects"))
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
            row: .placeholder("parent", kind: nil),
            children: [leaf("child")]
        )
        let collapsed = ExplorerTreeLayout(roots: [parent], expandedNodeIDs: [], baseRowHeight: base)
        let expanded = ExplorerTreeLayout(roots: [parent], expandedNodeIDs: ["parent"], baseRowHeight: base)
        #expect(collapsed.rows.count == 1)
        #expect(expanded.rows.map(\.depth) == [0, 1])
    }

    private func makeSession() -> ConnectionSession {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExplorerTreeLayoutTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return ConnectionSession(
            connection: TestFixtures.savedConnection(connectionName: "Test"),
            session: MockDatabaseSession(),
            spoolManager: ResultSpooler(configuration: .defaultConfiguration(rootDirectory: root))
        )
    }

    /// Server-level folders are section headings (tree style S1), so their children aren't indented.
    @Test func sectionChildrenStartAtTheLeftEdge() {
        let session = makeSession()
        func section(_ kind: ExplorerNodeKind) -> ObjectBrowserNode.Row {
            .section(ExplorerFolder(kind: kind, session: session, databaseName: nil, count: nil, isLoading: false, source: nil))
        }
        let databases = ObjectBrowserNode(id: "dbs", row: section(.databases), children: [leaf("db")])
        let security = ObjectBrowserNode(id: "sec", row: section(.serverSecurity), children: [leaf("logins")])
        let server = ObjectBrowserNode(id: "server", row: .server(session), children: [databases, security])
        let layout = ExplorerTreeLayout(roots: [server], expandedNodeIDs: ["server", "dbs", "sec"], baseRowHeight: base)
        #expect(layout.rows.map(\.id) == ["server", "dbs", "db", "sec", "logins"])
        #expect(layout.rows.map(\.depth) == [0, 0, 0, 0, 0])
        #expect(layout.rows[1].height == base + LayoutTokens.Workspace.treeSectionTopPadding)
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
