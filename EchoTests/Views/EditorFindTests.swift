import Foundation
import Testing
@testable import Echo

/// Rounds 28.12 and 28.13: the editor's own find.
@MainActor
@Suite("Editor find")
struct EditorFindTests {
    private let script = "FROM orders AS o\nJOIN Orders_2026 o2\nUPDATE orders SET x = 1" as NSString

    @Test func findsEveryMatchIgnoringCaseByDefault() {
        let matches = EditorFind.matches(of: "orders", in: script)
        #expect(matches.count == 3)
        #expect(matches.first == NSRange(location: 5, length: 6))
    }

    @Test func matchCaseAndWholeWordsNarrowTheMatches() {
        #expect(EditorFind.matches(of: "orders", in: script, matchCase: true).count == 2)
        #expect(EditorFind.matches(of: "orders", in: script, wholeWords: true).count == 2)
    }

    @Test func aScopeLimitsTheSearch() {
        let firstLine = NSRange(location: 0, length: 16)
        #expect(EditorFind.matches(of: "orders", in: script, scope: firstLine).count == 1)
    }

    @Test func theCountSaysWhatReplaceAllDid() {
        let find = EditorFind()
        find.matches = [NSRange(location: 0, length: 1), NSRange(location: 2, length: 1)]
        #expect(find.countText == "2 found")
        find.status = "Replaced 2"
        #expect(find.countText == "Replaced 2")
        find.query = "x"
        #expect(find.countText == "2 found")
    }

    @Test func nothingToFindFindsNothing() {
        #expect(EditorFind.matches(of: "", in: script).isEmpty)
    }
}
