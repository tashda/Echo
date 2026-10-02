import Foundation
import Testing
@testable import Echo

@Suite("Script results (round 21): labels, editor ranges, entries and Messages lines")
struct ScriptResultEntryTests {
    @Test func labelsAreTheStatementsFirstWords() {
        #expect(ScriptResultEntry.label(for: "SELECT id, name FROM customers WHERE id > 3") == "SELECT … FROM customers")
        #expect(ScriptResultEntry.label(for: "select * from public.orders o") == "SELECT … FROM public.orders")
        #expect(ScriptResultEntry.label(for: "UPDATE orders SET status = 'paid'") == "UPDATE orders SET")
        #expect(ScriptResultEntry.label(for: "create temp table picks (id int)") == "CREATE TEMP TABLE")
        #expect(ScriptResultEntry.label(for: "-- load\n/* note */ INSERT INTO picks VALUES (1)") == "INSERT INTO picks")
        #expect(ScriptResultEntry.label(for: "SELECT 1") == "SELECT 1")
    }

    @Test func editorRangesAreFoundInOrderWithinWhatRan() {
        let text = "-- top\nSELECT 1;\nSELECT 1;\nUPDATE t SET a = 1;"
        let ranges = ScriptResultEntry.editorRanges(for: ["SELECT 1", "SELECT 1", "UPDATE t SET a = 1"], in: text, within: nil)
        let ns = text as NSString
        #expect(ranges.compactMap { $0 }.map { ns.substring(with: $0) } == ["SELECT 1", "SELECT 1", "UPDATE t SET a = 1"])
        #expect(ranges[0]!.location < ranges[1]!.location)
        let selected = ScriptResultEntry.editorRanges(for: ["SELECT 1"], in: text, within: NSRange(location: 17, length: 10))
        #expect(selected[0]?.location == 17)
        #expect(ScriptResultEntry.editorRanges(for: ["DELETE FROM x"], in: text, within: nil) == [nil])
    }

    @Test func entriesLeaveOutStatementsThatDidNotRun() {
        let set = QueryResultSet(columns: [ColumnInfo(name: "id", dataType: "INT4(23)")], rows: [["1"], ["2"]], totalRowCount: 2)
        var failed = BatchResult(batchIndex: 2, resultSets: [], error: "duplicate key", messages: [])
        failed.duration = 0.004
        var skipped = BatchResult(batchIndex: 3, resultSets: [], error: nil, messages: [])
        skipped.skipped = true
        let results = [
            BatchResult(batchIndex: 0, resultSets: [], error: nil, messages: [ServerMessage(kind: .info, number: 0, message: "INSERT 0 2", state: 0, severity: 0, serverName: nil, procedureName: nil, lineNumber: nil, category: "Server Response", metadata: [:])]),
            BatchResult(batchIndex: 1, resultSets: [set], error: nil, messages: []),
            failed, skipped,
        ]
        let entries = ScriptResultEntry.entries(for: results, statements: ["INSERT INTO t VALUES (1), (2)", "SELECT id FROM t", "INSERT INTO t VALUES (1)", "SELECT 1"], editorRanges: [nil, nil, nil, nil])
        #expect(entries.map(\.id) == [0, 1, 2])
        #expect(entries[0].outcome == .command(tag: "INSERT 0 2"))
        #expect(entries[1].outcome == .rows(resultSetIndex: 0, count: 2))
        #expect(entries[2].isFailure)
        #expect(entries[0].messageLine == "1 · INSERT 0 2")
        #expect(entries[1].messageLine == "2 · 2 rows")
        #expect(entries[2].messageLine == "3 · ERROR: duplicate key")
    }

    @Test func summaryLinesSayWhatDidNotRunAndWhatHappenedToTheTransaction() {
        var skipped = BatchResult(batchIndex: 2, resultSets: [], error: nil, messages: [])
        skipped.skipped = true
        let results = [BatchResult(batchIndex: 0, resultSets: [], error: nil, messages: []),
                       BatchResult(batchIndex: 1, resultSets: [], error: "boom", messages: []), skipped]
        #expect(PostgresScriptSummary.lines(results: results, transaction: .notRequested).map(\.text) == ["Stopped: statement 2 failed; statement 3 was not run."])
        #expect(PostgresScriptSummary.lines(results: results, transaction: .rolledBack(failedStatement: 1)).last?.text == "Ran as one transaction: rolled back because statement 2 failed. Nothing was saved.")
        #expect(PostgresScriptSummary.numbers([5, 6, 7]) == "statements 5 to 7 were")
    }
}
