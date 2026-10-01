import Foundation
#if os(macOS)
import AppKit
#endif

/// Asking before a PostgreSQL or MySQL transaction would be lost (Echo Labs round 21, open transaction on
/// close, accepted): an alert (G2) with Commit as the default button (D1), the sentence, how long it
/// has been open and how many statements ran (DT2), on closing a tab, switching database,
/// disconnecting and quitting (W1). A failed transaction offers Roll Back and Cancel and says it
/// failed (FT1). Quitting with several asks once, listing them: Review, Roll Back All, Cancel (Q1).
/// No "don't ask again" (N1). The state is checked with the server first (K1).
extension EnvironmentState {
    enum OpenTransactionAction: Equatable {
        case closeTab, switchDatabase, disconnect, quit
    }

    /// Whether the tab looks like it has an open transaction (Echo's own tracking; no server call).
    func mayHaveOpenTransaction(_ tab: WorkspaceTab) -> Bool {
        guard tab.connection.databaseType == .postgresql || tab.connection.databaseType == .mysql, let query = tab.query else { return false }
        return query.transactionState != .none
    }

    /// Asks about `tab`'s open transactions before `action`; true when the action may go ahead
    /// (nothing was open, or the user committed or rolled back and it worked).
    func confirmOpenTransactions(in tab: WorkspaceTab, for action: OpenTransactionAction) async -> Bool {
        guard let open = await openTransactions(in: tab) else { return true }
        tab.query?.refreshTransactionState()
        guard !open.isEmpty else { return true }
        let failed = open.allSatisfy(\.failed)
        let choice = await OpenTransactionAlert.ask(tab: tab.title, open: open, action: action)
        switch choice {
        case .cancel:
            return false
        case .commit, .rollBack:
            do {
                try await endTransactions(in: tab, commit: choice == .commit && !failed)
                tab.query?.refreshTransactionState()
                return true
            } catch {
                tab.query?.refreshTransactionState()
                await OpenTransactionAlert.show(error: error, tab: tab.title)
                return false
            }
        }
    }

    /// Several tabs at once (disconnecting a server, quitting): one alert listing them (Q1).
    /// Review brings the first tab to the front and stops; Roll Back All rolls each back.
    func confirmOpenTransactions(in tabs: [WorkspaceTab], for action: OpenTransactionAction) async -> Bool {
        var open: [(tab: WorkspaceTab, transactions: [QueryOpenTransaction])] = []
        for tab in tabs {
            guard let transactions = await openTransactions(in: tab), !transactions.isEmpty else { continue }
            open.append((tab, transactions))
        }
        guard !open.isEmpty else { return true }
        if open.count == 1, action != .quit {
            return await confirmOpenTransactions(in: open[0].tab, for: action)
        }
        switch await OpenTransactionAlert.askForSeveral(open.map { ($0.tab.title, $0.transactions) }, action: action) {
        case .cancel:
            return false
        case .review:
            reveal(NotificationContext(serverName: nil, connectionID: open[0].tab.connection.id, tabID: open[0].tab.id))
            return false
        case .rollBackAll:
            for entry in open {
                try? await endTransactions(in: entry.tab, commit: false)
                entry.tab.query?.refreshTransactionState()
            }
            return true
        }
    }

    /// Tabs whose close was confirmed and may now close without asking again.
    @MainActor private static var confirmedCloses: Set<UUID> = []

    /// The tab store's close check: holds back a tab with an open transaction, asks, and closes it
    /// once the transaction is committed or rolled back. Returns true when it held the close back.
    func holdCloseForOpenTransaction(_ tab: WorkspaceTab) -> Bool {
        if Self.confirmedCloses.remove(tab.id) != nil { return false }
        guard mayHaveOpenTransaction(tab) else { return false }
        Task { @MainActor [weak self] in
            guard let self, await self.confirmOpenTransactions(in: tab, for: .closeTab) else { return }
            Self.confirmedCloses.insert(tab.id)
            self.tabStore.closeTab(id: tab.id)
        }
        return true
    }
}

/// The alerts, in the words the round's pages used.
@MainActor
enum OpenTransactionAlert {
    enum Choice { case commit, rollBack, cancel }
    enum SeveralChoice { case review, rollBackAll, cancel }

    static func ask(tab: String, open: [QueryOpenTransaction], action: EnvironmentState.OpenTransactionAction) async -> Choice {
        let failed = open.allSatisfy(\.failed)
        let text = texts(tab: tab, open: open, action: action)
        let buttons: [(String, Choice, Bool)] = failed
            ? [("Roll Back", .rollBack, false), ("Cancel", .cancel, false)]
            : [("Commit", .commit, false), ("Roll Back", .rollBack, true), ("Cancel", .cancel, false)]
        let index = await present(title: text.title, message: text.message, buttons: buttons.map { ($0.0, $0.2) })
        return buttons[min(index, buttons.count - 1)].1
    }

    static func askForSeveral(_ open: [(tab: String, transactions: [QueryOpenTransaction])],
                              action: EnvironmentState.OpenTransactionAction) async -> SeveralChoice {
        let lines = open.map { entry in
            let databases = entry.transactions.map(\.database).joined(separator: ", ")
            let detail = entry.transactions.first.map { summary($0) } ?? ""
            return "\(entry.tab) · \(databases)\(detail.isEmpty ? "" : " · \(detail)")"
        }
        let title = "\(open.count) tabs have transactions that are not committed"
        let message = lines.joined(separator: "\n") + "\n\n" + (action == .quit
            ? "Quitting rolls them back. Review goes to each tab so you can commit or roll back."
            : "Disconnecting rolls them back. Review goes to each tab so you can commit or roll back.")
        let buttons: [(String, SeveralChoice, Bool)] = [("Review…", .review, false), ("Roll Back All", .rollBackAll, true), ("Cancel", .cancel, false)]
        let index = await present(title: title, message: message, buttons: buttons.map { ($0.0, $0.2) })
        return buttons[min(index, buttons.count - 1)].1
    }

    static func show(error: any Error, tab: String) async {
        _ = await present(title: "\(tab): the transaction was not committed", message: error.localizedDescription, buttons: [("OK", false)])
    }

    /// Title and message (DT2: the sentence, how long it has been open, how many statements).
    static func texts(tab: String, open: [QueryOpenTransaction],
                      action: EnvironmentState.OpenTransactionAction, now: Date = Date()) -> (title: String, message: String) {
        let failed = open.allSatisfy(\.failed)
        let title: String
        switch action {
        case .closeTab: title = failed ? "Close \(tab)?" : "Commit before closing \(tab)?"
        case .switchDatabase: title = failed ? "Switch database?" : "Commit before switching database?"
        case .disconnect: title = failed ? "Disconnect?" : "Commit before disconnecting?"
        case .quit: title = failed ? "Quit Echo?" : "Commit before quitting?"
        }
        let databases = open.map(\.database).joined(separator: ", ")
        var message = failed
            ? "\(tab)'s transaction on \(databases) failed. Nothing can be committed."
            : "\(tab) has a transaction on \(databases) that is not committed."
        if !failed, let first = open.first {
            let detail = summary(first, now: now)
            if !detail.isEmpty { message += "\n" + detail + "." }
        }
        return (title, message)
    }

    /// "Open for 12 minutes · 3 statements".
    static func summary(_ transaction: QueryOpenTransaction, now: Date = Date()) -> String {
        var parts: [String] = []
        if let started = transaction.startedAt {
            let minutes = Int(now.timeIntervalSince(started) / 60)
            parts.append(minutes < 1 ? "Open for less than a minute" : "Open for \(minutes) \(minutes == 1 ? "minute" : "minutes")")
        }
        if transaction.statements > 0 {
            parts.append("\(transaction.statements) \(transaction.statements == 1 ? "statement" : "statements")")
        }
        return parts.joined(separator: " · ")
    }

    /// Shows the alert as a sheet on the key window (or on its own) and returns the button's index.
    private static func present(title: String, message: String, buttons: [(String, Bool)]) async -> Int {
        #if os(macOS)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        for (label, destructive) in buttons {
            let button = alert.addButton(withTitle: label)
            button.hasDestructiveAction = destructive
        }
        let response: NSApplication.ModalResponse
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            response = await alert.beginSheetModal(for: window)
        } else {
            response = alert.runModal()
        }
        return response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        #else
        return buttons.count - 1
        #endif
    }
}
