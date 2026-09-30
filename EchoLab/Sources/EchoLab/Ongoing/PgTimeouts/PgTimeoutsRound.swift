import SwiftUI

/// Round 21 · Postgres: statement timeouts. The connection sheet has had a Query Timeout field
/// (60 seconds) for a long time; it is saved and synced but no query uses it, so every query runs
/// until it ends or you cancel it. postgres-wire can now apply statement_timeout and lock_timeout
/// to a tab's session. This page decides where the limit is set, its default and what you see
/// when it fires. Touches CON-2.3, FTR-2.6 and the cancel page in this round.
///
/// Revision 2 (owner feedback): few people set a limit, so nothing shows unless one is set;
/// Settings default with connection override; where the message goes, with notifications;
/// lock waits in the footer status; a limit set on the server.
@MainActor
enum PgTimeoutsRound {
    enum Where: String, CaseIterable {
        case connection = "TW1 · Connection sheet only"
        case settings = "TW2 · Settings default, connection overrides"
        case connectionAndTab = "TW3 · Connection, changeable per tab"
        case tabOnly = "TW4 · Per tab only"
    }
    enum Default: String, CaseIterable {
        case sixty = "TD1 · 60 seconds (the saved value)"
        case off = "TD2 · No limit unless set"
        case five = "TD3 · 5 minutes"
    }
    enum Fired: String, CaseIterable {
        case serverText = "TF1 · The server's error only"
        case explained = "TF2 · Explained, with Run Without Limit"
        case footer = "TF3 · Footer pill turns red, text in Messages"
        case explainedToastAway = "TF4 · Explained, plus a notification when you're elsewhere"
        case toastOnly = "TF5 · Notification only"
        case explainedToastAlways = "TF6 · Explained, plus a notification every time"

        var explains: Bool { self == .explained || self == .explainedToastAway || self == .explainedToastAlways }
        /// Whether a toast appears while you are on the tab, and while you are on another tab or app.
        var toastHere: Bool { self == .toastOnly || self == .explainedToastAlways }
        var toastAway: Bool { toastHere || self == .explainedToastAway }
    }
    enum Locks: String, CaseIterable {
        case none = "TL1 · Not offered"
        case field = "TL2 · Separate field under Timeouts"
        case same = "TL3 · The statement limit covers it"
        case waitOnly = "TL4 · No lock field; show the wait instead"
    }
    enum LockStatus: String, CaseIterable {
        case none = "LF1 · Nothing, the timer runs (today)"
        case pill = "LF2 · Status says Waiting for lock"
        case pillWho = "LF3 · Waiting for lock, who holds it on hover"
    }

    private static let width: CGFloat = 760
    private static let height: CGFloat = 400

    static let spec = RoundSpec(
        controls: [
            .of("where", "Where", Where.self, default: .settings,
                question: "Where is the limit set?",
                recommend: .settings,
                why: "Agreed: one default in Settings, overridden in a connection's sheet, is how SSMS does it (Tools › Options › Query Execution, and Execution time-out in the Connect dialog's options). SSMS also has a per-window value under Query Options, but few use it, and an Echo tab can already do that without any UI: tabs keep their own session now, so SET statement_timeout = '10min' in a tab changes that tab only. pgAdmin 4 has no limit setting of its own as far as I know; people use SET or a server setting."),
            .of("default", "Default", Default.self, default: .off,
                question: "What should a new connection start with?",
                recommend: .off,
                why: "No limit is what every query has had in practice until now, and what psql and pgAdmin do. A limit you did not choose cancelling a long migration is worse than a query you cancel yourself; the field makes it one step to add one."),
            .of("fired", "When it fires", Fired.self, default: .explainedToastAway,
                question: "Look at 'Where the message goes': the tab you are on, and the same tab while you are on another. Which tells you best without interrupting you while you watch?",
                recommend: .explainedToastAway,
                why: "The message belongs in the tab's results area, where the grid would be, because that is where you look for the result. A notification only helps when you are not looking: a long query left running while you work in another tab or app. Then the toast (and Notification history) says which tab stopped and why. A toast while you watch the tab repeats what is in front of you.",
                newChoices: (2, [.explainedToastAway, .toastOnly, .explainedToastAlways])),
            .of("locks", "Lock waits", Locks.self, default: .field,
                question: "A statement waits for a lock held by another session. Should that have its own limit?",
                recommend: .field,
                why: "Waiting for a lock is a different problem from a slow query: a short lock limit (5 s) stops an ALTER TABLE queueing behind a long transaction and blocking everyone, without cutting off real work. It sits under Timeouts next to the statement limit, empty by default. TL4 (only showing the wait) helps everyone but cannot protect a migration you start and walk away from.",
                newChoices: (2, [.waitOnly])),
            .of("lockStatus", "Lock wait in the footer", LockStatus.self, default: .pillWho,
                question: "Press 'Wait on a lock'. Should the footer's status say the query is waiting, not running?",
                recommend: .pillWho,
                why: "Yes, whether or not a lock limit is set: a query that waits looks exactly like a slow one today, and people cancel and rewrite a query that was fine. After 2 s Echo asks the server (pg_stat_activity and pg_blocking_pids, over a separate connection) once a second; the status then says Waiting for lock, and hovering it shows who holds the lock and what they are running. It never touches the running query's connection, so the query is not slowed, and nothing happens for queries under 2 s.",
                addedIn: 2),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "The sheet says 60 seconds, but the query runs on: nothing applies it.",
                  isEchoToday: true, designWidth: width, designHeight: height) { _ in
                PgTimeoutExhibit(where_: .connection, default_: .sixty, fired: .serverText, locks: .none, lockStatus: .none, appliesLimit: false)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Press Set Limits, Run, then +10 s; Wait on a Lock shows a blocked query. Without a limit nothing new appears.",
                  designWidth: width, designHeight: height) { values in
                PgTimeoutExhibit(where_: Where(rawValue: values["where"]) ?? .settings,
                                 default_: Default(rawValue: values["default"]) ?? .off,
                                 fired: Fired(rawValue: values["fired"]) ?? .explainedToastAway,
                                 locks: Locks(rawValue: values["locks"]) ?? .field,
                                 lockStatus: LockStatus(rawValue: values["lockStatus"]) ?? .pillWho,
                                 appliesLimit: true)
            },
            .init(id: "fired", title: "Where the message goes",
                  summary: "The limit has fired, drawn as it stays. Left: you are on the tab. Right: you were on another tab when it fired. Follows When it fires.",
                  isWide: true, addedIn: 2, designWidth: 900, designHeight: 330) { values in
                PgTimeoutFiredExhibit(fired: Fired(rawValue: values["fired"]) ?? .explainedToastAway)
            },
        ],
        questions: [
            .init(id: "migrate", title: "The 60 seconds already saved",
                  question: "Every existing connection has 60 s saved that never did anything. What happens when the field starts working?",
                  choices: [
                      .init(id: "apply", name: "M1 · Start applying 60 s"),
                      .init(id: "reset", name: "M2 · Reset to No limit, quietly"),
                      .init(id: "resetTell", name: "M3 · Reset to No limit, mention it once in What's New"),
                  ],
                  recommended: "resetTell",
                  why: "Applying 60 s would start cancelling queries that work today, for a value nobody chose. Resetting keeps behaviour the same; one line in What's New tells people the field now works."),
            .init(id: "timer", title: "The limit in the footer",
                  question: "When a limit is set, should the footer's timer show it?",
                  choices: [
                      .init(id: "fraction", name: "FT1 · 0:12 / 0:30 while running"),
                      .init(id: "near", name: "FT2 · Only in the last 20 %"),
                      .init(id: "never", name: "FT3 · No, elapsed only (today)"),
                  ],
                  recommended: "fraction",
                  why: "Knowing the limit before it fires avoids the surprise. It only appears while a query runs with a limit set, so tabs without one look exactly as they do now. The timer is already redrawn every second, so this costs nothing."),
            .init(id: "serverLimit", title: "A limit set on the server",
                  question: "Many companies set statement_timeout on the server, for a role or a database. Echo gets the same error. What does the message say then?",
                  choices: [
                      .init(id: "named", name: "SL1 · Names it: the server's limit of 30 s", addedIn: 2),
                      .init(id: "generic", name: "SL2 · Only that a time limit stopped it", addedIn: 2),
                  ],
                  recommended: "named",
                  why: "This is the case most people will actually meet: they never set a limit, their DBA did. When the error arrives Echo asks the session SHOW statement_timeout (one query, only after the error) and can say it is the server's limit, not Echo's, so nobody looks in Echo for a setting that is not there. Run Without Limit is offered only when the server lets the session change it.",
                  addedIn: 2),
            .init(id: "idle", title: "Idle in transaction",
                  question: "Postgres can end a session left idle inside a transaction. Should Echo offer it?",
                  choices: [
                      .init(id: "no", name: "IT1 · No, the transaction indicator covers it"),
                      .init(id: "advanced", name: "IT2 · Yes, under Timeouts, empty by default"),
                  ],
                  recommended: "no",
                  why: "When it fires the server closes the connection and the transaction's work is lost, which is exactly what the guard in this round tries to prevent. DBAs set it on the server, where it belongs."),
            .init(id: "scripts", title: "Scripts",
                  question: "In a script, does the limit apply to each statement or to the whole run?",
                  choices: [
                      .init(id: "each", name: "SC1 · Each statement (how Postgres does it)"),
                      .init(id: "whole", name: "SC2 · The whole script"),
                  ],
                  recommended: "each",
                  why: "statement_timeout is per statement on the server; a whole-script limit would need Echo's own timer and would cut a script of many quick statements for no reason."),
        ],
        exhibitTopic: ("Should the limit work?", "Run past the limit in both. Why a limit at all: on a shared or production server one mistaken query (a missing WHERE, a join without an index) can run for hours, hold locks and slow everyone else; a limit ends it on its own. Few people set one, so it lives in Settings and the connection sheet and shows nowhere else unless it is set.",
                       "proposal",
                       "Today the sheet promises 60 seconds and nothing happens. The proposal applies the limit you set, stays invisible when there is none, and when one fires it says whose limit it was and offers the way out."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "TW2, TD2, TF4, TL2, LF3.",
                  values: ["where": Where.settings.rawValue, "default": Default.off.rawValue,
                           "fired": Fired.explainedToastAway.rawValue, "locks": Locks.field.rawValue,
                           "lockStatus": LockStatus.pillWho.rawValue],
                  isRecommended: true),
            .init(id: "minimal", name: "Minimal", summary: "TW2, TD2, TF2, TL4, LF2.",
                  values: ["where": Where.settings.rawValue, "default": Default.off.rawValue,
                           "fired": Fired.explained.rawValue, "locks": Locks.waitOnly.rawValue,
                           "lockStatus": LockStatus.pill.rawValue]),
            .init(id: "strict", name: "Strict", summary: "TW2, TD3, TF6, TL2, LF3.",
                  values: ["where": Where.settings.rawValue, "default": Default.five.rawValue,
                           "fired": Fired.explainedToastAlways.rawValue, "locks": Locks.field.rawValue,
                           "lockStatus": LockStatus.pillWho.rawValue]),
            .init(id: "today", name: "Like Echo today (but working)", summary: "TW1, TD1, TF1, TL1, LF1.",
                  values: ["where": Where.connection.rawValue, "default": Default.sixty.rawValue,
                           "fired": Fired.serverText.rawValue, "locks": Locks.none.rawValue,
                           "lockStatus": LockStatus.none.rawValue]),
        ]
    )
}
