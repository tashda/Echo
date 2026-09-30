import SwiftUI

/// Connections by piece, each with a stable ID (`CON-2.3`).
@MainActor
enum ConnectionsSpec {
    private static let code = "Echo/Sources/Features/Connections/"
    private static let r14 = "ported.Round 14 · connections"

    static func spec<Specimen: View>(stageHeight: CGFloat, @ViewBuilder specimen: @escaping () -> Specimen) -> AreaSpec {
        AreaSpec(code: "CON", stageHeight: stageHeight, parts: parts, specimen: specimen)
    }

    private static let parts: [SpecPart] = [
        SpecPart(number: "1", name: "Sheets", summary: "One short sheet for two jobs.", elements: [
            SpecElement(number: "1.1", name: "Quick Connect", summary: "For a one-off connection.", groups: [
                .layout(.row("Fields", "engine, server and port on one line; database; sign in; Keychain")),
                .behaviour(.row("Name", "never asked"), .row("Password", "also saved in the Keychain (CR6, not saving it, was rejected)")),
            ], rounds: [r14], files: [code]),
            SpecElement(number: "1.2", name: "New Connection", summary: "The same sheet, for a connection to keep.", groups: [
                .behaviour(.row("Name, folder and colour", "appear only while Save to Connections is on")),
            ], rounds: [r14], files: [code]),
        ]),
        SpecPart(number: "2", name: "Form", summary: "A native grouped form.", elements: [
            SpecElement(number: "2.1", name: "Text fields", summary: "Every field has a prompt.", groups: [
                .behaviour(.row("Rule", "a TextField in a grouped Form always has a prompt with a realistic example")),
            ], files: [code]),
            SpecElement(number: "2.2", name: "Engine", summary: "Choosing the engine changes the port's placeholder.", groups: [.behaviour(.row("Change the engine", "the port placeholder follows it"))], files: [code]),
            SpecElement(number: "2.3", name: "Security and timeouts", summary: "One disclosure with a one-line summary.", groups: [
                .behaviour(.row("Open state", "remembered")), .motion(.row("Disclosure", "system disclosure")),
            ], files: [code]),
            SpecElement(number: "2.4", name: "Paste a connection", summary: "A URL or connection string pasted anywhere fills the fields.", groups: [.behaviour(.row("Paste", "anywhere in the form"))], files: [code]),
            SpecElement(number: "2.5", name: "Missing fields", summary: "The default button is never silently disabled.", groups: [
                .behaviour(.row("Press it with fields missing", "an inline message, and focus on the field"), .row("Why", "a greyed button hides why")),
            ], rounds: [r14], files: [code]),
            SpecElement(number: "2.6", name: "Test", summary: "Tries the connection.", groups: [.behaviour(.row("Result", "shows beside the buttons"))], files: [code]),
        ]),
        SpecPart(number: "3", name: "Manage Connections", summary: "Where connections are edited.", elements: [
            SpecElement(number: "3.1", name: "List", summary: "The saved connections.", groups: [
                .layout(.row("Minimum width", "320pt", token: "LayoutTokens.ManageConnections.listMinWidth")),
            ], rounds: [r14], files: ["Packages/EchoDesignSystem/.../LayoutToken+ManageConnections.swift"]),
            SpecElement(number: "3.2", name: "Editor pane", summary: "The selected connection's detail is the editable form.", groups: [
                .layout(.row("Width", "380pt minimum, 460pt ideal", token: "editorMinWidth / editorIdealWidth")),
                .behaviour(.row("+", "adds a connection with the same form"), .row("Why", "editing lives here so the sheet stays short (CN1, CN3, CN4 rejected)")),
            ], rounds: [r14], files: [code]),
        ]),
    ]
}
