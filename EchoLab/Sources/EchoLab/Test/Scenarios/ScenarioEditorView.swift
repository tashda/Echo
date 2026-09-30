import EchoSense
import EchoSenseScenarios
import SwiftUI

/// One scenario, editable: what should happen, the SQL with its caret, the expected result beside the
/// actual one from the real engine, and what Echo's editor should do with it.
struct ScenarioEditorView: View {
    @Binding var scenario: CompletionScenario
    /// Live schemas are used by the playground; scenarios use their built-in schema.
    var runner = ScenarioStore.shared.runner
    var onChange: () -> Void = {}

    @State private var text = ""
    @State private var caret = 0
    @State private var result: ScenarioResult?
    @State private var loadedID = ""
    /// True while a scenario is being put into the editor, so that is not written back as an edit.
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                header
                verdictBanner
                shouldField
                sqlField
                ScenarioExpectationEditor(scenario: $scenario, actual: result?.actual)
                echoCard
                actions
            }
            .padding(SpacingTokens.md)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: load)
        .onChange(of: scenario.id) { _, _ in load() }
        .onChange(of: text) { _, _ in commitSQL() }
        .onChange(of: caret) { _, _ in commitSQL() }
        .onChange(of: scenario) { _, _ in recompute() }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(spacing: 8) {
                Text(scenario.id).font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 7).frame(height: 22).background(ColorTokens.Surface.hover, in: .rect(cornerRadius: 6))
                Text(scenario.group).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                if let source = scenario.source { LabTag(text: source, symbol: "doc.text") }
                Spacer()
                Picker("", selection: $scenario.review) {
                    ForEach(ScenarioReview.allCases, id: \.self) { Text($0.title).tag($0) }
                }.labelsHidden().fixedSize()
            }
            TextField("", text: $scenario.title, prompt: Text("Scenario title")).textFieldStyle(.plain)
                .font(.system(size: 22, weight: .bold))
            HStack(spacing: SpacingTokens.sm) {
                Picker("Dialect", selection: $scenario.dialect) { ForEach(ScenarioDialect.allCases, id: \.self) { Text($0.title).tag($0) } }.fixedSize()
                Picker("Schema", selection: $scenario.schema) { ForEach(ScenarioSchemas.ids, id: \.self) { Text($0).tag($0) } }.fixedSize()
                    .disabled(runner.liveStructure != nil)
                Picker("Trigger", selection: $scenario.trigger) {
                    Text("Typing").tag(ScenarioTrigger.typing); Text("Manual (⌘.)").tag(ScenarioTrigger.manual)
                }.fixedSize()
                Toggle("System schemas", isOn: $scenario.options.includeSystemSchemas)
                Toggle("Qualify inserts", isOn: $scenario.options.qualifyTableInsertions)
                Spacer()
            }.controlSize(.small)
        }
    }

    @ViewBuilder
    private var verdictBanner: some View {
        if let result {
            let known = scenario.knownIssue != nil
            if result.isFailing {
                banner(known ? "Known issue: it fails as noted" : "Fails", symbol: known ? "exclamationmark.triangle.fill" : "xmark.octagon.fill",
                       tint: known ? ColorTokens.Status.warning : ColorTokens.Status.error, lines: result.failureReasons + (known ? ["Noted: \(scenario.knownIssue ?? "")"] : []))
            } else if result.isPass {
                banner(known ? "Passes now, but it is listed as a known issue: remove the flag." : "Passes", symbol: "checkmark.circle.fill",
                       tint: known ? ColorTokens.Status.warning : ColorTokens.Status.success, lines: [])
            } else {
                banner("No expected result yet", symbol: "questionmark.circle", tint: ColorTokens.Text.secondary,
                       lines: ["Write what should come back, or press “Use actual as expected” if what the engine does now is right."])
            }
        }
    }

    private func banner(_ title: String, symbol: String, tint: Color, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(TypographyTokens.standard.weight(.semibold)).foregroundStyle(tint)
            ForEach(lines, id: \.self) { Text($0).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).textSelection(.enabled) }
        }
        .padding(SpacingTokens.sm).frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10), in: .rect(cornerRadius: 10))
    }

    // MARK: Should and SQL

    private var shouldField: some View {
        card("What should happen", symbol: "text.alignleft") {
            TextEditor(text: $scenario.should).font(TypographyTokens.standard).frame(minHeight: 60).scrollContentBackground(.hidden)
        }
    }

    private var sqlField: some View {
        card("SQL, with the caret where completion happens", symbol: "chevron.left.forwardslash.chevron.right") {
            LabCaretTextView(text: $text, caret: $caret).frame(height: 140)
                .clipShape(.rect(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
            Text("Caret at \(caret). The file stores it as “\(scenario.caretMarker)”.").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
        }
    }

    // MARK: Echo

    private var echoCard: some View {
        card("Expected from Echo's editor", symbol: "macwindow") {
            HStack(spacing: SpacingTokens.md) {
                Picker("Popup", selection: echoBinding(\.popup)) {
                    Text("Not set").tag(Optional<EchoExpectation.Popup>.none)
                    Text("Shown").tag(Optional(EchoExpectation.Popup.shown)); Text("Hidden").tag(Optional(EchoExpectation.Popup.hidden))
                }.fixedSize()
                TextField("", text: echoTextBinding(\.selected), prompt: Text("Selected suggestion")).textFieldStyle(.roundedBorder)
                TextField("", text: echoTextBinding(\.ghostText), prompt: Text("Ghost text")).textFieldStyle(.roundedBorder)
            }
            TextField("", text: echoTextBinding(\.textAfterAccepting), prompt: Text("Text after accepting the selected suggestion, with | for the caret"), axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(1...3)
            Label("Checked: whether the popup opens, the selected suggestion, and the text after accepting it (the rules are EchoSense's, shared with Echo's editor). Ghost text and suppression after accepting are written down but not checked yet.", systemImage: "info.circle")
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
        }
    }

    // MARK: Actions

    private var actions: some View {
        card("Status", symbol: "flag") {
            HStack(spacing: SpacingTokens.sm) {
                Toggle("Known issue", isOn: Binding(
                    get: { scenario.knownIssue != nil },
                    set: { scenario.knownIssue = $0 ? (scenario.knownIssue ?? "Fails today") : nil; onChange() }))
                if scenario.knownIssue != nil {
                    TextField("", text: Binding(get: { scenario.knownIssue ?? "" }, set: { scenario.knownIssue = $0; onChange() }), prompt: Text("Why it fails, or the ticket"))
                        .textFieldStyle(.roundedBorder)
                }
            }
            TextField("", text: Binding(get: { scenario.notes ?? "" }, set: { scenario.notes = $0.isEmpty ? nil : $0; onChange() }), prompt: Text("Notes"), axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(1...4)
        }
    }

    // MARK: Helpers

    private func card<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Label(title.uppercased(), systemImage: symbol).font(.system(size: 10, weight: .semibold)).foregroundStyle(ColorTokens.Text.secondary)
            content()
        }
        .padding(SpacingTokens.sm).frame(maxWidth: .infinity, alignment: .topLeading).labCard(cornerRadius: 12)
    }

    private func load() {
        guard loadedID != scenario.id else { return }
        loadedID = scenario.id
        let split = scenario.textAndCaret
        isLoading = true
        text = split.text
        caret = split.caret
        recompute()
        Task { @MainActor in isLoading = false }
    }

    /// Writes the editor's text back into the scenario with the caret marker in place.
    private func commitSQL() {
        guard loadedID == scenario.id, !isLoading else { return }
        let ns = text as NSString
        let location = max(0, min(caret, ns.length))
        let sql = ns.substring(to: location) + scenario.caretMarker + ns.substring(from: location)
        if sql != scenario.sql { scenario.sql = sql }
    }

    private func recompute() {
        result = runner.run(scenario)
        onChange()
    }

    private func echoBinding<T>(_ keyPath: WritableKeyPath<EchoExpectation, T?>) -> Binding<T?> {
        Binding(get: { scenario.echo?[keyPath: keyPath] }, set: { new in
            var value = scenario.echo ?? EchoExpectation()
            value[keyPath: keyPath] = new
            scenario.echo = value
        })
    }

    private func echoTextBinding(_ keyPath: WritableKeyPath<EchoExpectation, String?>) -> Binding<String> {
        Binding(get: { scenario.echo?[keyPath: keyPath] ?? "" }, set: { new in
            var value = scenario.echo ?? EchoExpectation()
            value[keyPath: keyPath] = new.isEmpty ? nil : new
            scenario.echo = value
        })
    }
}
