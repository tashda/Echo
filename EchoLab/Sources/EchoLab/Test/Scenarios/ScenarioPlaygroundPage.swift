import EchoSense
import EchoSenseScenarios
import SwiftUI

/// Test › Try SQL: write a query against a sample or live schema, see what EchoSense does at the
/// caret next to what you expect, and save it as a scenario when it isn't what you want.
struct ScenarioPlaygroundPage: View {
    @State private var draft = ScenarioPlaygroundPage.blank()
    @State private var session = LabLiveSession.shared
    @AppStorage("lab.playground.live") private var useLive = false
    @State private var group = "My scenarios"
    @State private var saved: String?

    private static func blank() -> CompletionScenario {
        CompletionScenario(id: "DRAFT", group: "My scenarios", title: "Try SQL", should: "", sql: "SELECT * FROM |", review: .approved)
    }

    private var live: EchoSenseDatabaseStructure? {
        guard useLive, let connection = session.connection, connection.state == .connected else { return nil }
        return connection.structure
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: SpacingTokens.md) {
                Picker("Schema", selection: $useLive) {
                    Text("Sample: \(draft.schema)").tag(false)
                    Text(session.connection.map { "Live: \($0.profile.name)" } ?? "Live (connect on Test › Connections first)").tag(true)
                }.fixedSize().disabled(session.connection?.structure == nil && !useLive)
                if useLive, live == nil {
                    Text("No live schema loaded: connect and load one on the Connections page.").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.warning)
                }
                Spacer()
                TextField("", text: $group, prompt: Text("Group")).textFieldStyle(.roundedBorder).frame(width: 160)
                Button("Save as scenario", systemImage: "square.and.arrow.down") { save() }
                    .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent, prominent: true))
                if let saved { Label("Saved as \(saved)", systemImage: "checkmark").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.success) }
            }
            .padding(SpacingTokens.sm)
            Divider()
            ScenarioEditorView(scenario: $draft, runner: CompletionScenarioRunner(liveStructure: live))
        }
    }

    private func save() {
        let store = ScenarioStore.shared
        var scenario = draft
        scenario.id = store.nextID(prefix: "MINE")
        scenario.group = group.isEmpty ? "My scenarios" : group
        if scenario.title == "Try SQL" || scenario.title.isEmpty { scenario.title = String(scenario.sql.replacingOccurrences(of: "\n", with: " ").prefix(60)) }
        if let connection = session.connection, live != nil {
            scenario.notes = ((scenario.notes.map { $0 + "\n" }) ?? "") + "Written against the live server \(connection.profile.name); it replays on the \(scenario.schema) schema."
        }
        store.update(scenario)
        saved = scenario.id
    }
}
