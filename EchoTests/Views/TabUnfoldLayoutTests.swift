import Foundation
import Testing
@testable import Echo

@Suite("Tool tab unfolding in the tab bar")
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

    @Test func noChangeWhenTheEqualWidthIsEnough() {
        #expect(TabUnfoldLayout.widths(tabIDs: ids, unfoldedID: ids[0], idealUnfoldedWidth: 150, equalWidth: 200, totalWidth: 800).isEmpty)
    }

    @Test func aSingleTabNeverUnfolds() {
        #expect(TabUnfoldLayout.widths(tabIDs: [ids[0]], unfoldedID: ids[0], idealUnfoldedWidth: 600, equalWidth: 300, totalWidth: 300).isEmpty)
    }

    @MainActor
    @Test func activityMonitorPagesPerEngine() {
        #expect(MSSQLActivityMonitorView.MSSQLActivitySection.allCases.first?.rawValue == "Processes")
        #expect(!PostgresActivityMonitorView.PostgresActivitySection.allCases.isEmpty)
        #expect(MySQLActivityMonitorView.MySQLActivitySection.allCases.first?.rawValue == "Overview")
    }
}
