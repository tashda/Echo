import EchoSense
import Foundation
import Testing
@testable import Echo

@Suite("Statement focus (QE1)")
struct StatementFocusTests {
    private let script = "SELECT 1;\nSELECT 2;\n\nUPDATE t SET a = 1;"

    @Test func everyStatementIsListedInOrder() {
        #expect(SQLStatementAtCaret.statements(in: script).map(\.text) == ["SELECT 1", "SELECT 2", "UPDATE t SET a = 1"])
    }

    @Test func theCaretPicksItsStatementFromTheList() {
        let statements = SQLStatementAtCaret.statements(in: script)
        let caret = (script as NSString).range(of: "UPDATE").location + 3
        #expect(SQLStatementAtCaret.statement(among: statements, caret: caret)?.text == "UPDATE t SET a = 1")
        #expect(SQLStatementAtCaret.statement(among: statements, caret: 0)?.text == "SELECT 1")
    }

    @Test func listLookupMatchesTheDirectLookup() {
        let statements = SQLStatementAtCaret.statements(in: script)
        for caret in 0...(script as NSString).length {
            #expect(SQLStatementAtCaret.statement(among: statements, caret: caret) == SQLStatementAtCaret.statement(in: script, caret: caret))
        }
    }

    @Test func anEmptyScriptHasNoStatements() {
        #expect(SQLStatementAtCaret.statements(in: "  \n ").isEmpty)
        #expect(SQLStatementAtCaret.statement(among: [], caret: 0) == nil)
    }
}
