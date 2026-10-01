import AppKit
import Testing
@testable import Echo

@MainActor
@Suite("Result column sizing")
struct ResultColumnSizingTests {
    private typealias Coordinator = QueryResultsTableView.Coordinator

    @Test func measuresOnlyTheLongestValues() {
        let values: [(text: NSString, kind: Int)] = (1...40).map { (String(repeating: "x", count: $0) as NSString, 0) }
        let picked = Coordinator.longestValues(values, limit: 5)
        #expect(picked.map(\.text.length) == [40, 39, 38, 37, 36])
    }

    @Test func keepsEveryValueUnderTheLimit() {
        let values: [(text: NSString, kind: Int)] = [("a", 0), ("bbb", 1)]
        #expect(Coordinator.longestValues(values, limit: 5).count == 2)
    }
}
