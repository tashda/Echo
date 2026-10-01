import Testing
@testable import Echo

/// Round 28.9: Tab, ⇧Tab, Return, closing pairs and ⌘/.
@Suite("Editor typing")
struct EditorTypingTests {
    @Test func tabReachesTheNextStopOfFour() {
        #expect(SQLEditorTyping.softTab(atColumn: 0) == "    ")
        #expect(SQLEditorTyping.softTab(atColumn: 2) == "  ")
        #expect(SQLEditorTyping.softTab(atColumn: 4) == "    ")
    }

    @Test func indentAndOutdentWholeLines() {
        #expect(SQLEditorTyping.indented(["SELECT 1", "", "FROM t"]) == ["    SELECT 1", "", "    FROM t"])
        #expect(SQLEditorTyping.outdented(["      AND x", "\tAND y", "z"]) == ["  AND x", "AND y", "z"])
    }

    @Test func returnKeepsTheLeadingWhitespace() {
        #expect(SQLEditorTyping.leadingWhitespace(of: "  AND o.total >= 100") == "  ")
        #expect(SQLEditorTyping.leadingWhitespace(of: "SELECT") == "")
    }

    @Test func commentToggleAddsAtTheSmallestIndentAndRemoves() {
        let lines = ["  AND a = 1", "    AND b = 2", ""]
        let commented = SQLEditorTyping.toggledComment(lines)
        #expect(commented == ["  -- AND a = 1", "  --   AND b = 2", ""])
        #expect(SQLEditorTyping.toggledComment(commented) == lines)
    }

    @Test func bracketsAndQuotesCloseOnlyWhereTheyShould() {
        #expect(SQLEditorTyping.autoCloser(for: "(", before: nil, after: "t") == ")")
        #expect(SQLEditorTyping.autoCloser(for: "(", before: "x", after: " ") == nil)
        #expect(SQLEditorTyping.autoCloser(for: "'", before: nil, after: " ") == "'")
        #expect(SQLEditorTyping.autoCloser(for: "'", before: nil, after: "n") == nil)
        #expect(SQLEditorTyping.stepsOver(")", next: ")"))
        #expect(!SQLEditorTyping.stepsOver(")", next: " "))
    }
}
