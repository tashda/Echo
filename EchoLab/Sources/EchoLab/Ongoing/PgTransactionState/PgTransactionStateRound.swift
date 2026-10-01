import SwiftUI

/// Round 21 · Postgres: transaction state. PostgreSQL tabs now run on one pinned connection, so
/// `BEGIN` really opens a transaction that lasts across runs. Where and how does the tab show it?
/// Touches FTR-2.5, FTR-2.6 and the tab (TABS).
@MainActor
enum PgTransactionStateRound {
    enum Place: String, CaseIterable {
        case none = "TS1 · Nothing (today)"
        case tab = "TS2 · On the tab"
        case footer = "TS3 · Footer pill"
        case both = "TS4 · Tab and footer"
        case edge = "TS5 · Editor edge"
    }
    enum Look: String, CaseIterable {
        case dot = "TL1 · Dot"
        case iconWord = "TL2 · Icon and word"
        case badge = "TL3 · TXN badge"
    }
    enum Colour: String, CaseIterable {
        case orange = "TC1 · Orange, red when failed"
        case accent = "TC2 · Accent, red when failed"
        case neutral = "TC3 · Grey, red when failed"
    }
    enum Timer: String, CaseIterable {
        case none = "TT1 · No time"
        case afterMinute = "TT2 · After a minute"
        case always = "TT3 · Always"
    }
    enum Actions: String, CaseIterable {
        case none = "TA1 · None, type COMMIT"
        case menu = "TA2 · Commit and Roll Back in the pill's menu"
        case buttons = "TA3 · Buttons beside the pill"
        case queryMenu = "TA4 · Query menu only"
    }

    private static let width: CGFloat = 600
    private static let height: CGFloat = 420

    static let spec = RoundSpec(
        controls: [
            .of("place", "Where", Place.self, default: .footer,
                question: "Press BEGIN, then UPDATE, then switch tabs and back. Where do you notice that the tab is inside a transaction?",
                recommend: .both,
                why: "An open transaction holds locks and is lost when the tab closes, so it must be visible from any tab: a mark on the tab says which tab, the footer pill says what and for how long. The footer alone is invisible from other tabs; the editor edge looks like the validation colour."),
            .of("look", "Look", Look.self, default: .iconWord,
                question: "Look at the tab and the pill in each state (the gallery shows all four). Which is clear without being loud?",
                recommend: .iconWord,
                why: "The footer already speaks in a dot and a word (FTR-2.6); an icon and the word Transaction says what it is to someone who has never seen it. On the tab only the icon fits. A bare dot is ambiguous; TXN is jargon."),
            .of("colour", "Colour", Colour.self, default: .orange,
                question: "Compare the colours in light and dark. Which says 'something is pending' without saying 'error'?",
                recommend: .orange,
                why: "Orange is the warning colour and an open transaction is a warning: work not yet saved, locks held. The accent reads as 'selected'; grey is easy to miss. Failed is red in every option."),
            .of("timer", "Time", Timer.self, default: .afterMinute,
                question: "Leave the transaction open. When should the pill show how long it has been open?",
                recommend: .afterMinute,
                why: "A short transaction needs no clock; a long one is the dangerous one (locks, idle timeouts). Showing time after a minute keeps the pill short for the common case. Always ticking is busy."),
            .of("actions", "Actions", Actions.self, default: .menu,
                question: "Try to commit without typing. Where should Commit and Roll Back be?",
                recommend: .menu,
                why: "Clicking the pill opens a small menu (Commit, Roll Back, Show in Messages) — one click from where you look, and no permanent buttons. Always-visible buttons make an accidental commit easy; the Query menu alone is hard to find."),
            .of("speed", "Speed", LabSpeed.self, default: .standard),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Nothing shows. BEGIN and COMMIT only appear as messages.",
                  isEchoToday: true, designWidth: width, designHeight: height) { _ in
                PgTxnExhibit(options: .today)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Use the buttons to move through the states.",
                  designWidth: width, designHeight: height) { values in
                PgTxnExhibit(options: PgTxnOptions(values: values))
            },
            .init(id: "gallery", title: "All states", summary: "Idle, in a transaction, failed inside one, connection lost — with the Look and Colour above.",
                  designWidth: width, designHeight: 300) { values in
                PgTxnGallery(options: PgTxnOptions(values: values))
            },
        ],
        questions: [
            .init(id: "failed", title: "Failed transaction",
                  question: "After an error inside a transaction, Postgres ignores everything until ROLLBACK. How should the tab say that?",
                  choices: [
                      .init(id: "red-word", name: "F1 · Red, 'Failed — roll back'", summary: "The pill turns red and names the way out."),
                      .init(id: "red-only", name: "F2 · Red, 'Failed'"),
                      .init(id: "block-run", name: "F3 · Red, and Run asks first", summary: "Running anything but ROLLBACK asks whether to roll back first."),
                  ],
                  recommended: "red-word",
                  why: "Every later statement fails with 'current transaction is aborted', which puzzles people; naming ROLLBACK is the fix. Asking before each run (F3) interrupts people who roll back to a savepoint."),
            .init(id: "reminder", title: "Long transaction",
                  question: "A transaction left open blocks others. Should Echo remind you?",
                  choices: [
                      .init(id: "none", name: "R1 · No reminder"),
                      .init(id: "pill", name: "R2 · The pill turns red after 15 minutes idle"),
                      .init(id: "toast", name: "R3 · A notification after 15 minutes idle"),
                  ],
                  recommended: "pill",
                  why: "A change in the pill you are already shown is enough and never interrupts; a notification is noise for people who keep transactions open on purpose. Fifteen minutes is below common idle_in_transaction timeouts."),
            .init(id: "accuracy", title: "How the state is known",
                  question: "Echo can follow the state from the statements you run, or ask the server after each run.",
                  choices: [
                      .init(id: "statements", name: "K1 · From the statements, check the server before closing", summary: "Instant; a procedure that commits by itself is corrected when it matters."),
                      .init(id: "server", name: "K2 · Ask the server after every run", summary: "Always exact, one extra round trip per run."),
                  ],
                  recommended: "statements",
                  why: "Queries must not get slower: an extra round trip after every run is measurable on a remote server. Statements are exact except for procedures that commit themselves, and the close prompt asks the server anyway."),
        ],
        exhibitTopic: ("Show the state?", "Run the same steps in Echo today and the proposal. Should Echo show the transaction state?",
                       "proposal",
                       "Today nothing tells you a tab is inside a transaction, and closing it silently rolls back. The proposal keeps it visible from every tab with one quiet mark."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "TS4, TL2, TC1, TT2, TA2.",
                  values: ["place": Place.both.rawValue, "look": Look.iconWord.rawValue, "colour": Colour.orange.rawValue,
                           "timer": Timer.afterMinute.rawValue, "actions": Actions.menu.rawValue],
                  isRecommended: true),
            .init(id: "minimal", name: "Quietest", summary: "Footer only, a dot, grey, no time, no actions.",
                  values: ["place": Place.footer.rawValue, "look": Look.dot.rawValue, "colour": Colour.neutral.rawValue,
                           "timer": Timer.none.rawValue, "actions": Actions.none.rawValue]),
            .init(id: "today", name: "Like Echo today", summary: "Nothing shows.",
                  values: ["place": Place.none.rawValue]),
        ]
    )
}

/// What an exhibit draws with.
struct PgTxnOptions: Equatable {
    var place: PgTransactionStateRound.Place = .none
    var look: PgTransactionStateRound.Look = .iconWord
    var colour: PgTransactionStateRound.Colour = .orange
    var timer: PgTransactionStateRound.Timer = .afterMinute
    var actions: PgTransactionStateRound.Actions = .menu

    static let today = PgTxnOptions()

    init() {}

    @MainActor init(values: RoundValues) {
        place = .init(rawValue: values["place"]) ?? .both
        look = .init(rawValue: values["look"]) ?? .iconWord
        colour = .init(rawValue: values["colour"]) ?? .orange
        timer = .init(rawValue: values["timer"]) ?? .afterMinute
        actions = .init(rawValue: values["actions"]) ?? .menu
    }

    func color(for state: PgTxn) -> Color {
        switch state {
        case .idle: ColorTokens.Status.success
        case .failed, .lost: ColorTokens.Status.error
        case .inTransaction:
            switch colour {
            case .orange: ColorTokens.Status.warning
            case .accent: ColorTokens.accent
            case .neutral: ColorTokens.Text.secondary
            }
        }
    }

    func word(for state: PgTxn) -> String {
        switch state {
        case .idle: "Ready"
        case .inTransaction: "Transaction"
        case .failed: "Failed — roll back"
        case .lost: "Disconnected"
        }
    }

    func time(for state: PgTxn) -> String? {
        guard case .inTransaction(_, let seconds) = state else { return nil }
        switch timer {
        case .none: return nil
        case .afterMinute: return seconds >= 60 ? pgDuration(seconds) : nil
        case .always: return pgDuration(seconds)
        }
    }
}

/// The mark for a state, in the chosen look. `compact` is the tab's version.
struct PgTxnMark: View {
    let state: PgTxn
    let options: PgTxnOptions
    var compact = false

    var body: some View {
        let color = options.color(for: state)
        switch options.look {
        case .dot:
            HStack(spacing: SpacingTokens.xxs) {
                Circle().fill(color).frame(width: SpacingTokens.xs, height: SpacingTokens.xs)
                if !compact { Text(options.word(for: state)) }
            }
        case .iconWord:
            HStack(spacing: SpacingTokens.xxs) {
                Image(systemName: symbol).foregroundStyle(color)
                if !compact { Text(options.word(for: state)) }
            }
        case .badge:
            Text(badgeText)
                .font(TypographyTokens.micro)
                .padding(.horizontal, SpacingTokens.xxs)
                .padding(.vertical, SpacingTokens.nano)
                .foregroundStyle(color)
                .background(color.opacity(0.15), in: .capsule)
        }
    }

    private var symbol: String {
        switch state {
        case .idle: "checkmark.circle"
        case .inTransaction: "arrow.triangle.branch"
        case .failed: "exclamationmark.octagon"
        case .lost: "bolt.horizontal.circle"
        }
    }

    private var badgeText: String {
        switch state {
        case .idle: "OK"
        case .inTransaction: "TXN"
        case .failed: "FAILED"
        case .lost: "LOST"
        }
    }
}

/// The interactive exhibit: a query tab, its editor and footer, and buttons that run statements.
struct PgTxnExhibit: View {
    let options: PgTxnOptions
    @State private var state: PgTxn = .idle
    @State private var messages: [String] = ["Connected to shop"]
    @State private var menuShown = false
    @State private var ticker: Task<Void, Never>?

    private var showsTab: Bool { options.place == .tab || options.place == .both }
    private var showsFooter: Bool { options.place == .footer || options.place == .both }

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            PgTabStrip(tabs: [
                PgTab(id: 0, title: "Query 1", badge: showsTab && state != .idle ? AnyView(PgTxnMark(state: state, options: options, compact: true)) : nil),
                PgTab(id: 1, title: "Query 2"),
                PgTab(id: 2, title: "Orders", icon: "tablecells"),
            ], active: 0)
            PgEditorCard(lines: ["BEGIN;", "UPDATE orders SET status = 'shipped'", "  WHERE id = 1042;", "COMMIT;"])
                .overlay(alignment: .leading) {
                    if options.place == .edge, state != .idle {
                        RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.nano)
                            .fill(options.color(for: state))
                            .frame(width: SpacingTokens.xxxs)
                            .padding(.vertical, SpacingTokens.sm)
                    }
                }
            resultsCard
            PgSimBar(actions: [
                ("BEGIN", { begin() }), ("UPDATE", { statement() }), ("Error", { fail() }),
                ("COMMIT", { end("COMMIT") }), ("ROLLBACK", { end("ROLLBACK") }), ("Connection drops", { lose() }),
                ("+10 min", { advance(600) }),
            ])
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
        .onDisappear { ticker?.cancel() }
    }

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            ForEach(Array(messages.suffix(3).enumerated()), id: \.offset) { _, message in
                Text(message).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            }
            Spacer(minLength: SpacingTokens.none)
            PgFooter(segment: "Messages") {
                if showsFooter, state != .idle {
                    footerPill
                } else {
                    PgPill { PgStatusLabel(text: "Ready", color: ColorTokens.Status.success) }
                }
                PgPill { Text("0.02 s") }
            }
        }
        .padding(.top, SpacingTokens.sm)
        .padding(.horizontal, SpacingTokens.sm)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .workspaceCard()
    }

    @ViewBuilder
    private var footerPill: some View {
        let pill = PgPill(tint: options.color(for: state)) {
            PgTxnMark(state: state, options: options)
            if let time = options.time(for: state) {
                Text(time).monospacedDigit().foregroundStyle(ColorTokens.Text.secondary)
            }
            if options.actions == .menu, state.isOpen {
                Image(systemName: "chevron.down").font(TypographyTokens.micro)
            }
        }
        HStack(spacing: SpacingTokens.xxs) {
            if options.actions == .menu, state.isOpen {
                Menu {
                    if state != .failed { Button("Commit") { end("COMMIT") } }
                    Button("Roll Back") { end("ROLLBACK") }
                    Divider()
                    Button("Show in Messages") {}
                } label: { pill }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .fixedSize()
            } else {
                pill
            }
            if options.actions == .buttons, state.isOpen {
                if state != .failed { Button("Commit") { end("COMMIT") }.controlSize(.small) }
                Button("Roll Back") { end("ROLLBACK") }.controlSize(.small)
            }
        }
    }

    private func begin() {
        guard !state.isOpen else { messages.append("WARNING: there is already a transaction in progress"); return }
        state = .inTransaction(statements: 0, seconds: 0)
        messages.append("BEGIN")
        ticker?.cancel()
        ticker = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if case .inTransaction(let n, let s) = state { state = .inTransaction(statements: n, seconds: s + 1) }
            }
        }
    }

    private func statement() {
        if case .failed = state { messages.append("ERROR: current transaction is aborted, commands ignored until end of transaction block"); return }
        if case .inTransaction(let n, let s) = state { state = .inTransaction(statements: n + 1, seconds: s) }
        messages.append("UPDATE 1")
    }

    private func fail() {
        messages.append("ERROR: duplicate key value violates unique constraint \"orders_pkey\"")
        if state.isOpen { state = .failed; ticker?.cancel() }
    }

    private func end(_ word: String) {
        if word == "COMMIT", state == .failed { messages.append("ROLLBACK (the transaction had failed)") } else { messages.append(word) }
        state = .idle
        ticker?.cancel()
    }

    private func lose() {
        messages.append(state.isOpen ? "Connection lost. The open transaction was rolled back." : "Connection lost.")
        state = .lost
        ticker?.cancel()
    }

    private func advance(_ seconds: Int) {
        if case .inTransaction(let n, let s) = state { state = .inTransaction(statements: n, seconds: s + seconds) }
    }
}

/// The four states side by side, as a tab mark and a footer pill.
struct PgTxnGallery: View {
    let options: PgTxnOptions

    private let states: [(String, PgTxn)] = [
        ("Idle", .idle), ("In a transaction", .inTransaction(statements: 2, seconds: 134)),
        ("Failed", .failed), ("Connection lost", .lost),
    ]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: SpacingTokens.lg, verticalSpacing: SpacingTokens.md) {
            GridRow {
                Text("")
                Text("Tab").font(TypographyTokens.labelBold)
                Text("Footer").font(TypographyTokens.labelBold)
            }
            ForEach(Array(states.enumerated()), id: \.offset) { _, entry in
                GridRow {
                    Text(entry.0).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    PgTabStrip(tabs: [PgTab(id: 0, title: "Query 1", badge: entry.1 == .idle ? nil : AnyView(PgTxnMark(state: entry.1, options: options, compact: true)))], active: 0)
                        .frame(width: 170)
                    PgPill(tint: entry.1 == .idle ? nil : options.color(for: entry.1)) {
                        PgTxnMark(state: entry.1, options: options)
                        if let time = options.time(for: entry.1) { Text(time).monospacedDigit() }
                    }
                }
            }
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.canvas)
    }
}
