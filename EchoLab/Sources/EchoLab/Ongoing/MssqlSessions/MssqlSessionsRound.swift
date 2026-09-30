import SwiftUI

/// Round 22 · SQL Server: cancel, timeouts and lost connections. With sqlserver-nio's new request
/// pipeline, ■ cancels the statement on the server and waits for SQL Server's acknowledgement, and
/// the query tab's session survives. Echo today throws the session away after every cancel
/// (temporary tables, SET options and an open transaction vanish without a word), stops any
/// non-streamed query after a fixed 45 seconds while it keeps running on the server, ignores the
/// connection's Query Timeout, and never recovers a tab whose connection dropped. Touches EDT-3.3,
/// EDT-4.3/4.4 (behaviour only), FTR-2.6 and CON-4.5; the looks follow the Postgres pages of round 21.
@MainActor
enum MssqlSessionsRound {
    enum Scenario: String, CaseIterable {
        case cancel = "Cancel a query, then use #staging"
        case long = "A query that runs 50 seconds"
        case dropped = "The server drops the connection"
    }
    enum Timeout: String, CaseIterable {
        case followPostgres = "TO1 · Follow the Postgres timeouts decision"
        case none = "TO2 · No limit unless the connection sets one"
        case today = "TO3 · A fixed 45 seconds (today)"
    }
    enum Dropped: String, CaseIterable {
        case reconnectAndSay = "LC1 · Reconnect on the next Run, and say what was lost"
        case reconnectSilently = "LC2 · Reconnect on the next Run, silently"
        case today = "LC3 · Keep failing until the tab is reopened (today)"
    }

    private static let width: CGFloat = 620
    private static let height: CGFloat = 400

    static let spec = RoundSpec(
        controls: [
            .of("scenario", "Scenario", Scenario.self, default: .cancel),
            .of("timeout", "Query time limit", Timeout.self, default: .followPostgres,
                question: "Pick 'A query that runs 50 seconds'. When should Echo stop a long query, and where is that set?",
                recommend: .followPostgres,
                why: "You already picked TW2 on the Postgres timeouts page (a Settings default that a connection can override); one rule for every engine is less to learn. The limit becomes the driver's request deadline, which cancels on the server. Today's 45 seconds is hard-coded, ignores the connection's Query Timeout and leaves the query running on the server."),
            .of("dropped", "Dropped connection", Dropped.self, default: .reconnectAndSay,
                question: "Pick 'The server drops the connection', then Run again. What should happen?",
                recommend: .reconnectAndSay,
                why: "A new session is the only way forward, but it has lost the temporary tables, SET options and any open transaction, so Echo must say so (the Postgres connection-lost page decides how it looks). Silent reconnects make the next statement fail in confusing ways; today the tab is dead until reopened."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Cancel reconnects and loses #staging; 45 s kills the wait but not the query; a dropped tab stays broken.",
                  isEchoToday: true, designWidth: width, designHeight: height) { values in
                MssqlSessionsExhibit(scenario: Scenario(rawValue: values["scenario"]) ?? .cancel, timeout: .today, dropped: .today, today: true)
            },
            .init(id: "proposal", title: "Proposal", summary: "Cancel keeps the session; the limit comes from Settings and the connection; a dropped tab reconnects and says what was lost.",
                  designWidth: width, designHeight: height) { values in
                MssqlSessionsExhibit(scenario: Scenario(rawValue: values["scenario"]) ?? .cancel,
                                     timeout: Timeout(rawValue: values["timeout"]) ?? .followPostgres,
                                     dropped: Dropped(rawValue: values["dropped"]) ?? .reconnectAndSay,
                                     today: false)
            },
        ],
        questions: [
            .init(id: "cancelLook", title: "How cancelling looks",
                  question: "Should SQL Server tabs use exactly what you decide on the Postgres cancel page (the 'Stopping…' state, rows already fetched, a stuck cancel)?",
                  choices: [
                      .init(id: "same", name: "CL1 · Yes, one design for both engines"),
                      .init(id: "own", name: "CL2 · A separate SQL Server design"),
                  ],
                  recommended: "same",
                  why: "Both drivers now cancel on the server and report the same three outcomes (stopped, finished first, no answer after 15 s of silence and the connection closed), so the same design fits."),
            .init(id: "txn", title: "Transactions and cancel",
                  question: "Echo runs SQL Server tabs with XACT_ABORT ON, so a cancelled statement rolls back an open transaction. Should the tab keep that setting?",
                  choices: [
                      .init(id: "on", name: "XA1 · Keep XACT_ABORT ON and say 'Transaction rolled back' after a cancel inside one"),
                      .init(id: "off", name: "XA2 · Turn it off so the transaction stays open after a cancel (SSMS default)"),
                  ],
                  recommended: "on",
                  why: "With it off, a cancelled statement leaves a transaction open holding locks until someone notices; with it on, the state is always clear. The transaction-state page of round 21 shows where the message appears."),
            .init(id: "background", title: "Changes you will not see",
                  question: "These change behaviour without changing any design. Ship them together with this round?",
                  choices: [
                      .init(id: "ship", name: "BG1 · Ship all",
                            summary: "Tabs share threads; APP_NAME() reads 'Echo'; extra result sets stream to disk instead of memory; the query tab's session is used by one task at a time; pooled sidebar queries reuse reset sessions."),
                      .init(id: "list", name: "BG2 · Show me each one first"),
                  ],
                  recommended: "ship",
                  why: "None has a look to judge. Each is covered by the driver's lab tests; together they remove the memory and state problems listed on this page."),
        ],
        exhibitTopic: ("Safer tab?", "Step through the three scenarios in both. Which tab keeps your work and tells you when it cannot?",
                       "proposal",
                       "It keeps the session through a cancel, stops long queries on the server when a limit applies, and recovers from a dropped connection while saying what was lost."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "TO1, LC1.",
                  values: ["timeout": Timeout.followPostgres.rawValue, "dropped": Dropped.reconnectAndSay.rawValue], isRecommended: true),
        ]
    )
}

/// A query tab's Messages for one scenario, as a short timeline.
struct MssqlSessionsExhibit: View {
    typealias R = MssqlSessionsRound
    let scenario: R.Scenario
    let timeout: R.Timeout
    let dropped: R.Dropped
    let today: Bool

    private struct Entry: Identifiable {
        let id = UUID()
        let sql: String?
        let text: String
        var colour: Color = ColorTokens.Text.primary
    }

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                        if let sql = entry.sql {
                            Text(sql).font(TypographyTokens.code).foregroundStyle(ColorTokens.Text.secondary)
                        }
                        Text(entry.text).font(TypographyTokens.detail).foregroundStyle(entry.colour)
                    }
                }
                Spacer(minLength: SpacingTokens.none)
            }
            .padding(SpacingTokens.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .workspaceCard()
            PgFooter(segment: "Messages", database: "sql01 · Sales") {
                PgPill { Text(footerStatus) }
            }
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
    }

    private var footerStatus: String {
        switch scenario {
        case .cancel: "Cancelled"
        case .long: today || timeout != .none ? "Stopped" : "Done in 0:50"
        case .dropped: today || dropped == .today ? "Failed" : "Reconnected"
        }
    }

    private var entries: [Entry] {
        let error = ColorTokens.Status.error
        let warning = ColorTokens.Status.warning
        switch scenario {
        case .cancel:
            let setup = Entry(sql: "SELECT * INTO #staging FROM dbo.orders;", text: "(1,000 rows affected)")
            let cancelled = Entry(sql: "UPDATE #staging SET total = total * 1.1; -- ■ pressed", text: "Query cancelled.")
            if today {
                return [setup, cancelled,
                        Entry(sql: "SELECT COUNT(*) FROM #staging;", text: "Invalid object name '#staging'.", colour: error)]
            }
            return [setup, cancelled,
                    Entry(sql: "SELECT COUNT(*) FROM #staging;", text: "1000 · the session and #staging are still there")]
        case .long:
            let sql = "EXEC dbo.rebuild_statistics; -- runs 50 s"
            if today {
                return [Entry(sql: sql, text: "Connection timed out: query did not complete within 45s", colour: error),
                        Entry(sql: nil, text: "(the procedure keeps running on the server)", colour: warning)]
            }
            switch timeout {
            case .none:
                return [Entry(sql: sql, text: "Completed in 50 s.")]
            case .followPostgres, .today:
                return [Entry(sql: sql, text: "Stopped after 30 s: the query time limit (Settings, 30 s) was reached. SQL Server confirmed the stop.", colour: warning)]
            }
        case .dropped:
            let lost = Entry(sql: "SELECT * FROM #staging;", text: "The connection to sql01 was lost.", colour: error)
            let rerun = "SELECT COUNT(*) FROM dbo.orders;"
            if today || dropped == .today {
                return [lost, Entry(sql: rerun, text: "The connection was closed.", colour: error),
                        Entry(sql: nil, text: "(every Run fails until the tab is closed and reopened)", colour: warning)]
            }
            if dropped == .reconnectSilently {
                return [lost, Entry(sql: rerun, text: "1000")]
            }
            return [lost,
                    Entry(sql: rerun, text: "Reconnected. The new session does not have #staging, the SET options or the open transaction of the old one.", colour: warning),
                    Entry(sql: nil, text: "1000")]
        }
    }
}
