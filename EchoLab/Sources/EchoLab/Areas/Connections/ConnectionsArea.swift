import SwiftUI

/// Connections as they are in Echo today (plan Phase 13, decisions 2026-09-30).
@MainActor
enum ConnectionsArea {
    static let area = LabArea(
        id: "connections",
        title: "Connections",
        symbol: "externaldrive.connected.to.line.below",
        summary: "One short sheet for Quick Connect and New Connection; editing happens inside Manage Connections.",
        asBuilt: AsBuiltPage(
            verification: .init(
                level: .code, commit: "a24192df", date: "2026-09-30",
                note: "Written from the decision log; the specimen is Round 14's Manage Connections. Not yet compared with the running sheet."),
            stageHeight: 620,
            behaviours: [
                .init(trigger: "Quick Connect", result: "A short sheet: engine, server and port on one line, database, sign in, Keychain. It never asks for a name; it also saves the password in the Keychain."),
                .init(trigger: "New Connection", result: "The same sheet; name, folder and colour appear only while Save to Connections is on."),
                .init(trigger: "Security and timeouts", result: "One disclosure with a one-line summary; it remembers whether it was open."),
                .init(trigger: "Press the default button with fields missing", result: "Never silently disabled: an inline message and focus on the field."),
                .init(trigger: "Change the engine", result: "The port placeholder follows it."),
                .init(trigger: "Paste a connection URL or string", result: "Anywhere in the form; it fills the fields."),
                .init(trigger: "Test", result: "The result shows beside the buttons."),
                .init(trigger: "Edit a connection", result: "In Manage Connections: its detail pane is the editable form; + adds one with the same form."),
            ],
            motions: [
                .init(name: "Security disclosure", curve: "system disclosure", duration: "system"),
            ],
            measurements: [
                .init(label: "Form", value: "Native grouped form"),
                .init(label: "Text fields", value: "Always have a prompt", token: "Form TextField rule"),
                .init(label: "Manage list", value: "320pt minimum", token: "LayoutTokens.ManageConnections.listMinWidth"),
                .init(label: "Editor pane", value: "380pt minimum, 460pt ideal", token: "editorMinWidth / editorIdealWidth"),
            ],
            rules: [
                .init(text: "One short sheet, editing in Manage Connections",
                      why: "Fewer places to learn. Other layouts (CN1, CN3, CN4) were rejected.",
                      rounds: ["ported.Round 14 · connections"]),
                .init(text: "The default button is never silently disabled",
                      why: "A greyed button hides why; an inline message says what is missing."),
                .init(text: "Quick Connect never asks for a name",
                      why: "It is for one-off connections; naming belongs to saving."),
                .init(text: "Quick Connect also saves its password in the Keychain",
                      why: "Rejected the alternative (CR6) of not saving it."),
            ],
            code: [
                "Echo/Sources/Features/Connections/",
                "Packages/EchoDesignSystem/.../LayoutToken+ManageConnections.swift",
            ]
        ) {
            LabRound14ManageConnections()
        },
        spec: ConnectionsSpec.spec(stageHeight: 620) { LabRound14ManageConnections() }
    )
}
