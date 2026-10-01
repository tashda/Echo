import EchoSense
import Foundation
import SQLServerKit
import Testing
@testable import Echo

@Suite("Error mark in the editor (round 21 EM5, round 22 ED1)")
struct QueryErrorMarkerTests {
    private static func sqlServerError(_ number: Int32, _ text: String, line: Int32, procedure: String = "") -> SQLServerError {
        SQLServerError.fromServerMessages([
            SQLServerStreamMessage(kind: .info, number: 0, message: "loading", state: 1, severity: 0,
                                   serverName: "sql01", procedureName: "", lineNumber: 1),
            SQLServerStreamMessage(kind: .error, number: number, message: text, state: 1, severity: 16,
                                   serverName: "sql01", procedureName: procedure, lineNumber: line),
        ])!
    }

    private static func marked(_ mark: QueryErrorMark?, in editor: String) -> String? {
        mark.map { (editor as NSString).substring(with: $0.range) }
    }

    // MARK: - SQL Server

    @Test func invalidColumnMarksTheWordWithAFix() throws {
        let editor = "-- orders\nSELECT id,\n       stats, total\nFROM dbo.orders;\n"
        let sent = "SELECT id,\n       stats, total\nFROM dbo.orders;"
        let runRange = (editor as NSString).range(of: sent)
        let error = Self.sqlServerError(207, "Invalid column name 'stats'.", line: 2)
        let mark = try #require(QueryErrorMarker.mark(for: error, sentSQL: sent, editorText: editor, runRange: runRange,
                                                      columnCandidates: ["id", "status", "total", "customer_id"]))
        #expect(Self.marked(mark, in: editor) == "stats")
        #expect(mark.line == 3)
        #expect(mark.message == "Invalid column name 'stats'.")
        #expect(mark.fix == .init(title: "Use status", replacement: "status"))
        // Wrapped in DatabaseError as the sessions throw it, it reads the same.
        let wrapped = DatabaseError.from(sqlServerError: error)
        #expect(QueryErrorMarker.mark(for: wrapped, sentSQL: sent, editorText: editor, runRange: runRange) != nil)
    }

    @Test func linesEchoAddedInFrontAreSkipped() throws {
        let editor = "SELECT 1;\nSELECT nope FROM t;"
        let sent = "SET STATISTICS IO ON;\nSET STATISTICS TIME ON;\n" + editor
        let error = Self.sqlServerError(207, "Invalid column name 'nope'.", line: 4)
        let mark = try #require(QueryErrorMarker.mark(for: error, sentSQL: sent, editorText: editor, runRange: nil))
        #expect(Self.marked(mark, in: editor) == "nope")
        #expect(mark.line == 2)
        #expect(QueryErrorMarker.editorLine(forSentLine: 4, sentSQL: sent, editorText: editor, runRange: nil) == 2)
    }

    @Test func withoutANamedObjectTheWholeLineIsMarked() throws {
        let editor = "BEGIN TRANSACTION;\n    INSERT INTO dbo.orders (customer_id) VALUES (999);  \nCOMMIT;"
        let error = Self.sqlServerError(547, "The INSERT statement conflicted with the FOREIGN KEY constraint \"FK_orders_customer\".", line: 2)
        let mark = try #require(QueryErrorMarker.mark(for: error, sentSQL: editor, editorText: editor, runRange: nil))
        #expect(Self.marked(mark, in: editor) == "INSERT INTO dbo.orders (customer_id) VALUES (999);")
        #expect(mark.fix == nil)
    }

    @Test func anErrorInsideAProcedureMarksTheCall() throws {
        let editor = "BEGIN TRANSACTION;\nEXEC dbo.load_orders @batch = 1;\nCOMMIT;"
        let error = Self.sqlServerError(50000, "boom", line: 12, procedure: "load_orders")
        let mark = try #require(QueryErrorMarker.mark(for: error, sentSQL: editor, editorText: editor, runRange: nil))
        #expect(Self.marked(mark, in: editor) == "EXEC dbo.load_orders")
        #expect(mark.line == 2)
        #expect(mark.detail == "load_orders, line 12")
    }

    @Test func noMarkWhenTheSQLIsNotInTheEditor() {
        let error = Self.sqlServerError(207, "Invalid column name 'x'.", line: 1)
        #expect(QueryErrorMarker.mark(for: error, sentSQL: "SELECT x", editorText: "SELECT y", runRange: nil) == nil)
        #expect(QueryErrorMarker.mark(for: DatabaseError.queryError("x"), sentSQL: "SELECT x", editorText: "SELECT x", runRange: nil) == nil)
    }

    // MARK: - PostgreSQL

    @Test func postgresPositionMarksTheWordAndTheHintFixesIt() throws {
        let editor = "select order_id,\n       stats, total from orders\nwhere status = 'paid';"
        let position = (editor as NSString).range(of: "stats").location + 1
        let pointer = QueryErrorMarker.PostgresPointer(
            message: "column \"stats\" does not exist", position: position,
            hint: "Perhaps you meant to reference the column \"orders.status\".", context: nil)
        let mark = try #require(QueryErrorMarker.mark(postgres: pointer, sentSQL: editor, editorText: editor, runRange: nil))
        #expect(Self.marked(mark, in: editor) == "stats")
        #expect(mark.line == 2)
        #expect(mark.detail == "Perhaps you meant to reference the column \"orders.status\".")
        #expect(mark.fix == .init(title: "Use orders.status", replacement: "status"))
    }

    @Test func postgresQualifiedTypoKeepsItsQualifier() {
        let fix = QueryErrorMarker.postgresFix(hint: "Perhaps you meant to reference the column \"o.status\".", markedWord: "o.stats")
        #expect(fix == .init(title: "Use o.status", replacement: "o.status"))
        #expect(QueryErrorMarker.postgresFix(hint: "No function matches the given name.", markedWord: "f") == nil)
    }

    @Test func postgresErrorInsideAFunctionMarksTheCall() throws {
        let editor = "select load_orders(1);"
        let pointer = QueryErrorMarker.PostgresPointer(
            message: "boom", position: nil, hint: nil,
            context: "PL/pgSQL function load_orders(integer) line 12 at RAISE")
        let mark = try #require(QueryErrorMarker.mark(postgres: pointer, sentSQL: editor, editorText: editor, runRange: nil))
        #expect(Self.marked(mark, in: editor) == "load_orders")
        #expect(mark.detail == "load_orders, line 12")
    }

    // MARK: - Helpers

    @Test func closestNameOnlyAcceptsNearMisses() {
        #expect(QueryErrorMarker.closestName(to: "stats", among: ["status", "state", "total"]) == "state")
        #expect(QueryErrorMarker.closestName(to: "custmer_id", among: ["customer_id", "id"]) == "customer_id")
        #expect(QueryErrorMarker.closestName(to: "xyz", among: ["status", "total"]) == nil)
        #expect(QueryErrorMarker.editDistance("kitten", "sitting") == 3)
    }

    @Test func messagesShowTheSSMSHeader() {
        let error = QueryExecutionMessage(index: 1, message: "boom", severity: .error, procedure: "dbo.load_orders", line: 12,
                                          metadata: ["messageNumber": "50000", "level": "16", "state": "1"])
        #expect(error.ssmsHeader == "Msg 50000, Level 16, State 1, Procedure dbo.load_orders")
        let info = QueryExecutionMessage(index: 2, message: "Changed database context", severity: .info, line: 1,
                                         metadata: ["messageNumber": "5701", "level": "10", "state": "1"])
        #expect(info.ssmsHeader == nil)
    }

    @Test func shortRunNoteCarriesTheWholeMessageInItsTooltip() throws {
        let note = try #require(QueryRunNote.shortFailure(range: NSRange(location: 0, length: 4), message: "column \"stats\" does not exist"))
        #expect(note.text == "! Error")
        #expect(note.detail == "column \"stats\" does not exist")
        #expect(note.isError)
    }
}
