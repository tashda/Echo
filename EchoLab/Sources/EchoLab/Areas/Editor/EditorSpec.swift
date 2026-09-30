import SwiftUI

/// The editor card and Run by piece, each with a stable ID (`EDT-4.3`). Values come from
/// `LayoutTokens.EditorGutter`, the SQL text view and `QueryRunToolbarControl`.
@MainActor
enum EditorSpec {
    private static let textView = "Echo/Sources/Features/QueryWorkspace/Views/Query/SQLTextView/"
    private static let run = "Echo/Sources/Features/AppHost/Views/Toolbar/WorkspaceToolbarItems/QueryRunToolbarControl.swift"
    private static let tokens = "Packages/EchoDesignSystem/.../LayoutToken.swift (EditorGutter)"
    private static let r15 = "ported.Round 15 · Run"

    static func spec<Specimen: View, Controls: View>(
        stageHeight: CGFloat, @ViewBuilder specimen: @escaping () -> Specimen, @ViewBuilder controls: @escaping () -> Controls
    ) -> AreaSpec {
        AreaSpec(code: "EDT", stageHeight: stageHeight, parts: parts, specimen: specimen).controls(controls)
    }

    private static let parts: [SpecPart] = [
        SpecPart(number: "1", name: "Editor card", summary: "The opaque card the SQL is written in.", elements: [
            SpecElement(number: "1.1", name: "Card", summary: "The same card as every content card.", groups: [
                .material(.row("Fill", "opaque", token: "ColorTokens.Workspace.card"), .row("Glass", "none")),
            ], rounds: ["decided.window-canvas-and-cards"], files: ["Echo/Sources/Shared/DesignSystem/Components/ContentPanelCards.swift"]),
            SpecElement(number: "1.2", name: "Text", summary: "The code's font, size and line spacing are settings.", groups: [
                .type(.row("Size", "13pt (setting)", token: "editor font setting"), .row("Line spacing", "1.55 (setting)"),
                      .row("Why", "more room reads calmer")),
                .behaviour(.row("Fonts bundled", "JetBrains Mono, Geist Mono, Google Sans Code, Intel One Mono, Martian Mono, Fragment Mono, Atkinson Hyperlegible Mono, Cascadia Code, Monaspace, Commit Mono"),
                           .row("Default font", "still to be picked")),
            ], files: [textView]),
            SpecElement(number: "1.3", name: "Starting points", summary: "An empty tab shows faint suggestions.", groups: [
                .behaviour(.row("Shows", "the last four tables opened on this connection, then snippets"), .row("Goes", "they vanish on typing")),
            ], files: [textView]),
        ]),
        SpecPart(number: "2", name: "Gutter", summary: "The strip of line numbers at the left.", elements: [
            SpecElement(number: "2.1", name: "Style", summary: "Subtle, Tinted column or Tinted lane (a setting).", groups: [
                .material(.row("Tinted lane (GT2)", "inset 5pt, corner 8pt, no edge line", token: "LayoutTokens.EditorGutter.laneInset / laneCornerRadius"),
                          .row("Edge", "0.5pt", token: "LayoutTokens.EditorGutter.edgeWidth")),
                .behaviour(.row("Tint height", "always the card's full height, even below the last line (GL1)")),
            ], files: [textView, tokens]),
            SpecElement(number: "2.2", name: "Numbers", summary: "Line numbers with room to breathe (QE4).", groups: [
                .layout(.row("Minimum digits", "2, so the gutter doesn't jump at line 10", token: "LayoutTokens.EditorGutter.minimumDigits"),
                        .row("Gap to the code", "12pt", token: "LayoutTokens.EditorGutter.numberTrailing")),
                .behaviour(.row("Last line", "numbers stop at the last line")),
            ], files: [textView, tokens]),
            SpecElement(number: "2.3", name: "Validation marker", summary: "A red dot on a failing line.", groups: [
                .layout(.row("Size", "5pt", token: "LayoutTokens.EditorGutter.markerSize"), .row("Leading", "4pt", token: "markerLeading")),
                .material(.row("Colour", "error", token: "ColorTokens.Status.error")),
            ], files: [textView, tokens]),
            SpecElement(number: "2.4", name: "Current line", summary: "A rounded band inside the card.", groups: [
                .layout(.row("Inset", "6pt from the card's edges", token: "LayoutTokens.EditorGutter.currentLineInset"),
                        .row("Corner", "6pt", token: "currentLineCornerRadius")),
            ], files: [textView, tokens]),
        ]),
        SpecPart(number: "3", name: "Statement", summary: "The statement the caret is in.", elements: [
            SpecElement(number: "3.1", name: "Statement band", summary: "A faint band on the statement at the caret (QE1).", groups: [
                .material(.row("Opacity", "6%", token: "LayoutTokens.EditorGutter.statementBandOpacity")),
            ], files: [textView, tokens]),
            SpecElement(number: "3.2", name: "Run arrow", summary: "A small arrow in the gutter that runs just that statement.", groups: [
                .layout(.row("Size", "8pt", token: "LayoutTokens.EditorGutter.runArrowSize")),
                .behaviour(.row("Click", "runs only that statement")),
            ], files: [textView, tokens]),
            SpecElement(number: "3.3", name: "Run note", summary: "After a run: the rows and time, or the error, at the end of the statement (QE2).", groups: [
                .layout(.row("Gap after the last character", "20pt", token: "LayoutTokens.EditorGutter.runNoteGap")),
                .behaviour(.row("Fades", "when the statement is edited")),
            ], files: [textView, tokens]),
            SpecElement(number: "3.4", name: "Where a statement ends", summary: "At a semicolon, a GO line or a blank line.", groups: [
                .behaviour(.row("Ends at", "a semicolon, a GO line or a blank line")),
            ], files: [textView]),
        ]),
        SpecPart(number: "4", name: "Run", summary: "A plain ▶ in a capsule of its own, like its neighbours.", elements: [
            SpecElement(number: "4.1", name: "Idle", summary: "A standard toolbar button, icon only, in its own toolbar group.", groups: [
                .material(.row("Glass", "the system's toolbar glass"), .row("Tint", "none, and no chevron")),
                .behaviour(.row("Why", "changing Run must not move anything else in the toolbar; the accent-glass Run was replaced")),
            ], rounds: [r15], files: [run]),
            SpecElement(number: "4.2", name: "With a selection", summary: "▶ turns the accent colour: Run will run only the selection.", groups: [
                .states(.row("Colour", "accent", token: "ColorTokens.accent")), .motion(.row("Change", "ease out, 0.12s", token: "echoMotion.hover")),
            ], rounds: [r15], files: [run]),
            SpecElement(number: "4.3", name: "Running", summary: "The whole capsule turns red with ■ and the elapsed time.", groups: [
                .material(.row("Fill", "the system's prominent glass, tinted red", token: "ColorTokens.Status.error")),
                .behaviour(.row("⌘↩ or click ▶", "runs the query"), .row("Click ■", "cancels; ⌥⌘. also cancels")),
                .motion(.row("Run to running", "house spring, 0.45s; the capsule's contents change in place and nothing else moves")),
            ], rounds: [r15], files: [run]),
            SpecElement(number: "4.4", name: "Result", summary: "✓ or ! shows for a moment, then it settles back to ▶.", groups: [
                .motion(.row("Hold", "2.4s", token: "QueryRunToolbarControl.resultHold")),
            ], rounds: [r15], files: [run]),
            SpecElement(number: "4.5", name: "Run menu", summary: "Right-click Run for the other modes.", groups: [
                .behaviour(.row("Items", "statement at cursor, Explain, Explain analyze (also in the Query menu)")),
            ], files: [run, "Echo/Sources/Features/AppHost/EchoApp+QueryMenu.swift"]),
            SpecElement(number: "4.6", name: "No floating capsule", summary: "Editor actions stay in the toolbar.", groups: [
                .behaviour(.row("Stay in the toolbar", "Format, Validate, Context Help, Estimated Plan")),
            ], rounds: [r15]),
        ]),
        SpecPart(number: "5", name: "Layout with results", summary: "How the editor and results share the tab.", elements: [
            SpecElement(number: "5.1", name: "First run", summary: "The results grow up out of the footer while the editor card shrinks.", groups: [
                .motion(.row("Curve", "house spring, 0.45s")),
            ], files: ["Echo/Sources/Shared/DesignSystem/Components/ContentPanelCards.swift"]),
            SpecElement(number: "5.2", name: "Resize", summary: "Drag the gap between the cards; double-click it to maximise the results.", groups: [
                .behaviour(.row("Grab capsule", "shows on hover"), .row("Maximised", "the editor keeps a one-line height")),
            ], files: ["Echo/Sources/Features/AppHost/Views/Navigation/WorkspaceView.swift"]),
        ]),
    ]
}
