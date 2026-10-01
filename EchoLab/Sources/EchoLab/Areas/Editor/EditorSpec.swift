import SwiftUI

/// The editor card and Run by piece, each with a stable ID (`EDT-4.3`). Values come from
/// `LayoutTokens.EditorGutter`, the SQL text view and `QueryRunToolbarControl`.
@MainActor
enum EditorSpec {
    private static let textView = "Echo/Sources/Features/QueryWorkspace/Views/Query/SQLTextView/"
    private static let run = "Echo/Sources/Features/AppHost/Views/Toolbar/WorkspaceToolbarItems/QueryRunToolbarControl.swift"
    private static let tokens = "Packages/EchoDesignSystem/Sources/EchoDesignSystem/Tokens/LayoutToken.swift"
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
                .type(.row("Size", "13pt (setting)", token: "SQLEditorTheme.defaultFontSize"), .row("Line height", "Comfortable: 1.55 × the size, 20pt at 13pt (Compact 1.3, Relaxed 1.75)", token: "EditorLineHeight / SQLLayoutManager.lineHeight"),
                      .row("Default font", "SF Mono (round 28.1)", token: "SQLEditorTheme.defaultFontName"),
                      .row("Ligatures", "off unless turned on for a font"),
                      .row("Margins", "8pt above the first line, the code 16pt after the numbers", token: "textContainerInset"),
                      .row("Why", "more room reads calmer")),
                .behaviour(.row("Bundled fonts", "Geist Mono, Google Sans Code, Intel One Mono, Martian Mono, Fragment Mono, Atkinson Hyperlegible Mono, Cascadia Code, Commit Mono and five Monaspace variants", token: "SQLEditorTheme.bundledFontFamilies")),
            ], rounds: ["ongoing.editor-text-r28"], files: [textView]),
            SpecElement(number: "1.3", name: "Empty prompt", summary: "An empty tab shows “Start typing a query” where you type (round 28.10).", groups: [
                .type(.row("Prompt", "the editor's font, placeholder colour", token: "SQLTextView.emptyPrompt")),
                .layout(.row("Place", "on the first line, at the caret")),
                .behaviour(.row("Offers", "nothing else: the recent tables and snippets (QE6) were dropped"), .row("Goes", "with the first character")),
            ], rounds: ["ongoing.editor-empty-r28"], files: [textView]),
            SpecElement(number: "1.4", name: "Zoom", summary: "A glass “100%” pill at the editor's bottom left, placed like the footer's pills (rounds 28.8, 31).", groups: [
                .material(.row("Pill", "Liquid Glass capsule, 24pt like the footer's pills, 11pt primary text, a menu of 50% to 200% and Actual Size", token: "LayoutTokens.Footer.chipHeight / chipHorizontalPadding")),
                .layout(.row("With results", "12pt in, 9pt up: where the server pill sits in the results card", token: "LayoutTokens.Footer.pillInset"),
                        .row("Without results", "above the server pill, left edges aligned, 9pt between (42pt up)", token: "EditorZoomControl.bottomInset")),
                .behaviour(.row("Keys", "⌘+, ⌘− and ⌘0 in the View menu, and pinch"), .row("Scope", "this tab, until it closes; the editor's font and gutter, not the results")),
            ], rounds: ["ongoing.editor-zoom-r28", "ongoing.zoom-pill-footer-r31"], files: [textView, "Echo/Sources/Features/QueryWorkspace/Views/Query/EditorZoomControl.swift"]),
            SpecElement(number: "1.5", name: "Typing", summary: "Tab, Return, pairs and comments (round 28.9).", groups: [
                .behaviour(.row("Tab", "spaces to the next stop of four; on several lines, indents them; ⇧Tab outdents"),
                           .row("Return", "keeps the line's indent"),
                           .row("( and quotes", "close themselves; typing the closer steps over it"),
                           .row("⌘/", "toggles -- on the selected lines"),
                           .row("⌘L", "a small glass Go to Line field at the top, Return jumps, Escape closes")),
            ], rounds: ["ongoing.editor-find-typing-r28"], files: [textView]),
            SpecElement(number: "1.6", name: "Find and replace", summary: "Echo's glass find bar over the top of the editor; Replace opens inside it (rounds 28.12, 28.13).", groups: [
                .material(.row("Bar", "a 400pt glass capsule and three 32pt glass circles, 8pt from the top", token: "LayoutTokens.EditorGutter.findBarWidth")),
                .behaviour(.row("⌘F", "opens Find; a selected word becomes the search; Replace stays as it was"),
                           .row("⌥⌘F, the chevron", "opens Replace inside the capsule as it grows"),
                           .row("Selection", "a button, on, only when text over several lines is selected"),
                           .row("Preview", "each match shows its replacement: the old struck through on red, the new after it on green; the script changes only on Replace", token: "EditorMarkTokens.Meaning.wrong / added"),
                           .row("Return, Replace All", "Return replaces and moves on; Replace All is one undo and says “Replaced 12”")),
            ], rounds: ["ongoing.editor-find-bar-r28", "ongoing.editor-search-replace-r28"], files: ["Echo/Sources/Features/QueryWorkspace/Views/Query/Find/"]),
        ]),
        SpecPart(number: "2", name: "Gutter", summary: "The strip of line numbers at the left.", elements: [
            SpecElement(number: "2.1", name: "Style", summary: "Subtle (the default), Column, Lane or Hairline (a setting).", states: [SpecState(key: "column", name: "Column"), SpecState(key: "lane", name: "Lane"), SpecState(key: "subtle", name: "Subtle"), SpecState(key: "hairline", name: "Hairline")], defaultState: "column", groups: [
                .material(.row("Subtle", "numbers only"),
                          .row("Column", "a faint full-height column in the theme's gutter colour with a 0.5pt separator edge towards the text", token: "LayoutTokens.EditorGutter.edgeWidth"),
                          .row("Lane (GT2)", "the whole gutter, 5pt from the card's edges, the card's full height, corners concentric with the card's, the system's quiet fill, numbers centred, no edge (round 28.14)", token: "laneInset / EditorGutterSurface"),
                          .row("Hairline (round 28.2)", "no fill, only the 0.5pt separator edge", token: "LayoutTokens.EditorGutter.edgeWidth"),
                          .row("Drawn", "behind the editor across the card's full height (decd9770); the Lane: the whole gutter, 5pt from the card's edges, corners concentric with the card's, the system's quiet fill, numbers centred (round 28.14)", token: "EditorGutterSurface")),
                .behaviour(.row("Tint height", "always the card's full height, even below the last line (GL1)")),
            ], rounds: ["ongoing.editor-gutter-r28", "ongoing.editor-gutter-lane-r28"], files: [textView, tokens]),
            SpecElement(number: "2.2", name: "Numbers", summary: "Line numbers with room to breathe (QE4).", groups: [
                .type(.row("Font", "SF digits 2pt under the code (11pt at 13pt)", token: "LineNumberRulerView.numberFont(forCodeSize:)"),
                      .row("Colours", "tertiary label; the caret's line in the text colour, same weight (round 28.2)")),
                .layout(.row("Width", "4pt + 5pt dot + 2pt + the digits + 7pt", token: "LineNumberRulerView.thickness(forDigits:codeSize:)"),
                        .row("Minimum digits", "2, so the gutter doesn't jump at line 10", token: "LayoutTokens.EditorGutter.minimumDigits"),
                        .row("Gap to the code", "16pt: 7pt to the gutter's edge, then the text view's 9pt", token: "LayoutTokens.EditorGutter.numberTrailing")),
                .behaviour(.row("Wrapped lines", "one number per logical line; continuations stay blank"), .row("After a final newline", "the empty line is numbered")),
            ], rounds: ["ongoing.editor-gutter-r28"], files: [textView, tokens]),
            SpecElement(number: "2.3", name: "Validation marker", summary: "A red dot on a failing line.", states: [SpecState(key: "error", name: "Error line")], defaultState: "error", groups: [
                .layout(.row("Size", "5pt", token: "LayoutTokens.EditorGutter.markerSize"), .row("Leading", "4pt", token: "markerLeading")),
                .material(.row("Colour", "error", token: "ColorTokens.Status.error")),
                .behaviour(.row("Wins over the Run arrow", "a line with an error dot shows no Run arrow")),
            ], rounds: ["ongoing.editor-errors-r28"], files: [textView, tokens]),
            SpecElement(number: "2.4", name: "Current line", summary: "No band behind the caret's line (round 28.3, CL1); its number is in the text colour.", groups: [
                .behaviour(.row("Shown", "nothing; before round 28 a rounded band inset 6pt, corner 6pt")),
            ], rounds: ["ongoing.editor-caret-line-r28"], files: [textView, tokens]),
            SpecElement(number: "2.5", name: "Selection", summary: "The system's selection colour with rounded corners (round 28.3).", groups: [
                .material(.row("Colour", "the system selection colour; grey while the editor isn't focused")),
                .layout(.row("Corners", "the marks' corners: round by default; Settings › Editor › Marks › Corners (round 28.15)", token: "EditorMarkCorners / SQLLayoutManager.fillBackgroundRectArray")),
            ], rounds: ["ongoing.editor-caret-line-r28"], files: [textView]),
            SpecElement(number: "2.6", name: "Caret", summary: "The system's insertion point (round 28.3).", groups: [
                .material(.row("Colour", "the accent colour", token: "NSColor.textInsertionPointColor")),
                .behaviour(.row("Blinking", "as the system sets it")),
            ], rounds: ["ongoing.editor-caret-line-r28"], files: [textView]),
            SpecElement(number: "2.7", name: "Word highlight", summary: "The word at the caret's other uses: a soft tint as high as the letters (round 28.5).", groups: [
                .material(.row("Tint", "a soft grey mark (round 28.15)", token: "EditorMarkTokens.Meaning.same")),
                .layout(.row("Corners", "Settings › Editor › Marks › Corners, round by default")),
                .behaviour(.row("Typing )", "flashes its ( with the system's find indicator")),
            ], rounds: ["ongoing.editor-marks-r28"], files: [textView]),
            SpecElement(number: "2.8", name: "Error mark", summary: "A strong red mark behind a wrong word, the same while typing and after a run (rounds 28.6, 28.15).", groups: [
                .material(.row("Mark", "a strong red mark (round 28.15)", token: "EditorMarkTokens.Meaning.wrong")),
                .behaviour(.row("Bubble", "a popover (glass, with a pointer): title, message, detail, Fix; on hover or with the caret on the line"),
                           .row("Live check", "when the caret leaves the edited line, or 2 s after typing stops", token: "LayoutTokens.EditorGutter.liveCheckPause")),
            ], rounds: ["ongoing.editor-errors-r28"], files: [textView, "Echo/Sources/Features/QueryWorkspace/Views/Query/ErrorMark/"]),
        ]),
        SpecPart(number: "3", name: "Statement", summary: "The statement the caret is in.", elements: [
            SpecElement(number: "3.1", name: "Statement bracket", summary: "A thin bracket beside the statement's line numbers (QE1; a band before round 28.4).", groups: [
                .material(.row("Bracket", "2pt accent capsule at 70%, 4pt after the numbers, inset 2pt", token: "LayoutTokens.EditorGutter.statementBracket*"),
                          .row("A selected result's statement", "the same bracket, solid (SK2, SR1)")),
                .behaviour(.row("Shown", "with Statement Focus on (the default) and more than one statement in the script")),
            ], rounds: ["ongoing.editor-statement-r28"], files: [textView, tokens]),
            SpecElement(number: "3.2", name: "Run arrow", summary: "A small arrow in the gutter that runs just that statement.", groups: [
                .layout(.row("Size", "8pt high, 6.8pt wide, at the gutter's leading edge", token: "LayoutTokens.EditorGutter.runArrowSize")),
                .material(.row("Colour", "tertiary grey; the accent under the pointer (round 28.4, A1)")),
                .behaviour(.row("Click", "runs only that statement"), .row("Shown", "on the statement's first line, under the same conditions as the bracket")),
            ], rounds: ["ongoing.editor-statement-r28"], files: [textView, tokens]),
            SpecElement(number: "3.3", name: "Run note", summary: "After a run: a glass pill with the result's symbol and the rows and time, at the end of each statement (QE2, round 28.7).", groups: [
                .layout(.row("Gap after the last character", "20pt", token: "LayoutTokens.EditorGutter.runNoteGap")),
                .material(.row("Pill", "Liquid Glass capsule; checkmark.circle.fill green, exclamationmark.circle.fill red, stop.circle.fill orange (R10)")),
                .type(.row("Font", "11pt; the numbers secondary, an error's words red", token: "TypographyTokens.detail")),
                .behaviour(.row("Rows", "every row the server sent, the footer's count"), .row("A script", "one note after each statement (MS0)")),
                .behaviour(.row("Tooltip", "the detail of the result or error")),
            ], rounds: ["ongoing.editor-run-note-r28"], files: [textView, tokens]),
            SpecElement(number: "3.4", name: "Where a statement ends", summary: "At a semicolon, a GO line or a blank line.", groups: [
                .behaviour(.row("Ends at", "a semicolon, a GO line or a blank line")),
            ], files: [textView]),
            SpecElement(number: "3.5", name: "While running", summary: "The running statement's bracket breathes (round 28.7, RR1).", groups: [
                .motion(.row("Breath", "opacity 1 to 0.45 and back, 1.5 s, until the result", token: "LayoutTokens.EditorGutter.runningBreath*")),
            ], rounds: ["ongoing.editor-run-note-r28"], files: [textView, tokens]),
            SpecElement(number: "3.6", name: "What ran", summary: "When a run ends, a line beside what ran fades out (round 28.7, H9).", groups: [
                .motion(.row("Fade", "2 s, ease out", token: "LayoutTokens.EditorGutter.ranFadeDuration")),
            ], rounds: ["ongoing.editor-run-note-r28"], files: [textView, tokens]),
        ]),
        SpecPart(number: "4", name: "Run", summary: "A plain ▶ in a capsule of its own, like its neighbours.", elements: [
            SpecElement(number: "4.1", name: "Idle", summary: "A plain ▶ in a glass capsule of its own, sized like its neighbours (rounds 15, 20).", groups: [
                .material(.row("Glass", "its own interactive glass capsule", token: "LayoutTokens.Toolbar.capsuleHorizontalPadding"), .row("Tint", "none, and no chevron")),
                .states(.row("Disabled", "grey while there is nothing to run", token: "ColorTokens.Text.tertiary"),
                        .row("Help", "where it will run: “Run in sales on prod (⌘↩)”; “Type a query to run”", token: "QueryRunButtonText")),
                .behaviour(.row("Why", "changing Run must not move anything else in the toolbar; the accent-glass Run was replaced")),
            ], rounds: [r15], files: [run]),
            SpecElement(number: "4.2", name: "With a selection", summary: "▶ turns the accent colour: Run will run only the selection.", groups: [
                .states(.row("Colour", "accent", token: "ColorTokens.accent"), .row("Help", "Run Selection (⌘↩)")), .motion(.row("Change", "ease out, 0.12s", token: "echoMotion.hover")),
            ], rounds: [r15], files: [run]),
            SpecElement(number: "4.3", name: "Running", summary: "▶ becomes ■ as the capsule fades to red, then it widens for the time (rounds 20, 24).", groups: [
                .material(.row("Fill", "a red fill inside the glass; ■ and the time in white", token: "ColorTokens.Status.error / ColorTokens.Text.onFill")),
                .behaviour(.row("⌘↩ or click ▶", "runs the query"), .row("Click ■ or ⌘↩", "stops it; ⌥⌘. also cancels"),
                           .row("Stopping", "a spinner and “Stopping” on a 60% red until the server stops"),
                           .row("Time", "“5 s”, then “1:05”", token: "ElapsedTimeText")),
                .motion(.row("Run to running", "▶ to ■ and the red first, the width and the time 0.25 s later; echoMotion.settle, 0.45s; nothing else in the toolbar moves")),
            ], rounds: [r15, "ongoing.run-button-running-r20", "ongoing.run-into-running-r24"], files: [run]),
            SpecElement(number: "4.4", name: "Result", summary: "The red drains as a green ✓ draws itself, or a red ! shows, then ▶ again.", groups: [
                .motion(.row("Hold", "2.4s", token: "QueryRunToolbarControl.resultHold"), .row("✓", "draws itself (symbol draw-on)")),
                .behaviour(.row("After a cancel", "straight back to ▶")),
            ], rounds: [r15, "ongoing.run-button-look-r20"], files: [run]),
            SpecElement(number: "4.5", name: "Run menu", summary: "Right-click Run for the other modes.", groups: [
                .behaviour(.row("Items", "Run, Run Statement at Cursor, Explain, Explain Analyze (also in the Query menu)", token: "QueryRunMode"),
                           .row("Explain modes", "offered only for engines with execution plans; each item is disabled when it can't run")),
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
