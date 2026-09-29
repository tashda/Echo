import Foundation
import Testing
@testable import Echo

@Suite("Statement at caret")
struct SQLStatementAtCaretTests {
    private func statement(_ sql: String, caretBefore marker: String) -> String? {
        let caret = (sql as NSString).range(of: marker).location
        return SQLStatementAtCaret.statement(in: sql.replacingOccurrences(of: marker, with: ""), caret: caret)?.text
    }

    @Test func splitsOnSemicolons() {
        #expect(statement("SELECT 1; SELECT |2; SELECT 3;", caretBefore: "|") == "SELECT 2")
    }

    @Test func splitsOnBlankLines() {
        let sql = "SELECT *\nFROM a\n\nSELECT *\nFROM |b"
        #expect(statement(sql, caretBefore: "|") == "SELECT *\nFROM b")
    }

    @Test func splitsOnGo() {
        let sql = "SELECT 1\nGO\nSELECT |2\ngo\n"
        #expect(statement(sql, caretBefore: "|") == "SELECT 2")
    }

    @Test func ignoresDelimitersInQuotesAndComments() {
        let sql = "SELECT 'a;b', [x;y] -- c;d\nFROM |t /* e;\n\nf */;"
        #expect(statement(sql, caretBefore: "|") == "SELECT 'a;b', [x;y] -- c;d\nFROM t /* e;\n\nf */")
    }

    @Test func dollarQuotedBodiesStayWhole() {
        let sql = "CREATE FUNCTION f() RETURNS int AS $$ SELECT 1; $$ LANGUAGE sql;|"
        #expect(statement(sql, caretBefore: "|") == "CREATE FUNCTION f() RETURNS int AS $$ SELECT 1; $$ LANGUAGE sql")
    }

    @Test func caretAfterLastStatementPicksIt() {
        #expect(statement("SELECT 1;\n\n|", caretBefore: "|") == "SELECT 1")
    }

    @Test func emptyScriptHasNone() {
        #expect(SQLStatementAtCaret.statement(in: "  \n\n ", caret: 1) == nil)
    }

    @Test func rangeCoversTheText() throws {
        let sql = "SELECT 1;\nSELECT 2;"
        let match = try #require(SQLStatementAtCaret.statement(in: sql, caret: 12))
        #expect((sql as NSString).substring(with: match.range) == match.text)
    }
}

@Suite("Workspace toolbar context")
struct WorkspaceToolbarContextTests {
    @Test func queryTabsShowRunAndEditorActions() {
        let context = WorkspaceToolbarContext(kind: .query, databaseType: .postgresql)
        #expect(context.isQuery && !context.hasTabTools && !context.hasDatabaseToggles)
    }

    @Test func sqlServerQueryTabsShowToggles() {
        #expect(WorkspaceToolbarContext(kind: .query, databaseType: .microsoftSQL).hasDatabaseToggles)
    }

    @Test func toolTabsShowTheContextualCapsule() {
        for kind in [WorkspaceTab.Kind.structure, .activityMonitor, .jobQueue, .errorLog, .maintenance, .mssqlMaintenance] {
            let context = WorkspaceToolbarContext(kind: kind, databaseType: .microsoftSQL)
            #expect(context.hasTabTools && !context.isQuery)
        }
    }

    @Test func noTabShowsNeither() {
        #expect(WorkspaceToolbarContext(kind: nil, databaseType: nil) == WorkspaceToolbarContext(kind: .diagram, databaseType: nil))
    }
}
