import SwiftUI

/// Round 41.3 · Results: the error page and its neighbours. Echo today: a failure fills the results
/// card with QueryFailureView (a large red octagon, "Query Failed on Line 7", the message centred in
/// grey, Show in Editor as the default button and Show Messages); the other states are the same
/// centred pattern ("Executing query..." with a large spinner, "No Rows Returned", "No Results
/// Yet"; QueryResultsSection+Views). In the editor, the error mark puts a red pill on the first word of
/// the statement (SQL Server reports the batch's line, so the mark lands on SELECT), with the Error
/// bubble after the statement and the hover popover, which the owner likes.
@MainActor
enum ResultsErrorPageRound {
    enum Page: String, CaseIterable {
        case today = "EP0 · Centred: big symbol, title, message, two buttons (today)"
        case banner = "EP1 · A banner at the top of the card: symbol, message, line and actions in one block"
        case footerOnly = "EP2 · No page: the card stays closed; the editor's bubble and the footer say it"
        case messageCard = "EP3 · The error as the Messages row it is, with its details and actions"

        var summary: String {
            switch self {
            case .today: "An empty card with a poster in the middle; on a wide window the message is a long grey line."
            case .banner: "Reads from the top left like everything else in the card; details (Msg 248 · Level 16 · State 1) in quiet chips."
            case .footerOnly: "The editor already shows where and what; the results card only opens when there are results."
            case .messageCard: "The results card shows the Messages panel's error row (41.4), full width: one way to read errors."
            }
        }
    }

    enum State: String, CaseIterable {
        case error = "Failed"
        case affected = "12 rows changed"
        case noRows = "No rows"
        case cancelled = "Cancelled"
        case running = "Running"
    }

    enum Highlight: String, CaseIterable {
        case firstWord = "HL0 · A red pill on the statement's first word (today)"
        case line = "HL1 · A faint red band on the statement's lines"
        case none = "HL2 · Nothing in the text: the gutter dot and the Error bubble"

        var summary: String {
            switch self {
            case .firstWord: "Looks like SELECT is the mistake; SQL Server only says which line the batch started on."
            case .line: "Says 'this statement' without pointing at a word."
            case .none: "The bubble after the statement and its hover popover carry the message; the text stays readable."
            }
        }
    }

    static let spec = RoundSpec(
        controls: [
            .of("page", "The page", Page.self, default: .banner,
                question: "Switch the state in each exhibit. Which way of showing results-card states reads best, the error first of all?",
                recommend: .banner,
                why: "A results card is read from the top left; a banner puts the message where your eye already is and leaves room for what ran before the failure (a batch's earlier results). The same banner form serves 'Cancelled' and '12 rows changed', so the card has one pattern instead of five posters. EP2 is tempting but a failed batch can have partial results.",
                summary: \.summary),
            .of("highlight", "In the editor", Highlight.self, default: .none,
                question: "Look at the editor above each card. How should the failing statement be marked in the text?",
                recommend: .none,
                why: "You don't like SELECT highlighted, and it is wrong: SQL Server reports the line the statement starts on, not the word that failed. The gutter dot, the Error bubble and its hover say everything without painting the code.",
                summary: \.summary),
            .of("state", "State", State.self, default: .error),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "The editor and the results card as built.", isEchoToday: true, isWide: true, designWidth: 760, designHeight: 470) { values in
                LabEPTab(page: .today, highlight: .firstWord, state: State(rawValue: values["state"]) ?? .error)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls.", isWide: true, designWidth: 760, designHeight: 470) { values in
                LabEPTab(page: Page(rawValue: values["page"]) ?? .banner, highlight: Highlight(rawValue: values["highlight"]) ?? .none,
                         state: State(rawValue: values["state"]) ?? .error)
            },
        ],
        questions: [
            .init(id: "details", title: "SQL Server's numbers",
                  question: "Msg 248, Level 16, State 1: show them with the error?",
                  choices: [.init(id: "chips", name: "ED0 · Quiet chips after the message"), .init(id: "messages", name: "ED1 · Only in Messages")],
                  recommended: "chips",
                  why: "The number is what you search for; DBAs read the level to know how serious it is. Quiet chips keep the message first."),
            .init(id: "actions", title: "Actions",
                  question: "Which actions should the error offer?",
                  choices: [.init(id: "two", name: "EA0 · Show in Editor and Messages (today)"), .init(id: "three", name: "EA1 · EA0 and Copy Error")],
                  recommended: "three",
                  why: "Pasting the error into a chat or a search is the next thing people do; selecting the text works but a button is quicker."),
        ],
        presets: [.init(id: "recommended", name: "My recommendation", values: ["page": Page.banner.rawValue, "highlight": Highlight.none.rawValue], isRecommended: true)]
    )
}

/// The editor with the failing statement over the results card in a state.
private struct LabEPTab: View {
    let page: ResultsErrorPageRound.Page
    let highlight: ResultsErrorPageRound.Highlight
    let state: ResultsErrorPageRound.State

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            editor.frame(height: 130).workspaceCard()
            if page != .footerOnly {
                VStack(spacing: SpacingTokens.none) {
                    card.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: page == .today ? .center : .topLeading)
                    LabWKFooter(server: "dkloosql10-p · ccsLDK10", pills: pills)
                }
                .workspaceCard()
            } else {
                Spacer()
                LabWKFooter(server: "dkloosql10-p · ccsLDK10", pills: pills).workspaceCard()
            }
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
    }

    private var pills: [LabWKPill] {
        switch state {
        case .error: [.rows("0"), .time("0s"), .status("Error", tint: ColorTokens.Status.error)]
        case .affected: [.rows("12", label: "changed"), .time("0s"), .status("Completed", tint: ColorTokens.Status.success)]
        case .noRows: [.rows("0"), .time("0s"), .status("Completed", tint: ColorTokens.Status.success)]
        case .cancelled: [.rows("0"), .time("4s"), .status("Cancelled", tint: ColorTokens.Status.warning)]
        case .running: [.time("0:12"), .status("Running", tint: ColorTokens.Status.warning)]
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            ForEach(Array(["select *", "from ba_tbl", "where uniqueBagID <> 123456"].enumerated()), id: \.offset) { index, line in
                HStack(spacing: SpacingTokens.md) {
                    ZStack {
                        Text("\(index + 7)").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.tertiary)
                        if state == .error, index == 0 { Circle().fill(ColorTokens.Status.error).frame(width: 5, height: 5).offset(x: -SpacingTokens.md) }
                    }
                    .frame(width: SpacingTokens.md, alignment: .trailing)
                    if state == .error, index == 0, highlight == .firstWord {
                        HStack(spacing: SpacingTokens.none) {
                            Text("select").font(TypographyTokens.code).padding(.horizontal, SpacingTokens.xxxs).background(ColorTokens.Status.error.opacity(0.18), in: Capsule())
                            LabWKSQLText(line: " *")
                        }
                    } else {
                        LabWKSQLText(line: line)
                    }
                    if state == .error, index == 2 {
                        Label("Error", systemImage: "exclamationmark.circle.fill").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.error)
                            .padding(.horizontal, SpacingTokens.xs).frame(height: SpacingTokens.md2).glassEffect(.regular, in: .capsule)
                    }
                    Spacer()
                }
                .frame(height: SpacingTokens.lg + SpacingTokens.xxxs)
                .background(state == .error && highlight == .line ? ColorTokens.Status.error.opacity(0.06) : .clear)
            }
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var message: (symbol: String, tint: Color, title: String, detail: String) {
        switch state {
        case .error: ("exclamationmark.octagon.fill", ColorTokens.Status.error, page == .today ? "Query Failed on Line 7" : "Failed on line 7",
                      "The conversion of the varchar value '2610000125260' overflowed an int column.")
        case .affected: ("checkmark.circle.fill", ColorTokens.Status.success, "12 rows changed", "UPDATE finished in 4 ms.")
        case .noRows: ("tablecells.badge.ellipsis", ColorTokens.Text.secondary, page == .today ? "No Rows Returned" : "No rows",
                       "The query ran and returned nothing.")
        case .cancelled: ("stop.circle.fill", ColorTokens.Status.warning, "Cancelled", "You stopped the query after 4 s. Nothing was changed.")
        case .running: ("hourglass", ColorTokens.Text.secondary, page == .today ? "Executing query..." : "Running", "Waiting for the first rows.")
        }
    }

    @ViewBuilder
    private var card: some View {
        let m = message
        switch page {
        case .today:
            VStack(spacing: SpacingTokens.sm) {
                if state == .running { ProgressView().controlSize(.large) } else {
                    Image(systemName: m.symbol).font(TypographyTokens.hero).foregroundStyle(state == .error ? m.tint : ColorTokens.Text.secondary)
                }
                Text(m.title).font(TypographyTokens.headline)
                Text(state == .error ? "Query Error: \(m.detail)" : (state == .running ? "Please wait while we fetch your data." : m.detail))
                    .font(TypographyTokens.body).foregroundStyle(ColorTokens.Text.secondary).multilineTextAlignment(.center)
                if state == .error {
                    HStack { Button("Show in Editor") {}.buttonStyle(.borderedProminent); Button("Show Messages") {} }
                }
            }
            .padding(SpacingTokens.lg)
        case .banner, .footerOnly:
            HStack(alignment: .top, spacing: SpacingTokens.sm) {
                if state == .running { ProgressView().controlSize(.small) } else { Image(systemName: m.symbol).font(TypographyTokens.title3).foregroundStyle(m.tint) }
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text(m.title).font(TypographyTokens.standard.weight(.semibold))
                    Text(m.detail).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary).textSelection(.enabled)
                    if state == .error {
                        HStack(spacing: SpacingTokens.xxs) {
                            ForEach(["Msg 248", "Level 16", "State 1"], id: \.self) { chip in
                                Text(chip).font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.secondary)
                                    .padding(.horizontal, SpacingTokens.xxs2).padding(.vertical, SpacingTokens.micro)
                                    .background(ColorTokens.Sidebar.hoverFill, in: Capsule())
                            }
                        }
                        HStack(spacing: SpacingTokens.xs) {
                            Button("Show in Editor") {}; Button("Messages") {}; Button("Copy Error") {}
                        }
                        .controlSize(.small).padding(.top, SpacingTokens.xxs)
                    }
                }
            }
            .padding(SpacingTokens.md)
        case .messageCard:
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                HStack(spacing: SpacingTokens.xs) {
                    Image(systemName: m.symbol).foregroundStyle(m.tint)
                    Text(m.title).font(TypographyTokens.standard.weight(.semibold))
                    Spacer()
                    Text("15:34:51").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.tertiary)
                }
                Text(m.detail).font(TypographyTokens.detail.monospaced()).foregroundStyle(ColorTokens.Text.secondary).textSelection(.enabled)
            }
            .padding(SpacingTokens.sm)
            .background(ColorTokens.Workspace.groupFill, in: .rect(cornerRadius: SpacingTokens.sm))
            .padding(SpacingTokens.sm)
        }
    }
}
