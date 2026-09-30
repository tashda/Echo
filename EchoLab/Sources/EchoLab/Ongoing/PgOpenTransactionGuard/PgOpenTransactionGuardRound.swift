import SwiftUI

/// Round 21 · Postgres: open transaction on close. Closing a tab (or switching its database,
/// disconnecting, quitting) ends its connection, and the server rolls back an open transaction.
/// Touches the tab's close button (TABS) and the database chip (FTR-2.4).
@MainActor
enum PgOpenTransactionGuardRound {
    enum Form: String, CaseIterable {
        case silent = "G1 · Close, roll back silently (today)"
        case alert = "G2 · Alert"
        case sheet = "G3 · Sheet with what is pending"
        case popover = "G4 · Popover from the tab"
        case rollBackAndTell = "G5 · Roll back and tell"
    }
    enum DefaultButton: String, CaseIterable {
        case commit = "D1 · Commit"
        case rollBack = "D2 · Roll Back"
        case cancel = "D3 · Cancel"
    }
    enum Detail: String, CaseIterable {
        case sentence = "DT1 · One sentence"
        case counts = "DT2 · Sentence, time and statements"
        case statements = "DT3 · The statements since BEGIN"
    }

    private static let width: CGFloat = 620
    private static let height: CGFloat = 440

    static let spec = RoundSpec(
        controls: [
            .of("form", "Form", Form.self, default: .alert,
                question: "Press Close tab with the transaction open, then Switch database. Which form stops you at the right moment without feeling heavy?",
                recommend: .alert,
                why: "It is the same decision as 'Save changes?' and macOS answers that with an alert: familiar, keyboard-driven, impossible to miss. A sheet is heavier for a two-second choice; a popover is easy to dismiss by accident; rolling back and telling loses work you meant to keep."),
            .of("default", "Default button", DefaultButton.self, default: .commit,
                question: "Press Return in the alert. What should Return do?",
                recommend: .commit,
                why: "Commit plays the part of Save: it keeps what you did, and Roll Back is shown as the destructive choice like Don't Save. Making Roll Back the default throws work away on a reflex; Cancel as default makes Return do nothing useful."),
            .of("detail", "Detail", Detail.self, default: .counts,
                question: "Read the message. Does it tell you enough to choose?",
                recommend: .counts,
                why: "'Open for 12 minutes · 3 statements changed data' is what you need to decide; the full list of statements belongs in Messages and makes the alert tall. One sentence alone doesn't say how much is at stake."),
            .of("speed", "Speed", LabSpeed.self, default: .standard),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "The tab closes at once; the server rolls the transaction back and nothing says so.",
                  isEchoToday: true, designWidth: width, designHeight: height) { _ in
                PgGuardExhibit(form: .silent, defaultButton: .commit, detail: .sentence)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Close the tab, switch database or quit.",
                  designWidth: width, designHeight: height) { values in
                PgGuardExhibit(form: Form(rawValue: values["form"]) ?? .alert,
                               defaultButton: DefaultButton(rawValue: values["default"]) ?? .commit,
                               detail: Detail(rawValue: values["detail"]) ?? .counts)
            },
            .init(id: "quit", title: "Quitting with two open transactions", summary: "One alert that lists the tabs, as the Quit question below proposes.",
                  designWidth: width, designHeight: 300) { _ in
                PgGuardQuitExhibit()
            },
        ],
        questions: [
            .init(id: "when", title: "When to ask",
                  question: "Which actions end a tab's connection and should ask first?",
                  choices: [
                      .init(id: "all", name: "W1 · Close tab, switch database, disconnect, quit"),
                      .init(id: "close-quit", name: "W2 · Close tab and quit only"),
                      .init(id: "close", name: "W3 · Close tab only"),
                  ],
                  recommended: "all",
                  why: "All four end the connection and roll the transaction back; asking for some and not others would make the rule impossible to learn."),
            .init(id: "failed", title: "A failed transaction",
                  question: "The transaction already failed (nothing can be committed). What should the alert offer?",
                  choices: [
                      .init(id: "rollback-cancel", name: "FT1 · Roll Back and Cancel, saying it failed"),
                      .init(id: "same", name: "FT2 · The same three buttons"),
                      .init(id: "no-ask", name: "FT3 · Don't ask, it's lost anyway"),
                  ],
                  recommended: "rollback-cancel",
                  why: "Commit would silently roll back, so offering it misleads. Not asking at all hides that the work was lost; saying so once is kinder."),
            .init(id: "quit", title: "Quitting",
                  question: "Two tabs have open transactions and you quit Echo.",
                  choices: [
                      .init(id: "one-list", name: "Q1 · One alert listing the tabs: Review, Roll Back All, Cancel"),
                      .init(id: "per-tab", name: "Q2 · One alert per tab"),
                      .init(id: "commit-all", name: "Q3 · One alert: Commit All, Roll Back All, Cancel"),
                  ],
                  recommended: "one-list",
                  why: "Review walks you through the tabs so each one gets a real decision; committing several tabs' work with one click is too easy to regret. An alert per tab is tiring with five tabs."),
            .init(id: "remember", title: "Don't ask again",
                  question: "Should the alert have a 'Don't ask again' checkbox?",
                  choices: [
                      .init(id: "no", name: "N1 · No"),
                      .init(id: "yes", name: "N2 · Yes, remembered per connection"),
                  ],
                  recommended: "no",
                  why: "The alert only appears when work would be lost; turning it off trades a rare click for silent data loss."),
        ],
        exhibitTopic: ("Guard open transactions?", "Close the tab in both. Should Echo stop you before rolling back an open transaction?",
                       "proposal",
                       "Today a transaction's work disappears without a word when its tab closes. An alert shaped like 'Save changes?' costs one keypress and only appears when something would be lost."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "G2, D1, DT2.",
                  values: ["form": Form.alert.rawValue, "default": DefaultButton.commit.rawValue, "detail": Detail.counts.rawValue],
                  isRecommended: true),
            .init(id: "lightest", name: "Lightest", summary: "G5: roll back and tell afterwards.",
                  values: ["form": Form.rollBackAndTell.rawValue]),
            .init(id: "today", name: "Like Echo today", summary: "G1.", values: ["form": Form.silent.rawValue]),
        ]
    )
}

/// The exhibit: three tabs, the first with an open transaction; actions trigger the guard.
struct PgGuardExhibit: View {
    typealias Round = PgOpenTransactionGuardRound
    let form: Round.Form
    let defaultButton: Round.DefaultButton
    let detail: Round.Detail

    private enum Trigger: String { case close = "Close Query 1", switchDB = "Switch Query 1 to analytics", quit = "Quit Echo" }

    @State private var tabs = [0, 1, 2]
    @State private var asking: Trigger?
    @State private var outcome: String?
    @State private var failed = false
    @Environment(\.echoMotion) private var motion

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            PgTabStrip(tabs: tabs.map { index in
                PgTab(id: index, title: ["Query 1", "Query 2", "Orders"][index], icon: index == 2 ? "tablecells" : "doc.text",
                      badge: index == 0 ? AnyView(Image(systemName: "arrow.triangle.branch").foregroundStyle(failed ? ColorTokens.Status.error : ColorTokens.Status.warning)) : nil)
            }, active: tabs.first ?? 0, onClose: { _ in trigger(.close) })
            .overlay(alignment: .topLeading) {
                if form == .popover, asking != nil { popover.offset(y: 40).transition(.opacity) }
            }
            ZStack {
                PgEditorCard(lines: tabs.contains(0)
                             ? ["BEGIN;", "UPDATE orders SET status = 'shipped' WHERE id = 1042;", "DELETE FROM carts WHERE user_id = 7;", "INSERT INTO audit VALUES (…);"]
                             : ["select * from customers;"])
                if asking != nil, form == .alert { alert.transition(.scale(scale: 0.95).combined(with: .opacity)) }
                if asking != nil, form == .sheet { VStack { sheet; Spacer() }.transition(.move(edge: .top).combined(with: .opacity)) }
                if form == .rollBackAndTell, let outcome {
                    VStack { HStack { Spacer(); toast(outcome) }; Spacer() }.padding(SpacingTokens.xs).transition(.opacity)
                }
            }
            HStack {
                if let outcome, form != .rollBackAndTell {
                    Text(outcome).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                }
                Spacer()
            }
            PgSimBar(actions: [
                ("Close tab", { trigger(.close) }), ("Switch database", { trigger(.switchDB) }), ("Quit", { trigger(.quit) }),
                (failed ? "Make it healthy" : "Make it fail", { failed.toggle() }), ("Reset", { reset() }),
            ])
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
        .animation(motion.standard, value: asking)
        .animation(motion.standard, value: outcome)
    }

    private var message: String {
        let what = failed ? "Query 1's transaction failed. Nothing can be committed." : "Query 1 has a transaction that is not committed."
        switch detail {
        case .sentence: return what
        case .counts: return what + (failed ? "" : "\nOpen for 12 minutes · 3 statements changed data.")
        case .statements: return what + "\nUPDATE orders … WHERE id = 1042\nDELETE FROM carts WHERE user_id = 7\nINSERT INTO audit VALUES (…)"
        }
    }

    private var title: String {
        switch asking {
        case .close, .none: failed ? "Close Query 1?" : "Commit before closing Query 1?"
        case .switchDB: failed ? "Switch database?" : "Commit before switching database?"
        case .quit: failed ? "Quit Echo?" : "Commit before quitting?"
        }
    }

    @ViewBuilder
    private var buttons: some View {
        HStack(spacing: SpacingTokens.xs) {
            Button("Cancel") { resolve(nil) }
                .keyboardShortcut(defaultButton == .cancel ? .defaultAction : .cancelAction)
            Spacer(minLength: SpacingTokens.none)
            Button("Roll Back", role: .destructive) { resolve("rolled back") }
                .keyboardShortcut(defaultButton == .rollBack ? .defaultAction : nil)
            if !failed {
                Button("Commit") { resolve("committed") }
                    .keyboardShortcut(defaultButton == .commit ? .defaultAction : nil)
            }
        }
        .controlSize(.regular)
    }

    private var alert: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Image(systemName: "exclamationmark.triangle.fill").font(TypographyTokens.iconLarge).foregroundStyle(ColorTokens.Status.warning)
            Text(title).font(TypographyTokens.headline)
            Text(message).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
            buttons
        }
        .padding(SpacingTokens.md)
        .frame(width: 320)
        .background(ColorTokens.Workspace.card, in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.large))
        .shadow(radius: 20, y: 8)
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text(title).font(TypographyTokens.headline)
            Text(message).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            GroupBox {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Label("Started 12 minutes ago", systemImage: "clock")
                    Label("3 statements changed data", systemImage: "square.and.pencil")
                    Label("Holds row locks on orders, carts", systemImage: "lock")
                }
                .font(TypographyTokens.detail)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            buttons
        }
        .padding(SpacingTokens.md)
        .frame(width: 420)
        .background(ColorTokens.Workspace.card, in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.large))
        .shadow(radius: 16, y: 6)
    }

    private var popover: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text(title).font(TypographyTokens.labelBold)
            Text(message).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
            buttons.controlSize(.small)
        }
        .padding(SpacingTokens.sm)
        .frame(width: 280)
        .background(ColorTokens.Workspace.card, in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.medium))
        .shadow(radius: 10, y: 4)
    }

    private func toast(_ text: String) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.xs) {
            Image(systemName: "arrow.uturn.backward.circle.fill").foregroundStyle(ColorTokens.Status.warning)
            VStack(alignment: .leading, spacing: SpacingTokens.nano) {
                Text("Query 1 closed").font(TypographyTokens.labelBold)
                Text(text).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            }
        }
        .padding(SpacingTokens.sm)
        .frame(width: 260, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.large))
    }

    private func trigger(_ what: Trigger) {
        guard tabs.contains(0) else { return }
        outcome = nil
        switch form {
        case .silent:
            finish(what, verb: nil)
        case .rollBackAndTell:
            finish(what, verb: "rolled back")
        default:
            asking = what
        }
    }

    private func resolve(_ verb: String?) {
        guard let what = asking else { return }
        asking = nil
        guard let verb else { outcome = "Nothing changed: Query 1 is still open."; return }
        finish(what, verb: verb)
    }

    private func finish(_ what: Trigger, verb: String?) {
        if what == .close || what == .quit { tabs.removeAll { $0 == 0 } }
        switch (form, verb) {
        case (.silent, _): outcome = what == .switchDB ? "Switched. (The transaction was silently rolled back.)" : "Closed. (The transaction was silently rolled back.)"
        case (.rollBackAndTell, _): outcome = "Its transaction was rolled back: 3 statements."
        case (_, let verb?): outcome = "The transaction was \(verb), then \(what == .switchDB ? "the database switched" : "the tab closed")."
        default: break
        }
    }

    private func reset() { tabs = [0, 1, 2]; asking = nil; outcome = nil; failed = false }
}

/// Quitting with two tabs in a transaction: one alert that lists them.
struct PgGuardQuitExhibit: View {
    var body: some View {
        ZStack {
            ColorTokens.Workspace.canvas
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Image(systemName: "exclamationmark.triangle.fill").font(TypographyTokens.iconLarge).foregroundStyle(ColorTokens.Status.warning)
                Text("2 tabs have transactions that are not committed").font(TypographyTokens.headline)
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Label("Query 1 · shop · 12 min · 3 statements", systemImage: "arrow.triangle.branch")
                    Label("Fix prices · analytics · 2 min · 1 statement", systemImage: "arrow.triangle.branch")
                }
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                HStack {
                    Button("Cancel") {}
                    Spacer()
                    Button("Roll Back All", role: .destructive) {}
                    Button("Review…") {}.keyboardShortcut(.defaultAction)
                }
            }
            .padding(SpacingTokens.md)
            .frame(width: 380)
            .background(ColorTokens.Workspace.card, in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.large))
            .shadow(radius: 20, y: 8)
        }
    }
}
