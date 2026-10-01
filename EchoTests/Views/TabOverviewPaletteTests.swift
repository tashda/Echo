import Foundation
import Testing
@testable import Echo

/// Round 35.1 (TO6): the tab overview inside the ⌘K palette.
@Suite("Tab overview palette")
@MainActor
struct TabOverviewPaletteTests {
    private let ids = (0..<5).map { _ in UUID() }

    /// Strip order: two on sql10, one on postgres18, one more on sql10, one on postgres18.
    private var entries: [TabOverviewEntry] {
        [
            TabOverviewEntry(id: ids[0], title: "Query 1", server: "sql10", detail: "ESB", keywords: "select * from aml"),
            TabOverviewEntry(id: ids[1], title: "Jobs", server: "sql10", detail: "Jobs"),
            TabOverviewEntry(id: ids[2], title: "orders.sql", server: "postgres18", detail: "shop"),
            TabOverviewEntry(id: ids[3], title: "Bag history", server: "sql10", detail: "ccsLDK10"),
            TabOverviewEntry(id: ids[4], title: "Query 6", server: "postgres18", detail: "analytics"),
        ]
    }

    @Test func groupsByServerInOrderOfFirstTab() {
        let groups = TabOverviewEntry.groups(entries)
        #expect(groups.map(\.server) == ["sql10", "postgres18"])
        #expect(groups[0].entries.map(\.id) == [ids[0], ids[1], ids[3]])
        #expect(groups[1].entries.map(\.id) == [ids[2], ids[4]])
    }

    @Test func searchMatchesTitleServerDatabaseAndSQLKeepingOrder() {
        #expect(TabOverviewEntry.matching("query", in: entries).map(\.id) == [ids[0], ids[4]])
        #expect(TabOverviewEntry.matching("postgres", in: entries).map(\.id) == [ids[2], ids[4]])
        #expect(TabOverviewEntry.matching("ccsLDK", in: entries).map(\.id) == [ids[3]])
        #expect(TabOverviewEntry.matching("aml", in: entries).map(\.id) == [ids[0]])
        #expect(TabOverviewEntry.matching("  ", in: entries).count == 5)
    }

    @Test func selectionFallsBackToActiveTabThenFirstRow() {
        let model = TabOverviewPaletteModel()
        let shown = model.shown(entries)
        #expect(model.selection(in: shown, activeID: ids[3]) == ids[3])
        #expect(model.selection(in: shown, activeID: nil) == ids[0])
        model.selectedID = ids[2]
        #expect(model.selection(in: shown, activeID: ids[3]) == ids[2])
    }

    @Test func arrowsFollowTheGroupedOrderAndWrap() {
        let model = TabOverviewPaletteModel()
        let shown = model.shown(entries)
        #expect(shown.map(\.id) == [ids[0], ids[1], ids[3], ids[2], ids[4]])
        model.moveSelection(by: 1, in: shown, activeID: ids[3])
        #expect(model.selectedID == ids[2])
        model.moveSelection(by: 2, in: shown, activeID: nil)
        #expect(model.selectedID == ids[0])
        model.moveSelection(by: -1, in: shown, activeID: nil)
        #expect(model.selectedID == ids[4])
    }

    @Test func typingResetsTheSelection() {
        let model = TabOverviewPaletteModel()
        model.selectedID = ids[1]
        model.query = "q"
        #expect(model.selectedID == nil)
    }

    @Test func closingMovesTheSelectionToTheNextRowElseThePrevious() {
        #expect(TabOverviewEntry.neighbour(of: ids[1], in: entries) == ids[2])
        #expect(TabOverviewEntry.neighbour(of: ids[4], in: entries) == ids[3])
        #expect(TabOverviewEntry.neighbour(of: ids[0], in: Array(entries.prefix(1))) == nil)
    }

    @Test func statusReadsTheQueryState() {
        #expect(TabOverviewStatus(isExecuting: true, elapsed: 72, hasError: true, wasCancelled: false, hasRun: true, rows: 0).text == "Running 1:12")
        #expect(TabOverviewStatus(isExecuting: false, elapsed: 0, hasError: true, wasCancelled: false, hasRun: true, rows: 0) == .failed)
        #expect(TabOverviewStatus(isExecuting: false, elapsed: 0, hasError: false, wasCancelled: true, hasRun: true, rows: 3) == .cancelled)
        #expect(TabOverviewStatus(isExecuting: false, elapsed: 0, hasError: false, wasCancelled: false, hasRun: true, rows: 1204).text == "\(1204.formatted()) rows")
        #expect(TabOverviewStatus(isExecuting: false, elapsed: 0, hasError: false, wasCancelled: false, hasRun: true, rows: 1).text == "1 row")
        #expect(TabOverviewStatus(isExecuting: false, elapsed: 0, hasError: false, wasCancelled: false, hasRun: false, rows: 0).text == "Not run")
    }

    @Test func tabOverviewIsThePaletteOnTheTabs() {
        let state = AppState()
        state.toggleTabOverview()
        #expect(state.isCommandPaletteVisible && state.isTabOverviewVisible)
        state.toggleTabOverview()
        #expect(!state.isCommandPaletteVisible)
        #expect(state.commandPaletteScope == .everything)
    }

    @Test func tabOverviewRowKeepsThePaletteOpen() {
        let model = CommandPaletteModel()
        var opened = false
        model.localItems = [CommandPaletteItem(id: "tabOverview", section: .actions, title: "Tab Overview", subtitle: nil,
                                               systemImage: "square.grid.2x2", keepsPaletteOpen: true, perform: { opened = true })]
        #expect(model.performSelected() == false)
        #expect(opened)
    }
}
