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
        summary: "An opaque editor card with a quiet gutter, a statement focus with a Run arrow, and a plain Run button that becomes a stop and a timer while a query runs.",
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
                .init(trigger: "Caret in a statement", result: "With Statement Focus on (the default) and more than one statement in the script: a faint accent band behind the statement and a Run arrow in the gutter that runs just that statement. On a line with an error dot the arrow is not drawn."),
                .init(trigger: "After a run", result: "A note after the last line of what ran: green with the rows and time, or red with the error; the detail is in its tooltip."),
                .init(trigger: "First run", result: "The results grow up out of the footer while the editor card shrinks."),
                .init(trigger: "Drag the gap between the cards", result: "Resizes them; a grab capsule shows on hover. Double-click the gap maximises the results, leaving a one-line editor."),
                .init(trigger: "Empty tab", result: "\"Start typing, or begin with a recent table or a snippet\" in tertiary type, with chips: up to 4 tables last opened on this connection and database (a click inserts a query for their first rows), then up to 4 snippets for the dialect. They vanish on typing."),
                .init(trigger: "Outline Edge (setting, off)", result: "A strip on the editor's right edge marks statements and errors; click it to jump."),
                .init(trigger: "Caret line", result: "A rounded band across the card, shown only while nothing is selected."),
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
                .init(label: "Editor font size", value: "13pt (setting)", token: "editor font setting"),
                .init(label: "Line spacing", value: "1.55 (setting)"),
                .init(label: "Editor font", value: "JetBrains Mono by default; bundled: Geist Mono, Google Sans Code, Intel One Mono, Martian Mono, Fragment Mono, Atkinson Hyperlegible Mono, Cascadia Code, Commit Mono and five Monaspace variants", token: "SQLEditorTheme.bundledFontFamilies"),
                .init(label: "Gutter styles", value: "Subtle (default) · Column · Lane (setting)", token: "EditorGutterStyle"),
                .init(label: "Gutter numbers", value: "11pt monospaced digits; the caret's line semibold in the gutter accent", token: "LineNumberRulerView"),
                .init(label: "Gutter width", value: "4pt + 5pt dot + 2pt + the digits (at least 2) + 12pt", token: "LayoutTokens.EditorGutter"),
                .init(label: "Column edge", value: "0.5pt separator", token: "LayoutTokens.EditorGutter.edgeWidth"),
                .init(label: "Lane", value: "inset 5pt, corner 8pt, no edge", token: "laneInset / laneCornerRadius"),
                .init(label: "Validation marker", value: "A 5pt red dot beside the number of a failing line", token: "markerSize / ColorTokens.Status.error"),
                .init(label: "Run arrow", value: "8pt accent triangle at the gutter's leading edge", token: "LayoutTokens.EditorGutter.runArrowSize"),
                .init(label: "Statement band", value: "accent at 6%", token: "statementBandOpacity"),
                .init(label: "Current line", value: "Rounded band, 6pt inset, 6pt corner", token: "currentLineInset / currentLineCornerRadius"),
                .init(label: "Run note", value: "11pt, 20pt after the last character", token: "LayoutTokens.EditorGutter.runNoteGap"),
                .init(label: "Empty-tab hints", value: "up to 4 tables and 4 snippets, 52pt from the left, 32pt from the top", token: "LayoutTokens.EmptyQueryHints"),
            ],
            rules: [
                .init(text: "Run is a plain ▶ in its own capsule",
                      why: "Changing it must not move anything else in the toolbar. The accent-glass Run was replaced. Four other places (footer, editor corner, tab, only while running) were compared.",
                      rounds: ["ported.Round 15 · Run"]),
                .init(text: "No floating capsule in the editor",
                      why: "Editor actions (Format, Validate, Context Help, Estimated Plan) stay in the toolbar."),
                .init(text: "13pt with 1.55 line spacing",
                      why: "More room reads calmer; both are settings."),
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
