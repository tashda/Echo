import SwiftUI

/// Connections as they are in Echo today (plan Phase 13, decisions 2026-09-30).
@MainActor
enum ConnectionsArea {
    private static let state = ConnectionsSpecimenState()
    static let area = LabArea(
        id: "connections",
        title: "Connections",
        symbol: "externaldrive.connected.to.line.below",
        summary: "One short sheet for Quick Connect and New Connection; editing happens inside Manage Connections.",
        asBuilt: AsBuiltPage(
            verification: .init(
                level: .code, commit: "b1314d73", date: "2026-09-30",
                note: "Read line by line from ConnectionEditorView (+Detail, +DetailSections, +SecuritySection, +TestToolbar, +Support, +Actions), ManageConnectionsView and the ManageConnections tokens. The specimen draws the form itself (a native grouped form with the same rows, in the three presentations); the Manage Connections window is the Round 14 mock and is approximate."),
            stageHeight: 620,
            behaviours: [
                .init(trigger: "Quick Connect (the rail's + menu)", result: "The connection sheet with Save to Connections off: Connect uses the connection once and keeps its password in the Keychain; with it on, the button is Save and Connect."),
                .init(trigger: "New Connection", result: "The same sheet with Save to Connections on: Save, and Save and Connect (the default button)."),
                .init(trigger: "Edit a saved connection", result: "In Manage Connections only: pick it in the list and its form is the editable pane beside the list, with Revert, Connect and Save (the default)."),
                .init(trigger: "Choose an engine", result: "The engine picker is a segmented control (SQL Server, PostgreSQL, MySQL, SQLite). The port follows the engine's default unless you changed it; SQLite swaps Server for Database File with a Choose button and clears the sign-in."),
                .init(trigger: "Paste a connection URL or string into Server", result: "It fills the engine, server, port, database, user and password."),
                .init(trigger: "Sign In method", result: "Manual (mechanism, domain or token, user, password), Identity (pick or create one), or Inherit (from the folder); Windows integrated always uses Manual."),
                .init(trigger: "Security and timeouts", result: "One disclosure, closed at first, that remembers whether you opened it; its right side summarises the values, such as \"Optional · 30 s\" or \"TLS prefer · 30 s\"."),
                .init(trigger: "Press Save or Connect with something missing", result: "The buttons stay enabled. A red line appears under each field that is missing, and the first one takes focus."),
                .init(trigger: "Press Test", result: "It becomes Cancel Test with a spinner and \"Testing\"; then the last result line shows beside the buttons and opens the whole log in a popover."),
                .init(trigger: "Quick Connect password", result: "Connect without saving still writes the password to the Keychain."),
                .init(trigger: "Manage Connections, nothing selected", result: "\"No Connection Selected\" with a New Connection button."),
                .init(trigger: "Double-click a connection in the list", result: "Connects to it."),
                .init(trigger: "Delete", result: "An alert asks \"Are you sure you want to delete …? This action cannot be undone.\""),
            ],
            motions: [
                .init(name: "Security disclosure", curve: "system disclosure", duration: "system"),
                .init(name: "Save to Connections toggle", curve: "system animation", duration: "system", note: "the name, folder and colour rows appear"),
                .init(name: "Colour selection", curve: "ease in-out", duration: "0.15s"),
                .init(name: "Validation lines appear", curve: "default animation", duration: "system"),
            ],
            measurements: [
                .init(label: "Sheet width", value: "520pt", token: "ConnectionEditorView.body"),
                .init(label: "Sheet height", value: "360pt minimum, 520 ideal, 720 maximum", token: "ConnectionEditorView.body"),
                .init(label: "Form", value: "Native grouped form, hidden scroll background", token: ".formStyle(.grouped)"),
                .init(label: "Button row padding", value: "20pt in the sheet, 12pt in the pane", token: "SpacingTokens.md2 / sm"),
                .init(label: "Port field width", value: "32pt", token: "SpacingTokens.xxl"),
                .init(label: "Timeout fields", value: "60pt wide, default 30 s connection and 60 s query"),
                .init(label: "Colour swatches", value: "20pt circles, 5 colours and a colour picker", token: "ConnectionEditorView.colorPalette"),
                .init(label: "Manage Connections window", value: "1100 × 600pt minimum", token: "ManageConnectionsView+Layout"),
                .init(label: "Manage sidebar", value: "240pt minimum, 260 ideal, 400 maximum"),
                .init(label: "List pane", value: "320pt minimum", token: "LayoutTokens.ManageConnections.listMinWidth"),
                .init(label: "Editor pane", value: "380pt minimum, 460pt ideal", token: "LayoutTokens.ManageConnections.editorMinWidth / editorIdealWidth"),
            ],
            rules: [
                .init(text: "One short sheet, editing in Manage Connections",
                      why: "Fewer places to learn. Other layouts (CN1, CN3, CN4) were rejected.",
                      rounds: ["ported.Round 14 · connections"]),
                .init(text: "The default button is never silently disabled",
                      why: "A greyed button hides why; an inline message says what is missing (CR1)."),
                .init(text: "Quick Connect never asks for a name",
                      why: "It is for one-off connections; naming belongs to saving."),
                .init(text: "Quick Connect also saves its password in the Keychain",
                      why: "Design board CR6 rejected not saving it."),
                .init(text: "A pasted URL fills the form (CR3)", why: "Connection strings are how servers are usually shared."),
                .init(text: "The test result is one line by the buttons (CR4)", why: "The full log is one click away instead of a panel."),
            ],
            code: [
                "Echo/Sources/Features/ConnectionVault/Views/ConnectionEditor/",
                "Echo/Sources/Features/ConnectionVault/Views/ManageConnections/",
                "Echo/Sources/Features/AppHost/Views/Navigation/WorkspaceView.swift",
                "Packages/EchoDesignSystem/Sources/EchoDesignSystem/Tokens/LayoutToken+ManageConnections.swift",
            ]
        ) {
            ConnectionsSpecimen(state: state)
        }
        .controls { ConnectionsSpecimenControls(state: state) },
        spec: ConnectionsSpec.spec(stageHeight: 640, specimen: { ConnectionsSpecimen(state: state) }, controls: { ConnectionsSpecimenControls(state: state) }).onState { state.force($0) }
    )
}
