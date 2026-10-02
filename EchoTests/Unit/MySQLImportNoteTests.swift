import MySQLKit
import Testing
@testable import Echo

/// What a MySQL import says besides its count (round 25, ME1).
@Suite("MySQL import notes")
struct MySQLImportNoteTests {
    @Test func loadDataSaysNothingExtra() {
        #expect(BulkImportViewModel.completionNote(for: MySQLImportSummary(method: .loadDataLocal, rowCount: 3, batches: 1, warnings: [])) == nil)
    }

    @Test func insertsAndWarningsAreSaid() {
        let note = BulkImportViewModel.completionNote(for: MySQLImportSummary(
            method: .insertStatements, rowCount: 3, batches: 1,
            warnings: [MySQLWarning(level: "Warning", code: 1265, message: "Data truncated for column 'a' at row 1"),
                       MySQLWarning(level: "Warning", code: 1265, message: "Data truncated for column 'a' at row 2")]
        ))
        #expect(note?.contains("INSERT statements") == true)
        #expect(note?.contains("Data truncated for column 'a' at row 1, and 1 more") == true)
    }
}
