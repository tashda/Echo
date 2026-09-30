import SwiftUI

/// Round 21 · Postgres: where the error is. Postgres reports the character position of an error
/// and often a hint ("Perhaps you meant to reference the column orders.status"). Echo today repeats
/// the SQL in Messages with a caret under it. Touches EDT-2.3, EDT-3.3 and FTR-2.3.
@MainActor
enum PgErrorLocationRound {
    enum Mark: String, CaseIterable {
        case caretInMessages = "EM1 · Caret in Messages (today)"
        case squiggle = "EM2 · Squiggle under the word"
        case gutter = "EM3 · Gutter marker and line tint"
        case bubble = "EM4 · Error bubble under the line"
        case squiggleHover = "EM5 · Squiggle, bubble on hover"
    }
    enum Hint: String, CaseIterable {
        case messages = "EH1 · In Messages (today)"
        case withError = "EH2 · With the error in the editor"
        case fix = "EH3 · With a Fix button when it names a column"
    }
    enum Clearing: String, CaseIterable {
        case nextRun = "EC1 · On the next run"
        case edit = "EC2 · When the line is edited"
        case either = "EC3 · Whichever comes first"
    }

    private static let width: CGFloat = 620
    private static let height: CGFloat = 400

    static let spec = RoundSpec(
        controls: [
            .of("mark", "Mark", Mark.self, default: .squiggleHover,
                question: "Run the query. How fast do you see which word is wrong, and does the mark stay out of the way while you fix it?",
                recommend: .squiggleHover,
                why: "A squiggle under the exact word is how macOS marks spelling and how Xcode marks errors: precise and quiet, with the message a hover away. A permanent bubble pushes lines down while you type; the gutter marker only gives the line; the caret in Messages makes you switch segments and count characters."),
            .of("hint", "Hint", Hint.self, default: .fix,
                question: "The server suggests the right column. Where should that suggestion be?",
                recommend: .fix,
                why: "When the hint names a column (the common typo case) one click fixes it; otherwise the hint sits under the message in the bubble. Leaving hints in Messages means most people never read them."),
            .of("clearing", "Clearing", Clearing.self, default: .either,
                question: "Fix the typo, then run. When should the mark go away?",
                recommend: .either,
                why: "A mark on a line you have already changed points at text that is no longer there; a mark after a successful run is stale too. Clearing on whichever comes first matches the run note, which fades when edited (EDT-3.3)."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "The run note shows the error at the statement's end; Messages repeats the SQL with ^ under the position.",
                  isEchoToday: true, designWidth: width, designHeight: height) { _ in
                PgErrorExhibit(mark: .caretInMessages, hint: .messages, clearing: .nextRun)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Hover the mark; press Fix typo or Use orders.status.",
                  designWidth: width, designHeight: height) { values in
                PgErrorExhibit(mark: Mark(rawValue: values["mark"]) ?? .squiggleHover,
                               hint: Hint(rawValue: values["hint"]) ?? .fix,
                               clearing: Clearing(rawValue: values["clearing"]) ?? .either)
            },
        ],
        questions: [
            .init(id: "runNote", title: "The run note",
                  question: "The run note at the end of the statement shows the error too. Keep it?",
                  choices: [
                      .init(id: "short", name: "RN1 · Keep it short: '! Error' — the mark carries the message"),
                      .init(id: "full", name: "RN2 · Keep the full message (today)"),
                      .init(id: "none", name: "RN3 · Remove it for errors"),
                  ],
                  recommended: "short",
                  why: "The note says that the statement failed at the place you look after running; the mark says where and why. Two full copies of the message compete."),
            .init(id: "jump", title: "Jump to the error",
                  question: "After a failed run, should the caret move to the error?",
                  choices: [
                      .init(id: "click", name: "J1 · No, but clicking the error in Messages jumps there"),
                      .init(id: "move", name: "J2 · Yes, select the word"),
                  ],
                  recommended: "click",
                  why: "Moving the caret on its own loses your place (you may have kept typing while it ran); jumping on click gives the same help when you want it."),
            .init(id: "internal", title: "Errors inside functions",
                  question: "The error is inside a function the statement called (Postgres gives an internal position).",
                  choices: [
                      .init(id: "call", name: "IF1 · Mark the call, show the function's line in the bubble"),
                      .init(id: "statement", name: "IF2 · Mark the whole statement"),
                  ],
                  recommended: "call",
                  why: "The call is what you can change in this editor; the function's failing line tells you what went wrong inside it."),
        ],
        exhibitTopic: ("Point at the error?", "Run the broken query in both. Does the proposal get you to the fix faster?",
                       "proposal",
                       "It marks the exact word where you are already looking and offers the server's suggestion as one click, instead of a caret in another segment."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "EM5, EH3, EC3.",
                  values: ["mark": Mark.squiggleHover.rawValue, "hint": Hint.fix.rawValue, "clearing": Clearing.either.rawValue],
                  isRecommended: true),
            .init(id: "explicit", name: "Most explicit", summary: "EM4, EH2, EC1.",
                  values: ["mark": Mark.bubble.rawValue, "hint": Hint.withError.rawValue, "clearing": Clearing.nextRun.rawValue]),
            .init(id: "today", name: "Like Echo today", summary: "EM1, EH1, EC1.",
                  values: ["mark": Mark.caretInMessages.rawValue, "hint": Hint.messages.rawValue, "clearing": Clearing.nextRun.rawValue]),
        ]
    )
}

struct PgErrorExhibit: View {
    typealias R = PgErrorLocationRound
    let mark: R.Mark
    let hint: R.Hint
    let clearing: R.Clearing

    @State private var column = "stats"
    @State private var failed = false
    @State private var edited = false
    @State private var hovering = false
    @State private var segment = "Results"
    @Environment(\.echoMotion) private var motion

    private let message = "column \"stats\" does not exist"
    private let hintText = "Perhaps you meant to reference the column \"orders.status\"."

    private var showsMark: Bool {
        guard failed, column == "stats" || !edited else { return false }
        if edited, clearing != .nextRun { return false }
        return true
    }

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            editor
            results
            PgSimBar(actions: [("▶ Run", { run() }), ("Fix typo", { column = "status"; edited = true }), ("Reset", { reset() })])
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
        .animation(motion.standard, value: showsMark)
        .animation(motion.hover, value: hovering)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            codeLine(1, Text("select order_id,"))
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.none) {
                codeLine(2, secondLine)
                if failed, !edited || clearing == .nextRun {
                    Text(mark == .caretInMessages ? "   ! \(message)" : "   ! Error")
                        .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.error)
                }
            }
            .background(mark == .gutter && showsMark ? ColorTokens.Status.error.opacity(0.08) : Color.clear)
            .overlay(alignment: .leading) {
                if mark == .gutter, showsMark {
                    Circle().fill(ColorTokens.Status.error).frame(width: SpacingTokens.xs, height: SpacingTokens.xs).offset(x: -SpacingTokens.xs)
                }
            }
            if showsMark, mark == .bubble || (mark == .squiggleHover && hovering) || (mark == .gutter && hint != .messages) {
                bubble.padding(.leading, SpacingTokens.xxl).transition(.opacity)
            }
            codeLine(3, Text("where status = 'paid';"))
            Spacer(minLength: SpacingTokens.none)
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .workspaceCard()
    }

    private var secondLine: Text {
        let word = Text(column)
        let marked = showsMark && (mark == .squiggle || mark == .squiggleHover)
            ? word.underline(true, pattern: .dot, color: ColorTokens.Status.error)
            : word
        return Text("       ") + marked + Text(", total from orders")
    }

    private func codeLine(_ number: Int, _ text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.sm) {
            Text("\(number)").foregroundStyle(ColorTokens.Text.quaternary).frame(width: SpacingTokens.lg, alignment: .trailing)
            text
                .onHover { if number == 2 { hovering = $0 } }
        }
        .font(TypographyTokens.code)
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Label(message, systemImage: "exclamationmark.octagon.fill").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.error)
            if hint != .messages {
                Text(hintText).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                if hint == .fix {
                    Button("Use orders.status") { column = "status"; edited = true }.controlSize(.small)
                }
            }
        }
        .padding(SpacingTokens.xs)
        .background(ColorTokens.Status.error.opacity(0.08), in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.small))
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.nano) {
            if segment == "Messages", failed {
                Text("ERROR: \(message)").foregroundStyle(ColorTokens.Status.error)
                if hint == .messages { Text("Hint: \(hintText)") }
                Text("SQLSTATE: 42703")
                if mark == .caretInMessages {
                    Text("select order_id,\n       stats, total from orders").font(TypographyTokens.detailMono)
                    Text("                ^").font(TypographyTokens.detailMono)
                }
            } else {
                Text(failed ? "The query failed. See Messages." : "Run the query.").foregroundStyle(ColorTokens.Text.tertiary)
            }
            Spacer(minLength: SpacingTokens.none)
            HStack {
                Picker("", selection: $segment) { Text("Results").tag("Results"); Text("Messages").tag("Messages") }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 180)
                Spacer()
                PgPill { PgStatusLabel(text: failed ? "Error" : "Ready", color: failed ? ColorTokens.Status.error : ColorTokens.Status.success) }
            }
        }
        .font(TypographyTokens.detail)
        .foregroundStyle(ColorTokens.Text.secondary)
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .workspaceCard()
    }

    private func run() {
        failed = column == "stats"
        edited = false
        if failed, mark == .caretInMessages { segment = "Messages" }
    }

    private func reset() { column = "stats"; failed = false; edited = false; segment = "Results" }
}
