import SwiftUI

/// Round 28.9 · Editor: find, go to line and typing (rev 2: the find question moved to 28.12, the
/// owner's request for a find bar page). Echo today (SQLTextView, +Internal): the
/// native find bar (usesFindBar, incremental), ⌘L opens an alert with a field, lines wrap with
/// continuations indented 4 spaces (no switch in Settings), Tab types a tab character, nothing
/// closes brackets or quotes, Return starts the new line at the left edge, and there is no ⌘/.
@MainActor
enum EditorFindTypingRound {
    static let spec = RoundSpec(
        controls: [
            .of("goToLine", "Go to Line (⌘L)", LabQEGoToLine.self, default: .field,
                question: "Compare Go to Line in both exhibits. How should ⌘L ask for the line?",
                recommend: .field,
                why: "An alert stops everything for one number and covers the code you are jumping in. A small field at the top of the editor, like Xcode's ⌘L, takes the number and Return and is gone, and you can watch the jump.",
                summary: \.summary),
            LabQERound.sceneControl(default: .find),
            LabQERound.baseControl,
        ],
        exhibits: [
            .init(id: "today", title: "Echo before round 28", summary: "The native find bar; ⌘L opens an alert.", isEchoToday: true,
                  designWidth: LabQERound.width, designHeight: LabQERound.height) { values in
                LabQEEditor(style: .before28, scene: LabQERound.scene(values, .find))
                    .overlay { LabQEGoToLineView(look: .alert) }
            },
            .init(id: "proposal", title: "Proposal", summary: "The native find bar; ⌘L as chosen.",
                  designWidth: LabQERound.width, designHeight: LabQERound.height) { values in
                LabQEEditor(style: LabQEBase.proposal(values), scene: LabQERound.scene(values, .find))
                    .overlay(alignment: .top) { LabQEGoToLineView(look: LabQEGoToLine(rawValue: values["goToLine"]) ?? .field) }
            },
        ],
        questions: [
            .init(id: "tab", title: "Tab",
                  question: "What should Tab type (when EchoSense isn't showing)?",
                  choices: [
                      .init(id: "tabChar", name: "TB0 · A tab character (today)"),
                      .init(id: "spaces", name: "TB1 · 4 spaces; ⇧Tab outdents; Tab on a selection indents it"),
                  ],
                  recommended: "spaces",
                  why: "Scripts get pasted into tickets, Slack and other tools where tabs turn into 8 spaces; SSMS and DataGrip insert 4 spaces by default. Indenting a selected block with Tab is what everyone tries first."),
            .init(id: "indent", title: "Return",
                  question: "You press Return on an indented line. Where should the new line start?",
                  choices: [
                      .init(id: "left", name: "RT0 · At the left edge (today)"),
                      .init(id: "keep", name: "RT1 · Under the line above"),
                  ],
                  recommended: "keep",
                  why: "Every code editor keeps the indent; without it each AND under a WHERE needs two spaces typed by hand."),
            .init(id: "pairs", title: "Brackets and quotes",
                  question: "You type ( or '. Should Echo type the closing one for you?",
                  choices: [
                      .init(id: "off", name: "BQ0 · No (today, like SSMS)"),
                      .init(id: "on", name: "BQ1 · Yes, and typing the closing one steps over it"),
                  ],
                  recommended: "on",
                  why: "Unclosed quotes are the commonest cause of a script that turns red from one line down. With step-over you can type exactly as before; DataGrip and Xcode do it. A close call: say No if you often paste half-statements."),
            .init(id: "comment", title: "Comment out",
                  question: "Should ⌘/ comment out the selected lines (or the caret's line) with --, and uncomment them again?",
                  choices: [
                      .init(id: "yes", name: "CM1 · Yes, ⌘/ toggles --"),
                      .init(id: "no", name: "CM0 · No (today)"),
                  ],
                  recommended: "yes",
                  why: "It is the shortcut in Xcode, VS Code and DataGrip (SSMS has ⌘K ⌘C), and switching a WHERE condition off and on is everyday work in SQL."),
            .init(id: "wrap", title: "Long lines",
                  question: "Lines wrap today, with the continuation indented 4 spaces, and Settings can't change it. Keep that?",
                  choices: [
                      .init(id: "wrap", name: "LW0 · Wrap, continuations indented (today), with a switch in Settings"),
                      .init(id: "scroll", name: "LW1 · No wrapping: scroll sideways"),
                  ],
                  recommended: "wrap",
                  why: "Generated SQL and long IN lists run far off screen; wrapping keeps all of it readable in a narrow editor beside the tree and inspector. The setting already exists in Echo's data, it just has no switch (page 28.11)."),
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Go to Line as a field at the top.",
                  values: ["goToLine": LabQEGoToLine.field.rawValue], isRecommended: true),
            .init(id: "today", name: "Like Echo today", values: ["goToLine": LabQEGoToLine.alert.rawValue]),
        ]
    )
}

enum LabQEGoToLine: String, CaseIterable {
    case alert = "GL0 · An alert (today)"
    case field = "GL1 · A field at the top of the editor"

    var summary: String {
        self == .alert ? "NSAlert “Go to Line”, “Enter a line number:”, OK and Cancel."
            : "A small glass field over the editor's top edge; Return jumps, Escape closes."
    }
}

/// Go to Line, drawn open.
struct LabQEGoToLineView: View {
    let look: LabQEGoToLine

    var body: some View {
        switch look {
        case .alert:
            VStack(spacing: SpacingTokens.xs) {
                Image(systemName: "text.line.first.and.arrowtriangle.forward").font(TypographyTokens.title).foregroundStyle(ColorTokens.accent)
                Text(verbatim: "Go to Line").font(TypographyTokens.headline)
                Text(verbatim: "Enter a line number:").font(TypographyTokens.detail)
                Text(verbatim: "12").font(TypographyTokens.standard)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SpacingTokens.xxs)
                    .background(ColorTokens.Workspace.card, in: RoundedRectangle(cornerRadius: SpacingTokens.xxs))
                    .overlay(RoundedRectangle(cornerRadius: SpacingTokens.xxs).strokeBorder(ColorTokens.Separator.primary))
                HStack {
                    Text(verbatim: "Cancel").frame(maxWidth: .infinity).padding(.vertical, SpacingTokens.xxs)
                        .background(ColorTokens.Text.primary.opacity(0.06), in: Capsule())
                    Text(verbatim: "OK").foregroundStyle(ColorTokens.Text.onFill).frame(maxWidth: .infinity).padding(.vertical, SpacingTokens.xxs)
                        .background(ColorTokens.accent, in: Capsule())
                }
                .font(TypographyTokens.standard)
            }
            .padding(SpacingTokens.md)
            .frame(width: 240)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: SpacingTokens.md, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
        case .field:
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: "text.line.first.and.arrowtriangle.forward").foregroundStyle(ColorTokens.Text.secondary)
                Text(verbatim: "Line").foregroundStyle(ColorTokens.Text.secondary)
                Text(verbatim: "12")
                Spacer(minLength: SpacingTokens.none)
                Text(verbatim: "↩").foregroundStyle(ColorTokens.Text.tertiary)
            }
            .font(TypographyTokens.standard)
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xxs2)
            .frame(width: 220)
            .glassEffect(.regular, in: .capsule)
            .padding(.top, SpacingTokens.xxl)
        }
    }
}
