import Observation
import SwiftUI

/// The editor card and Run as they are in Echo today (plan Phases 11 and 17, round 15 idea 1).
@MainActor
enum EditorArea {
    private static let runState = RunSpecimenState()

    static let area = LabArea(
        id: "editor",
        title: "Editor and running",
        symbol: "curlybraces",
        summary: "An opaque editor card in SF Mono with 20pt lines, a quiet gutter, a bracket on the statement at the caret with a Run arrow, and a plain Run button whose capsule turns red with ■ and the time while a query runs.",
        asBuilt: AsBuiltPage(
            verification: .init(
                level: .code, commit: "3626716a", date: "2026-10-01",
                note: "Read from QueryRunToolbarControl(+Components), QueryRunButtonText, WorkspaceTab+RunModes, QueryRunMode, QueryRunNote, LineNumberRulerView, SQLTextView+StatementFocus, +RunNote, +Marks and +Find, EditorZoomControl, QueryInputSection, SQLEditorTheme and the editor settings. The specimen is a copy of the Run control (native button, accent with a selection, red while running) beside an editor card that draws the gutter styles, caret line, statement focus, error dot and run note."),
            stageHeight: 520,
            behaviours: [
                .init(trigger: "Idle", result: "Run is a plain ▶ in a glass capsule of its own, sized like its neighbours: no tint, no chevron. Grey and disabled while there is nothing to run; the tooltip says where it will run (“Run in sales on prod (⌘↩)”) or “Type a query to run” (round 20)."),
                .init(trigger: "Text selected", result: "▶ turns the accent colour: Run will run only the selection."),
                .init(trigger: "⌘↩ or click ▶", result: "Runs the query. ▶ becomes ■ in place as the capsule fades to red; just after, the capsule widens and the time (“5 s”, then “1:05”) fades in (rounds 20, 24)."),
                .init(trigger: "Click ■ or ⌘↩", result: "Stops the query (⌥⌘. also cancels). Until the server stops, a spinner and “Stopping” on a dimmer red. A cancelled statement's run note says “Cancelled after 3.2 s · 1,200 rows” in orange, and “The transaction now needs ROLLBACK” when it was inside one (round 21)."),
                .init(trigger: "Query ends", result: "The red drains as a green ✓ draws itself (or a red ! shows) for 2.4 s, then ▶ again; after a cancel it goes straight back to ▶."),
                .init(trigger: "Right-click Run", result: "The four modes: Run, Run Statement at Cursor, Explain, Explain Analyze (also in the Query menu). The Explain modes are offered only for engines that provide execution plans."),
                .init(trigger: "Caret in a statement", result: "With Statement Focus on (the default) and more than one statement in the script: a thin accent bracket beside the statement's line numbers and a grey Run arrow in the gutter (accent under the pointer) that runs just that statement. On a line with an error dot the arrow is not drawn (round 28.4)."),
                .init(trigger: "After a run", result: "A glass pill after each statement that ran: the result's symbol with the rows (every row the server sent) and time in grey, or “! Error”; the detail is in its tooltip. While it runs the statement's bracket breathes; when it ends a line beside it fades (round 28.7)."),
                .init(trigger: "A mistake", result: "A strong red mark behind the word (round 28.15), the same while typing and after a run; its message in a glass popover on hover or with the caret on the line. The live check runs when you leave the line or 2 s after typing (round 28.6)."),
                .init(trigger: "Caret on a word", result: "Its other uses get a soft grey mark as high as the letters; typing ) flashes its ( (round 28.5)."),
                .init(trigger: "⌘F, ⌥⌘F", result: "Echo's find bar: a glass capsule with glass buttons over the top of the editor; a selected word becomes the search, a selection over several lines gets a Selection button (on). ⌥⌘F or the chevron opens Replace inside the capsule as it grows; each match then shows its replacement (old struck through on red, new on green) without changing the script. Return replaces and moves on; Replace All is one undo and says “Replaced 12” (rounds 28.12, 28.13)."),
                .init(trigger: "Every mark", result: "As high as the letters, round ends (Settings › Editor › Marks › Corners, also the selection), soft 10% or strong 22% (Strength), coloured by meaning: grey the same word, yellow found, red wrong or removed, green added (round 28.15)."),
                .init(trigger: "Zoom", result: "The 100% pill at the bottom left, ⌘+ ⌘− ⌘0 or pinch; this tab only (round 28.8). It sits like the footer's pills: 12pt in and 9pt up with results; without results, stacked 9pt above the server pill (round 31)."),
                .init(trigger: "Typing", result: "Tab is 4 spaces, ⇧Tab outdents, Return keeps the indent, ( and quotes close themselves, ⌘/ toggles --, ⌘L opens a Go to Line field (round 28.9)."),
                .init(trigger: "First run", result: "The results grow up out of the footer while the editor card shrinks."),
                .init(trigger: "Drag the gap between the cards", result: "Resizes them; a grab capsule shows on hover. Double-click the gap maximises the results, leaving a one-line editor."),
                .init(trigger: "Empty tab", result: "“Start typing a query” on the first line, where the caret is, in the editor's font (round 28.10)."),
                .init(trigger: "Outline Edge (setting, off)", result: "A strip on the editor's right edge marks statements and errors; click it to jump."),
                .init(trigger: "Caret line", result: "Nothing behind the text; the caret's line number is in the text colour (rounds 28.2 and 28.3)."),
                .init(trigger: "Select text", result: "The system's selection colour with the marks' corners (Settings › Editor › Marks › Corners); grey while the editor isn't focused (round 28.3)."),
                .init(trigger: "Select a script result", result: "Its statement gets the bracket, solid (round 21 SK2, round 28.4)."),
                .init(trigger: "Wrapped lines", result: "One number per logical line; wrapped continuations stay blank, and the empty line after a final newline is numbered."),
                .init(trigger: "Statement ends at", result: "A semicolon, a GO line or a blank line."),
            ],
            motions: [
                .init(name: "Run to running to result", curve: "echoMotion.settle", duration: "0.45s", note: "▶ to ■ and the red first; the width and the time 0.25 s later. Nothing else in the toolbar moves."),
                .init(name: "Result hold", curve: "shows, then returns to idle", duration: "2.4s", note: "QueryRunToolbarControl.resultHold"),
                .init(name: "Selection accent", curve: "ease out", duration: "0.12s", note: "echoMotion.hover"),
                .init(name: "Results grow out of the footer", curve: "house spring", duration: "0.45s"),
            ],
            measurements: [
                .init(label: "Run", value: "Its own interactive glass capsule, sized like the toolbar's other capsules", token: "LayoutTokens.Toolbar.capsuleHorizontalPadding / glyph"),
                .init(label: "Run while running", value: "A red fill inside the glass with ■ and the time in white; 60% while stopping", token: "ColorTokens.Status.error / ColorTokens.Text.onFill"),
                .init(label: "Run with a selection", value: "▶ in the accent colour", token: "ColorTokens.accent"),
                .init(label: "Editor font size", value: "13pt (setting); ligatures off unless turned on for a font", token: "editor font setting"),
                .init(label: "Line height", value: "20pt at 13pt: Comfortable, 1.55 × the size (Compact 1.3, Relaxed 1.75; never under the font's own height). Round 28.1 fixed the setting being counted twice (31pt)", token: "EditorLineHeight / SQLLayoutManager.lineHeight"),
                .init(label: "Margins", value: "8pt above the first line; the code 16pt after the numbers (7pt to the gutter's edge, then the text view's 9pt)", token: "textContainerInset / LayoutTokens.EditorGutter.numberTrailing"),
                .init(label: "Editor font", value: "SF Mono by default (round 28.1; JetBrains Mono before); bundled: JetBrains Mono, Geist Mono, Google Sans Code, Intel One Mono, Martian Mono, Fragment Mono, Atkinson Hyperlegible Mono, Cascadia Code, Commit Mono and five Monaspace variants", token: "SQLEditorTheme.bundledFontFamilies"),
                .init(label: "Gutter styles", value: "Subtle (default) · Column · Lane · Hairline (setting); Column, Hairline and Lane drawn behind the editor, the card's full height; the lane 5pt from the card's edges, concentric corners, the system's quiet fill, numbers centred (round 28.14)", token: "EditorGutterStyle / EditorGutterSurface"),
                .init(label: "Gutter numbers", value: "SF digits 2pt under the code (11pt at 13pt), tertiary label; the caret's line in the text colour, same weight (round 28.2)", token: "LineNumberRulerView.numberFont(forCodeSize:)"),
                .init(label: "Gutter width", value: "4pt + 5pt dot + 2pt + the digits (at least 2) + 7pt", token: "LayoutTokens.EditorGutter"),
                .init(label: "Column edge", value: "0.5pt separator", token: "LayoutTokens.EditorGutter.edgeWidth"),
                .init(label: "Lane", value: "inset 5pt, corner 8pt, no edge", token: "laneInset / laneCornerRadius"),
                .init(label: "Validation marker", value: "A 5pt red dot beside the number of a failing line", token: "markerSize / ColorTokens.Status.error"),
                .init(label: "Run arrow", value: "8pt triangle at the gutter's leading edge, tertiary grey, accent under the pointer", token: "LayoutTokens.EditorGutter.runArrowSize"),
                .init(label: "Statement bracket", value: "2pt accent capsule at 70%, 4pt after the numbers, inset 2pt; solid for a selected result's statement", token: "LayoutTokens.EditorGutter.statementBracket*"),
                .init(label: "Current line", value: "No band (round 28.3)"),
                .init(label: "Selection", value: "System selection colour, the marks' corners (setting)", token: "EditorMarkCorners / SQLLayoutManager"),
                .init(label: "Caret", value: "The system insertion point (accent)", token: "NSColor.textInsertionPointColor"),
                .init(label: "Run note", value: "11pt, 20pt after the last character", token: "LayoutTokens.EditorGutter.runNoteGap"),
                .init(label: "Empty prompt", value: "“Start typing a query”, the editor's font, placeholder colour, at the caret on line 1", token: "SQLTextView.emptyPrompt"),
                .init(label: "Marks", value: "letters' height + 1pt, 2pt wider each side; soft 10%, strong 22%; round ends by default", token: "EditorMarkTokens"),
                .init(label: "Error mark", value: "a strong red mark; bubble max 360pt", token: "EditorMarkTokens.Meaning.wrong / errorBubbleMaxWidth"),
                .init(label: "Find bar", value: "400pt glass capsule, three 32pt glass circles, 8pt from the top", token: "LayoutTokens.EditorGutter.findBarWidth"),
                .init(label: "Zoom", value: "50%, 75%, 90%, 100%, 110%, 125%, 150%, 200%", token: "EditorZoom.levels"),
                .init(label: "Zoom pill", value: "24pt, 11pt primary; 12pt in; 9pt up with results, 42pt up above the server pill without (round 31)", token: "LayoutTokens.Footer.chipHeight / pillInset"),
            ],
            rules: [
                .init(text: "Run is a plain ▶ in its own capsule",
                      why: "Changing it must not move anything else in the toolbar. The accent-glass Run was replaced. Four other places (footer, editor corner, tab, only while running) were compared.",
                      rounds: ["ported.Round 15 · Run"]),
                .init(text: "No floating capsule in the editor",
                      why: "Editor actions (Format, Validate, Context Help, Estimated Plan) stay in the toolbar."),
                .init(text: "13pt SF Mono, lines 1.55 × the size",
                      why: "More room reads calmer without hiding code; size and line height are settings, and the line height has three names.",
                      rounds: ["ongoing.editor-text-r28"]),
                .init(text: "Nothing tints the text you type",
                      why: "No current-line band; the statement is a bracket in the gutter, not a band.",
                      rounds: ["ongoing.editor-caret-line-r28", "ongoing.editor-statement-r28"]),
                .init(text: "Numbers stop at the last line",
                      why: "The tinted gutter still runs the card's full height (GL1)."),
                .init(text: "Editor ideas are settings where they add chrome",
                      why: "Statement focus, inline results, errors on the line, the outline edge and the starting points were all accepted."),
            ],
            code: [
                "Echo/Sources/Features/QueryWorkspace/Views/Query/SQLTextView/",
                "Echo/Sources/Features/QueryWorkspace/Views/Query/LineNumberRulerView.swift",
                "Echo/Sources/Features/AppHost/Views/Toolbar/WorkspaceToolbarItems/QueryRunToolbarControl.swift",
                "Echo/Sources/Features/AppHost/EchoApp+QueryMenu.swift",
                "Echo/Sources/Shared/DesignSystem/Components/ContentPanelCards.swift",
                "Design/plan.md Phases 11 and 17",
            ]
        ) {
            RunButtonSpecimen(state: runState)
        }
        .controls {
            EditorControls(state: runState)
        },
        spec: EditorSpec.spec(stageHeight: 520, specimen: { RunButtonSpecimen(state: runState) }, controls: { EditorControls(state: runState) }).onState { runState.force($0) }
    )
}

private struct EditorControls: View {
    @Bindable var state: RunSpecimenState

    private var simulation: LabRunSimulation { state.simulation }

    var body: some View {
        @Bindable var simulation = state.simulation
        HStack(spacing: SpacingTokens.md) {
            Toggle("Text selected", isOn: $state.hasSelection)
            Picker("Gutter", selection: $state.gutter) {
                ForEach(EditorGutterLook.allCases) { Text($0.rawValue).tag($0) }
            }.frame(width: 200)
            Toggle("Statement focus", isOn: $state.statementFocus)
            Toggle("Error line", isOn: $state.showsError)
            Button(simulation.phase.isRunning ? "Cancel" : "Run (⌘↩)") { simulation.toggle() }
                .keyboardShortcut(.return, modifiers: .command)
            Button("Finish now") { simulation.finish(outcome: simulation.outcome) }
                .disabled(!simulation.phase.isRunning)
            Picker("The query", selection: $simulation.outcome) {
                ForEach(LabRunOutcome.allCases) { Text($0.rawValue).tag($0) }
            }
            .frame(width: 200)
            Picker("Takes", selection: $simulation.length) {
                ForEach(LabRunLength.allCases) { Text($0.rawValue).tag($0) }
            }
            .frame(width: 200)
            Spacer()
        }
    }
}
