import Foundation
import Testing
@testable import Echo

@MainActor
@Suite("Open transaction on close (round 21): the alert's words")
struct OpenTransactionAlertTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func open(minutes: Double, statements: Int, failed: Bool = false) -> PostgresPinnedSessionStore.OpenTransaction {
        .init(database: "shop", failed: failed, startedAt: now.addingTimeInterval(-minutes * 60), statements: statements)
    }

    @Test func closingSaysWhatIsOpenForHowLongAndHowManyStatements() {
        let text = OpenTransactionAlert.texts(tab: "Query 1", open: [open(minutes: 12.5, statements: 3)], action: .closeTab, now: now)
        #expect(text.title == "Commit before closing Query 1?")
        #expect(text.message == "Query 1 has a transaction on shop that is not committed.\nOpen for 12 minutes · 3 statements.")
    }

    @Test func eachActionHasItsTitle() {
        let transactions = [open(minutes: 1, statements: 1)]
        #expect(OpenTransactionAlert.texts(tab: "Q", open: transactions, action: .switchDatabase, now: now).title == "Commit before switching database?")
        #expect(OpenTransactionAlert.texts(tab: "Q", open: transactions, action: .disconnect, now: now).title == "Commit before disconnecting?")
        #expect(OpenTransactionAlert.texts(tab: "Q", open: transactions, action: .quit, now: now).title == "Commit before quitting?")
    }

    @Test func aFailedTransactionSaysNothingCanBeCommitted() {
        let text = OpenTransactionAlert.texts(tab: "Query 1", open: [open(minutes: 3, statements: 2, failed: true)], action: .closeTab, now: now)
        #expect(text.title == "Close Query 1?")
        #expect(text.message == "Query 1's transaction on shop failed. Nothing can be committed.")
    }

    @Test func shortTransactionsAndSingleStatements() {
        #expect(OpenTransactionAlert.summary(open(minutes: 0.2, statements: 1), now: now) == "Open for less than a minute · 1 statement")
        #expect(OpenTransactionAlert.summary(open(minutes: 1, statements: 0), now: now) == "Open for 1 minute")
    }
}
