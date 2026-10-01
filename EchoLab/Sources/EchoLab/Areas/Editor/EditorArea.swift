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
        summary: "An opaque editor card in SF Mono with 20pt lines, a quiet gutter, a bracket on the statement at the caret with a Run arrow, and a plain Run button that becomes a stop and a timer while a query runs.",
        asBuilt: AsBuiltPage(
            verification: .init(
                level: .code, commit: "30e73ffb", date: "2026-09-30",
                note: "Read from QueryRunToolbarControl, WorkspaceTab+RunModes, QueryRunMode, LineNumberRulerView, SQLTextView+StatementFocus and +RunNote, EmptyQueryHints, SQLEditorTheme and the editor settings. The specimen is a copy of the Run control (native button, accent with a selection, red while running) beside an editor card that draws the gutter styles, caret line, statement focus, error dot and run note."),
            stageHeight: 520,
            behaviours: [
                .init(trigger: "Idle", result: "Run is a standard toolbar button, a plain ▶ in a capsule of its own, like its neighbours: no tint, no chevron. It is disabled while the script is empty or a query is running."),
                .init(trigger: "Text selected", result: "▶ turns the accent colour: Run will run only the selection."),
                .init(trigger: "⌘↩ or click ▶", result: "Runs the query. The whole capsule turns red (the system's prominent glass) with ■ and the elapsed time."),
                .init(trigger: "Click ■", result: "Cancels the query (⌥⌘. also cancels)."),
                .init(trigger: "Query ends", result: "✓ or ! shows for a moment, then the button settles back to ▶."),
                .init(trigger: "Right-click Run", result: "The four modes: Run, Run Statement at Cursor, Explain, Explain Analyze (also in the Query menu). The Explain modes are offered only for engines that provide execution plans."),
                .init(trigger: "Caret in a statement", result: "With Statement Focus on (the default) and more than one statement in the script: a thin accent bracket beside the statement's line numbers and a grey Run arrow in the gutter (accent under the pointer) that runs just that statement. On a line with an error dot the arrow is not drawn (round 28.4)."),
                .init(trigger: "After a run", result: "A glass pill after each statement that ran: the result's symbol with the rows (every row the server sent) and time in grey, or “! Error”; the detail is in its tooltip. While it runs the statement's bracket breathes; when it ends a line beside it fades (round 28.7)."),
                .init(trigger: "A mistake", result: "A tinted red pill behind the word, the same while typing and after a run; its message in a glass popover on hover or with the caret on the line. The live check runs when you leave the line or 2 s after typing (round 28.6)."),
                .init(trigger: "Caret on a word", result: "Its other uses get a soft tint as high as the letters; typing ) flashes its ( (round 28.5)."),
                .init(trigger: "Zoom", result: "The 100% pill at the bottom left, ⌘+ ⌘− ⌘0 or pinch; this tab only (round 28.8)."),
                .init(trigger: "Typing", result: "Tab is 4 spaces, ⇧Tab outdents, Return keeps the indent, ( and quotes close themselves, ⌘/ toggles --, ⌘L opens a Go to Line field (round 28.9)."),
                .init(trigger: "First run", result: "The results grow up out of the footer while the editor card shrinks."),
                .init(trigger: "Drag the gap between the cards", result: "Resizes them; a grab capsule shows on hover. Double-click the gap maximises the results, leaving a one-line editor."),
                .init(trigger: "Empty tab", result: "“Start typing a query” on the first line, where the caret is, in the editor's font (round 28.10)."),
                .init(trigger: "Outline Edge (setting, off)", result: "A strip on the editor's right edge marks statements and errors; click it to jump."),
                .init(trigger: "Caret line", result: "Nothing behind the text; the caret's line number is in the text colour (rounds 28.2 and 28.3)."),
                .init(trigger: "Select text", result: "The system's selection colour with 3pt corners (Settings › Selection Corners: Square, 2, 3, 4 or 6pt); grey while the editor isn't focused (round 28.3)."),
                .init(trigger: "Select a script result", result: "Its statement gets the bracket, solid (round 21 SK2, round 28.4)."),
                .init(trigger: "Wrapped lines", result: "One number per logical line; wrapped continuations stay blank, and the empty line after a final newline is numbered."),
                .init(trigger: "Statement ends at", result: "A semicolon, a GO line or a blank line."),
            ],
            motions: [
                .init(name: "Run to running to result", curve: "house spring", duration: "0.45s", note: "The capsule's contents change in place; nothing else moves."),
                .init(name: "Result hold", curve: "shows, then returns to idle", duration: "2.4s", note: "QueryRunToolbarControl.resultHold"),
                .init(name: "Selection accent", curve: "ease out", duration: "0.12s", note: "echoMotion.hover"),
                .init(name: "Results grow out of the footer", curve: "house spring", duration: "0.45s"),
            ],
            measurements: [
                .init(label: "Run", value: "A standard toolbar button, icon only, in its own toolbar group"),
                .init(label: "Run while running", value: "Prominent glass tinted red, title and icon (■ and the timer)", token: "ColorTokens.Status.error"),
                .init(label: "Run with a selection", value: "▶ in the accent colour", token: "ColorTokens.accent"),
                .init(label: "Editor font size", value: "13pt (setting); ligatures off unless turned on for a font", token: "editor font setting"),
                .init(label: "Line height", value: "20pt at 13pt: Comfortable, 1.55 × the size (Compact 1.3, Relaxed 1.75; never under the font's own height). Round 28.1 fixed the setting being counted twice (31pt)", token: "EditorLineHeight / SQLLayoutManager.lineHeight"),
                .init(label: "Margins", value: "8pt above the first line; the code 16pt after the numbers (7pt to the gutter's edge, then the text view's 9pt)", token: "textContainerInset / LayoutTokens.EditorGutter.numberTrailing"),
                .init(label: "Editor font", value: "SF Mono by default (round 28.1; JetBrains Mono before); bundled: JetBrains Mono, Geist Mono, Google Sans Code, Intel One Mono, Martian Mono, Fragment Mono, Atkinson Hyperlegible Mono, Cascadia Code, Commit Mono and five Monaspace variants", token: "SQLEditorTheme.bundledFontFamilies"),
                .init(label: "Gutter styles", value: "Subtle (default) · Column · Lane · Hairline (setting; Hairline from round 28.2)", token: "EditorGutterStyle"),
                .init(label: "Gutter numbers", value: "SF digits 2pt under the code (11pt at 13pt), tertiary label; the caret's line in the text colour, same weight (round 28.2)", token: "LineNumberRulerView.numberFont(forCodeSize:)"),
                .init(label: "Gutter width", value: "4pt + 5pt dot + 2pt + the digits (at least 2) + 7pt", token: "LayoutTokens.EditorGutter"),
                .init(label: "Column edge", value: "0.5pt separator", token: "LayoutTokens.EditorGutter.edgeWidth"),
                .init(label: "Lane", value: "inset 5pt, corner 8pt, no edge", token: "laneInset / laneCornerRadius"),
                .init(label: "Validation marker", value: "A 5pt red dot beside the number of a failing line", token: "markerSize / ColorTokens.Status.error"),
                .init(label: "Run arrow", value: "8pt triangle at the gutter's leading edge, tertiary grey, accent under the pointer", token: "LayoutTokens.EditorGutter.runArrowSize"),
                .init(label: "Statement bracket", value: "2pt accent capsule at 70%, 4pt after the numbers, inset 2pt; solid for a selected result's statement", token: "LayoutTokens.EditorGutter.statementBracket*"),
                .init(label: "Current line", value: "No band (round 28.3)"),
                .init(label: "Selection", value: "System selection colour, 3pt corners (setting)", token: "EditorSelectionCorners / SQLLayoutManager"),
                .init(label: "Caret", value: "The system insertion point (accent)", token: "NSColor.textInsertionPointColor"),
                .init(label: "Run note", value: "11pt, 20pt after the last character", token: "LayoutTokens.EditorGutter.runNoteGap"),
                .init(label: "Empty prompt", value: "“Start typing a query”, the editor's font, placeholder colour, at the caret on line 1", token: "SQLTextView.emptyPrompt"),
                .init(label: "Error mark", value: "red pill at 14%, as high as the letters; bubble max 360pt", token: "LayoutTokens.EditorGutter.errorPillOpacity / errorBubbleMaxWidth"),
                .init(label: "Word highlight", value: "label colour at 9%, letters' height, Highlight Corners (3pt)", token: "LayoutTokens.EditorGutter.highlightOpacity"),
                .init(label: "Zoom", value: "50%, 75%, 90%, 100%, 110%, 125%, 150%, 200%", token: "EditorZoom.levels"),
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
                "Echo/Sources/Features/AppHost/Views/Tabs/EditorContainer/EmptyQueryHints.swift",
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
