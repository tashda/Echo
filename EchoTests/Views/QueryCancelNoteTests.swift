import Foundation
import Testing
@testable import Echo

@Suite("Cancelling a query (round 21): run note and Messages wording")
struct QueryCancelNoteTests {
    @Test func cancelledTextSaysHowLongAndHowManyRows() {
        #expect(QueryRunNote.cancelledText(duration: 3.2, rows: 1200) == "Cancelled after \(String(format: "%.1f", 3.2)) s · \(1200.formatted(.number)) rows")
        #expect(QueryRunNote.cancelledText(duration: 0.25, rows: 0) == "Cancelled after 250 ms")
        #expect(QueryRunNote.cancelledText(duration: nil, rows: 1) == "Cancelled · 1 row")
    }

    @Test func theNoteIsOrangeAndCanSayTheTransactionNeedsRollback() throws {
        let note = try #require(QueryRunNote.cancelled(range: NSRange(location: 0, length: 5), duration: 1.5, rows: 10))
        #expect(note.isWarning && !note.isError)
        #expect(note.needingRollback().text == "Cancelled after \(String(format: "%.1f", 1.5)) s · 10 rows · The transaction now needs ROLLBACK")
    }
}
