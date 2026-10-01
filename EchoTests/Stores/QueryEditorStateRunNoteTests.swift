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

    /// Round 28.7 (MS0): a script that ran statement by statement gets one note per statement.
    @Test func aScriptGetsOneNotePerStatement() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("RunNotes-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let state = QueryEditorState(sql: "", spoolManager: ResultSpooler(configuration: ResultSpoolConfiguration.defaultConfiguration(rootDirectory: root)))
        state.runNote = QueryRunNote.success(range: NSRange(location: 0, length: 40), rows: 3, hasResults: true, duration: 1)
        state.scriptEntries = [
            ScriptResultEntry(id: 0, label: "SELECT", outcome: .rows(resultSetIndex: 0, count: 3), duration: 0.5, editorRange: NSRange(location: 0, length: 20)),
            ScriptResultEntry(id: 1, label: "UPDATE", outcome: .command(tag: "UPDATE 2"), duration: 0.5, editorRange: NSRange(location: 21, length: 19)),
        ]
        let notes = state.runNotes
        #expect(notes.count == 2)
        #expect(notes.last?.text.hasPrefix("✓ UPDATE 2") == true)
        state.scriptEntries = nil
        #expect(state.runNotes.count == 1)
    }
}
