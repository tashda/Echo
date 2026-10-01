import Foundation
import Testing
@testable import Echo

@MainActor
@Suite("Transaction state (round 21): what the footer's status pill follows")
struct QueryTransactionStateTests {
    private func makeState() -> QueryEditorState {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("txn-state-\(UUID().uuidString)")
        let spooler = ResultSpooler(configuration: .defaultConfiguration(rootDirectory: root))
        return QueryEditorState(sql: "BEGIN", initialVisibleRowBatch: 500, previewRowLimit: 512, spoolManager: spooler)
    }

    @Test func openKeepsItsStartAcrossRunsAndFailsInPlace() {
        let state = makeState()
        state.applyTransactionStatus(.open)
        guard case .open(let since) = state.transactionState else { Issue.record("should be open"); return }
        state.applyTransactionStatus(.open)
        #expect(state.transactionState == .open(since: since), "the clock counts from BEGIN, not from the last run")
        state.applyTransactionStatus(.failed)
        #expect(state.transactionState == .failed(since: since))
        state.applyTransactionStatus(.idle)
        #expect(state.transactionState == .none)
    }

    @Test func eachRunRestartsTheReminderClock() {
        let state = makeState()
        state.transactionReminderSent = true
        state.transactionLastActivity = .distantPast
        state.applyTransactionStatus(.open)
        #expect(!state.transactionReminderSent)
        #expect(Date().timeIntervalSince(state.transactionLastActivity) < 5)
    }
}
