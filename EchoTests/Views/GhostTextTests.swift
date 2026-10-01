import Foundation
import Testing
import EchoSense
@testable import Echo

@MainActor
@Suite("EchoSense ghost text (ES3)")
struct GhostTextTests {
    private func suggestion(_ insert: String) -> SQLAutoCompletionSuggestion {
        SQLAutoCompletionSuggestion(title: insert, insertText: insert, kind: .column)
    }

    @Test func showsTheRestOfTheWord() {
        #expect(SQLTextView.ghostSuffix(for: suggestion("CustomerID"), typed: "Cu") == "stomerID")
        #expect(SQLTextView.ghostSuffix(for: suggestion("CustomerID"), typed: "cust") == "omerID")
    }

    @Test func showsNothingWhenTheSuggestionDoesNotContinueTheWord() {
        #expect(SQLTextView.ghostSuffix(for: suggestion("soh.CustomerID"), typed: "Cu") == nil)
        #expect(SQLTextView.ghostSuffix(for: suggestion("Cu"), typed: "Cu") == nil)
        #expect(SQLTextView.ghostSuffix(for: suggestion("CustomerID"), typed: "") == nil)
    }
}
