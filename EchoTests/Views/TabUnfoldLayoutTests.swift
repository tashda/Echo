import Foundation
import Testing
@testable import Echo

@Suite("Tool tab pages in the tab bar")
struct TabUnfoldLayoutTests {
    private let ids = (0..<4).map { _ in UUID() }

    @Test func unfoldedTabTakesItsIdealWidthAndOthersShareTheRest() {
        let widths = TabUnfoldLayout.widths(tabIDs: ids, unfoldedID: ids[0], idealUnfoldedWidth: 400, equalWidth: 200, totalWidth: 800)
        #expect(widths[ids[0]] == 400)
        #expect(widths[ids[1]] == 400.0 / 3)
        #expect(abs(widths.values.reduce(0, +) - 800) < 0.001)
    }

    @Test func unfoldedTabNeverTakesMoreThanItsShare() {
        let widths = TabUnfoldLayout.widths(tabIDs: ids, unfoldedID: ids[1], idealUnfoldedWidth: 2_000, equalWidth: 200, totalWidth: 800)
        #expect(widths[ids[1]] == 800 * LayoutTokens.TabPages.maxShareOfStrip)
    }

    /// Round 36.1, RW1: exactly as wide as its title and pages, even when that is narrower.
    @Test func narrowerTabKeepsItsOwnWidth() {
        let widths = TabUnfoldLayout.widths(tabIDs: ids, unfoldedID: ids[0], idealUnfoldedWidth: 150, equalWidth: 200, totalWidth: 800)
        #expect(widths[ids[0]] == 150)
        #expect(widths[ids[2]] == 650.0 / 3)
    }

    @Test func noChangeWhenTheIdealIsTheEqualWidth() {
        #expect(TabUnfoldLayout.widths(tabIDs: ids, unfoldedID: ids[0], idealUnfoldedWidth: 200, equalWidth: 200, totalWidth: 800).isEmpty)
    }

    /// Round 36.1, SW1: a lone tool tab keeps its own width at the leading edge.
    @Test func aLoneTabKeepsItsOwnWidth() {
        #expect(TabUnfoldLayout.widths(tabIDs: [ids[0]], unfoldedID: ids[0], idealUnfoldedWidth: 420, equalWidth: 900, totalWidth: 900) == [ids[0]: 420])
    }

    @Test func aLoneTabWiderThanTheStripFillsIt() {
        #expect(TabUnfoldLayout.widths(tabIDs: [ids[0]], unfoldedID: ids[0], idealUnfoldedWidth: 600, equalWidth: 300, totalWidth: 300).isEmpty)
    }

    @Test func anUnknownTabChangesNothing() {
        #expect(TabUnfoldLayout.widths(tabIDs: ids, unfoldedID: UUID(), idealUnfoldedWidth: 400, equalWidth: 200, totalWidth: 800).isEmpty)
    }

    @MainActor
    @Test func idealWidthDoesNotDependOnTheShownPage() {
        let pages = ["Processes", "Waits", "I/O"]
        let width = TabPageChipsMetrics.idealWidth(title: "Activity Monitor", pages: pages)
        #expect(width > LayoutTokens.TabPages.tabChrome)
        #expect(width == TabPageChipsMetrics.idealWidth(title: "Activity Monitor", pages: pages))
        #expect(TabPageChipsMetrics.idealWidth(title: "Activity Monitor", pages: pages + ["Queries"]) > width)
    }

    @MainActor
    @Test func activityMonitorPagesPerEngine() {
        #expect(MSSQLActivityMonitorView.MSSQLActivitySection.allCases.first?.rawValue == "Processes")
        #expect(!PostgresActivityMonitorView.PostgresActivitySection.allCases.isEmpty)
        #expect(MySQLActivityMonitorView.MySQLActivitySection.allCases.first?.rawValue == "Overview")
    }
}
