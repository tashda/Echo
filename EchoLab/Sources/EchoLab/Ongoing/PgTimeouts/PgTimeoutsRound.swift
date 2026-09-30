import SwiftUI

/// Round 21 · Postgres: statement timeouts. The connection sheet has had a Query Timeout field
/// (60 seconds) for a long time; it is saved and synced but no query uses it, so every query runs
/// until it ends or you cancel it. postgres-wire can now apply statement_timeout and lock_timeout
/// to a tab's session. This page decides where the limit is set, its default and what you see
/// when it fires. Touches CON-2.3, FTR-2.6 and the cancel page in this round.
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
    }
    enum Locks: String, CaseIterable {
        case none = "TL1 · Not offered"
        case field = "TL2 · Separate field under Timeouts"
        case same = "TL3 · The statement limit covers it"
    }

    private static let width: CGFloat = 760
    private static let height: CGFloat = 400

    static let spec = RoundSpec(
        controls: [
            .of("where", "Where", Where.self, default: .connectionAndTab,
                question: "You need one long report on a connection that has a 30 s limit. Where do you change it?",
                recommend: .connectionAndTab,
                why: "The limit belongs to the server (production gets one, your laptop does not), so the connection keeps it; a long report needs a one-tab change without editing the connection that every tab shares. A global Settings value can't tell production from local, and per tab only means setting it again every time."),
            .of("default", "Default", Default.self, default: .off,
                question: "What should a new connection start with?",
                recommend: .off,
                why: "No limit is what every query has had in practice until now, and what psql and pgAdmin do. A limit you did not choose cancelling a long migration is worse than a query you cancel yourself; the field makes it one step to add one."),
            .of("fired", "When it fires", Fired.self, default: .explained,
                question: "Run the query past the limit. Do you understand what happened, and what to do next?",
                recommend: .explained,
                why: "'canceling statement due to statement timeout' does not say which limit or where it is set. Saying 'Stopped after 30 s, the limit for this connection' with Run Without Limit (for this tab) turns a dead end into one click."),
            .of("locks", "Lock waits", Locks.self, default: .field,
                question: "A statement waits for a lock held by another session. Should that have its own limit?",
                recommend: .field,
                why: "Waiting for a lock is a different problem from a slow query: a short lock limit (5 s) stops an ALTER TABLE queueing behind a long transaction and blocking everyone, without cutting off real work. It sits under Timeouts, empty by default."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "The sheet says 60 seconds, but the query runs on: nothing applies it.",
                  isEchoToday: true, designWidth: width, designHeight: height) { _ in
                PgTimeoutExhibit(where_: .connection, default_: .sixty, fired: .serverText, locks: .none, appliesLimit: false)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Set 30 s on the connection, press Run, then +30 s; try the tab menu.",
                  designWidth: width, designHeight: height) { values in
                PgTimeoutExhibit(where_: Where(rawValue: values["where"]) ?? .connectionAndTab,
                                 default_: Default(rawValue: values["default"]) ?? .off,
                                 fired: Fired(rawValue: values["fired"]) ?? .explained,
                                 locks: Locks(rawValue: values["locks"]) ?? .field,
                                 appliesLimit: true)
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
                  why: "Knowing the limit before it fires avoids the surprise; it only appears when a limit is set, so most tabs look as they do now. The timer is already redrawn every second, so this costs nothing."),
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
        exhibitTopic: ("Should the limit work?", "Run past the limit in both.",
                       "proposal",
                       "Today the sheet promises 60 seconds and nothing happens; the proposal applies the limit you set, shows it while you wait and offers the way out when it fires."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "TW3, TD2, TF2, TL2.",
                  values: ["where": Where.connectionAndTab.rawValue, "default": Default.off.rawValue,
                           "fired": Fired.explained.rawValue, "locks": Locks.field.rawValue],
                  isRecommended: true),
            .init(id: "strict", name: "Strict", summary: "TW2, TD3, TF2, TL2.",
                  values: ["where": Where.settings.rawValue, "default": Default.five.rawValue,
                           "fired": Fired.explained.rawValue, "locks": Locks.field.rawValue]),
            .init(id: "today", name: "Like Echo today (but working)", summary: "TW1, TD1, TF1, TL1.",
                  values: ["where": Where.connection.rawValue, "default": Default.sixty.rawValue,
                           "fired": Fired.serverText.rawValue, "locks": Locks.none.rawValue]),
        ]
    )
}

struct PgTimeoutExhibit: View {
    typealias R = PgTimeoutsRound
    let where_: R.Where
    let default_: R.Default
    let fired: R.Fired
    let locks: R.Locks
    let appliesLimit: Bool

    @State private var elapsed: Int?
    @State private var timedOut = false
    @State private var tabOverride: Int??
    @Environment(\.echoMotion) private var motion

    /// "Set 30 s" simulates typing 30 into the connection's field, so the limit fires quickly.
    @State private var typedLimit: Int?

    private var connectionLimit: Int? {
        if let typedLimit { return typedLimit }
        switch default_ {
        case .sixty: return 60
        case .five: return 300
        case .off: return nil
        }
    }

    private var limit: Int? {
        guard appliesLimit else { return nil }
        if let tabOverride { return tabOverride }
        return connectionLimit
    }

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.sm) {
            sheet.frame(width: 230)
            VStack(spacing: SpacingTokens.xs) {
                PgEditorCard(lines: ["select customer_id, sum(total)", "from orders_2019_2026", "group by 1;"])
                results
                PgSimBar(actions: [("▶ Run", { run() }), ("+30 s", { tick() }), ("Set 30 s on the connection", { typedLimit = 30 }), ("Reset", { reset() })])
            }
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
        .animation(motion.standard, value: timedOut)
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text(where_ == .settings ? "Settings › Queries" : where_ == .tabOnly ? "Connection (no limit here)" : "Connection › Security and timeouts")
                .font(TypographyTokens.labelBold).foregroundStyle(ColorTokens.Text.secondary)
            if where_ != .tabOnly {
                row("Connection Timeout", "30 seconds")
                row(where_ == .settings ? "Default Query Limit" : "Query Timeout",
                    appliesLimit ? limitText(connectionLimit) : "60 seconds")
                if locks == .field { row("Lock Wait Limit", "No limit") }
            }
            if where_ == .settings {
                Text("Each connection can override it in its sheet.").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            }
            if !appliesLimit {
                Label("Saved and synced, but no query uses it.", systemImage: "exclamationmark.triangle")
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.warning)
            }
            Spacer(minLength: SpacingTokens.none)
        }
        .padding(SpacingTokens.sm)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(TypographyTokens.formLabel)
            Spacer()
            Text(value).font(TypographyTokens.formValue).foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            if timedOut {
                timedOutMessage
            } else if let elapsed {
                Text("Running… \(elapsed) s").foregroundStyle(ColorTokens.Text.secondary)
            } else {
                Text("Run the query.").foregroundStyle(ColorTokens.Text.tertiary)
            }
            Spacer(minLength: SpacingTokens.none)
            PgFooter(segment: timedOut && fired == .footer ? "Messages" : "Results") {
                if where_ == .connectionAndTab || where_ == .tabOnly { tabMenu }
                timerPill
            }
        }
        .font(TypographyTokens.detail)
        .padding(SpacingTokens.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
    }

    @ViewBuilder
    private var timedOutMessage: some View {
        let limitSeconds = limit ?? 0
        switch fired {
        case .serverText:
            Text("ERROR: canceling statement due to statement timeout").foregroundStyle(ColorTokens.Status.error)
        case .explained:
            Label("Stopped after \(limitText(limitSeconds)), the limit \(tabOverride != nil ? "for this tab" : "for this connection").",
                  systemImage: "timer").foregroundStyle(ColorTokens.Status.error)
            HStack(spacing: SpacingTokens.xs) {
                Button("Run Without Limit") { tabOverride = .some(nil); run() }
                Button("Change Limit…") {}
            }
            .controlSize(.small)
            Text("Nothing was changed: the statement was rolled back.").foregroundStyle(ColorTokens.Text.tertiary)
        case .footer:
            Text("ERROR: canceling statement due to statement timeout\nLimit: \(limitText(limitSeconds)) (connection setting)")
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    private var tabMenu: some View {
        Menu {
            Button("Connection's limit (\(limitText(connectionLimit)))") { tabOverride = nil }
            Button("No limit for this tab") { tabOverride = .some(nil) }
            Button("5 minutes for this tab") { tabOverride = .some(300) }
        } label: {
            Image(systemName: "timer")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Query limit for this tab")
    }

    private var timerPill: some View {
        PgPill(tint: timedOut ? ColorTokens.Status.error : nil) {
            if let elapsed {
                if let limit, !timedOut {
                    Text("\(pgDuration(elapsed)) / \(pgDuration(limit))").monospacedDigit()
                } else {
                    Text(pgDuration(elapsed)).monospacedDigit()
                }
            } else {
                Text(limit.map { "Limit \(limitText($0))" } ?? "No limit")
            }
        }
    }

    private func limitText(_ seconds: Int?) -> String {
        guard let seconds else { return "No limit" }
        return seconds >= 60 && seconds % 60 == 0 ? "\(seconds / 60) min" : "\(seconds) s"
    }

    private func run() { elapsed = 0; timedOut = false }

    private func tick() {
        guard let current = elapsed, !timedOut else { return }
        let next = current + 30
        if let limit, next >= limit {
            elapsed = limit
            timedOut = true
        } else {
            elapsed = next
        }
    }

    private func reset() { elapsed = nil; timedOut = false; tabOverride = nil; typedLimit = nil }
}
