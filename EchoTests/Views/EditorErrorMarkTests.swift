import Testing
@testable import Echo

/// Round 28.6: a mistake found while typing says in its bubble what kind it is and what is wrong.
@Suite("Editor error marks")
struct EditorErrorMarkTests {
    @Test func bubblesNameTheKindOfMistake() {
        let table = ErrorBubbleContent(diagnostic: SQLDiagnostic(message: "", severity: .error, kind: .unknownTable, confidence: .high, token: "custmers"))
        #expect(table.title == "Unknown table")
        #expect(table.message == "No table named 'custmers'.")
        let syntax = ErrorBubbleContent(diagnostic: SQLDiagnostic(message: "Unexpected FROM", severity: .error, kind: .syntaxError, confidence: .high, token: ""))
        #expect(syntax.title == "Syntax error")
        #expect(syntax.message == "Unexpected FROM")
    }

    @Test func theLiveCheckWaitsTwoSeconds() {
        #expect(LayoutTokens.EditorGutter.liveCheckPause == 2)
    }
}
