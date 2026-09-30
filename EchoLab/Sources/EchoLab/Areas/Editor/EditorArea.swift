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
                level: .code, commit: "92d9b637", date: "2026-09-30",
                note: "The specimen is a copy of QueryRunToolbarControl as of 92d9b637 (native button, accent with a selection, fully red while running). Awaiting your confirmation in the running app."),
            stageHeight: 520,
            behaviours: [
                .init(trigger: "Idle", result: "Run is a standard toolbar button, a plain ▶ in a capsule of its own, like its neighbours: no tint, no chevron."),
                .init(trigger: "Text selected", result: "▶ turns the accent colour: Run will run only the selection."),
                .init(trigger: "⌘↩ or click ▶", result: "Runs the query. The whole capsule turns red (the system's prominent glass) with ■ and the elapsed time."),
                .init(trigger: "Click ■", result: "Cancels the query (⌥⌘. also cancels)."),
                .init(trigger: "Query ends", result: "✓ or ! shows for a moment, then the button settles back to ▶."),
                .init(trigger: "Right-click Run", result: "The other modes: statement at cursor, Explain, Explain analyze (also in the Query menu)."),
                .init(trigger: "Caret in a statement", result: "A faint band on the statement and a Run arrow in the gutter that runs just that statement."),
                .init(trigger: "After a run", result: "Rows and time (or the error) appear at the end of the statement, fading when it is edited."),
                .init(trigger: "First run", result: "The results grow up out of the footer while the editor card shrinks."),
                .init(trigger: "Drag the gap between the cards", result: "Resizes them; a grab capsule shows on hover. Double-click the gap maximises the results, leaving a one-line editor."),
                .init(trigger: "Empty tab", result: "Faint starting points: the last four tables opened on this connection, then snippets. They vanish on typing."),
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
                .init(label: "Fonts bundled", value: "JetBrains Mono, Geist Mono, Google Sans Code, Intel One Mono, Martian Mono, Fragment Mono, Atkinson Hyperlegible Mono, Cascadia Code, Monaspace, Commit Mono",
                      check: "The default font is still to be picked."),
                .init(label: "Gutter styles", value: "Subtle · Tinted column · Tinted lane (setting)"),
                .init(label: "Gutter tint inset (lane)", value: "5pt, rounded, no edge"),
                .init(label: "Validation marker", value: "A red dot on failing lines"),
                .init(label: "Current line", value: "Rounded band inside the card"),
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
        }
    )
}

private struct EditorControls: View {
    @Bindable var state: RunSpecimenState

    private var simulation: LabRunSimulation { state.simulation }

    var body: some View {
        @Bindable var simulation = state.simulation
        HStack(spacing: SpacingTokens.md) {
            Toggle("Text selected", isOn: $state.hasSelection)
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
