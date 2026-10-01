import EchoSense
import Foundation
import Testing
@testable import Echo

@Suite("Run notes (QE2)")
struct QueryRunNoteTests {
    private let range = NSRange(location: 0, length: 10)

    @Test func resultsShowRowsAndTime() {
        let note = QueryRunNote.success(range: range, rows: 10, hasResults: true, duration: 0.034)
        #expect(note?.text == "✓ 10 rows · 34 ms")
        #expect(note?.isError == false)
    }

    @Test func oneRowIsSingular() {
        #expect(QueryRunNote.success(range: range, rows: 1, hasResults: true, duration: 2.5)?.text == "✓ 1 row · 2.5 s")
    }

    @Test func statementsWithoutResultsSayDone() {
        #expect(QueryRunNote.success(range: range, rows: 0, hasResults: false, duration: nil)?.text == "✓ Done")
    }

    @Test func errorsShowTheirFirstLineAndKeepTheRestForTheTooltip() {
        let message = "Invalid column name 'OrderDte'.\nStatement(s) could not be prepared."
        let note = QueryRunNote.failure(range: range, message: message)
        #expect(note?.text == "Invalid column name 'OrderDte'.")
        #expect(note?.detail == message)
        #expect(note?.isError == true)
    }

    @Test func nothingWithoutARange() {
        #expect(QueryRunNote.success(range: nil, rows: 1, hasResults: true, duration: 1) == nil)
        #expect(QueryRunNote.failure(range: nil, message: "x") == nil)
    }

    @Test func longRunsShowMinutes() {
        #expect(QueryRunNote.formatted(125) == "2 min 5 s")
    }
}
