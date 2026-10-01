import Foundation
import Testing
import EchoSense
@testable import Echo

/// The run note after a run counts the rows the footer counts, not only the rows already read
/// back into memory (it said "200 rows" for a result with many more).
@MainActor
struct QueryEditorStateRunNoteTests {
    @Test func runNoteCountsEveryRowTheServerReported() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("QueryEditorStateRunNoteTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let spooler = ResultSpooler(configuration: ResultSpoolConfiguration.defaultConfiguration(rootDirectory: root))
        let state = QueryEditorState(sql: "SELECT * FROM ba_history", initialVisibleRowBatch: 500, previewRowLimit: 512, spoolManager: spooler)
        state.startExecution()
        state.lastRunRange = NSRange(location: 0, length: 24)

        let columns = [ColumnInfo(name: "id", dataType: "int4")]
        state.applyStreamUpdate(QueryStreamUpdate(
            columns: columns, appendedRows: (0..<512).map { ["\($0)"] }, encodedRows: [],
            totalRowCount: 512, metrics: nil, rowRange: 0..<512))
        // The server reports the whole result while only the first rows are in memory.
        state.applyStreamUpdate(QueryStreamUpdate(
            columns: columns, appendedRows: [], encodedRows: [],
            totalRowCount: 20_000, metrics: nil, rowRange: nil))
        state.finishExecution()

        let note = try #require(state.runNote)
        let expected = try #require(QueryRunNote.success(range: note.range, rows: 20_000, hasResults: true, duration: state.lastExecutionTime))
        #expect(note.text == expected.text)
        #expect(state.rowProgress.displayCount == 20_000)
    }
}
