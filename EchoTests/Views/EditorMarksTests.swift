import AppKit
import Testing
@testable import Echo

/// Round 28.5: typing a closing bracket flashes its partner.
@MainActor
@Suite("Editor marks")
struct EditorMarksTests {
    @Test func findsThePartnerOfAClosingBracket() {
        let text = "SELECT count(*) FROM t WHERE id IN (1, (2), 3)" as NSString
        let close = text.length - 1
        #expect(SQLTextView.matchingOpenBracket(in: text, closingAt: close) == text.range(of: "(1").location)
        #expect(SQLTextView.matchingOpenBracket(in: text, closingAt: text.range(of: "*)").location + 1) == text.range(of: "(*").location)
    }

    @Test func bracketsInsideQuotesDoNotCount() {
        let text = "WHERE f(a, ')') " as NSString
        let close = text.range(of: "') ").location + 1
        #expect(SQLTextView.matchingOpenBracket(in: text, closingAt: close) == text.range(of: "(").location)
    }

    @Test func aBracketWithNoPartnerFlashesNothing() {
        #expect(SQLTextView.matchingOpenBracket(in: "a)" as NSString, closingAt: 1) == nil)
        #expect(SQLTextView.matchingOpenBracket(in: "a(" as NSString, closingAt: 1) == nil)
    }
}
