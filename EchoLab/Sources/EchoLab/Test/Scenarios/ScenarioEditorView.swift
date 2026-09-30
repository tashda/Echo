import EchoSense
import EchoSenseScenarios
import SwiftUI

/// One scenario, editable: what should happen, the SQL with its caret, the expected result beside the
/// actual one from the real engine, and what Echo's editor should do with it.
struct ScenarioEditorView: View {
    @Binding var scenario: CompletionScenario
    /// Live schemas are used by the playground; scenarios use their built-in schema.
    var runner = CompletionScenarioRunner()
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
                HStack(alignment: .top, spacing: SpacingTokens.md) {
                    expectedCard
                    actualCard
                }
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
                    ForEach(ScenarioReview.allCases, id: \.self) { Text($0 == .approved ? "Approved" : "Imported, not reviewed").tag($0) }
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
            switch result.verdict {
            case .pass:
                banner(known ? "Passes now, but it is listed as a known issue: remove the flag." : "Passes", symbol: "checkmark.circle.fill",
                       tint: known ? ColorTokens.Status.warning : ColorTokens.Status.success, lines: [])
            case .fail(let reasons):
                banner(known ? "Known issue: it fails as noted" : "Fails", symbol: known ? "exclamationmark.triangle.fill" : "xmark.octagon.fill",
                       tint: known ? ColorTokens.Status.warning : ColorTokens.Status.error, lines: reasons + (known ? ["Noted: \(scenario.knownIssue ?? "")"] : []))
            case .unchecked:
                banner("No expected result yet", symbol: "questionmark.circle", tint: ColorTokens.Text.secondary,
                       lines: ["Write what should come back, or press “Use actual as expected” if what the engine does now is right."])
            case .error(let message):
                banner("Could not run", symbol: "exclamationmark.octagon", tint: ColorTokens.Status.error, lines: [message])
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

    // MARK: Expected

    private var expected: EchoSenseExpectation? { scenario.echoSense }

    private var expectedCard: some View {
        card("Expected from EchoSense", symbol: "target") {
            Picker("", selection: outcomeBinding) {
                Text("Not set").tag(Optional<EchoSenseExpectation.Outcome>.none)
                Text("Suggests").tag(Optional(EchoSenseExpectation.Outcome.suggests))
                Text("Nothing").tag(Optional(EchoSenseExpectation.Outcome.nothing))
                Text("Silent").tag(Optional(EchoSenseExpectation.Outcome.silent))
            }.pickerStyle(.segmented).labelsHidden()
            if let outcome = expected?.outcome, outcome == .suggests {
                Picker("Match", selection: binding(\.order)) {
                    Text("Exactly these").tag(EchoSenseExpectation.Order.exact)
                    Text("These first").tag(EchoSenseExpectation.Order.leading)
                    Text("These are in it").tag(EchoSenseExpectation.Order.includes)
                }.controlSize(.small)
                lines("Suggestions, one per line, in order", text: itemsBinding)
                lines("Must not appear", text: excludesBinding, height: 44)
                lines("Insert text, “title = text”", text: insertBinding, height: 44)
            } else if let outcome = expected?.outcome, outcome == .nothing {
                Text("Nothing should be offered, not even by hand.").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            } else if let outcome = expected?.outcome, outcome == .silent {
                Text("Nothing while typing; a manual trigger may show something.").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            }
            Button("Use actual as expected", systemImage: "equal.circle") { useActual() }
                .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent, prominent: false)).disabled(result?.actual == nil)
        }
    }

    private func lines(_ title: String, text: Binding<String>, height: CGFloat = 130) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            TextEditor(text: text).font(.system(size: 12, design: .monospaced)).frame(height: height).scrollContentBackground(.hidden)
                .padding(4).background(ColorTokens.Surface.hover, in: .rect(cornerRadius: 6))
        }
    }

    // MARK: Actual

    private var actualCard: some View {
        card("Actual from EchoSense", symbol: "gearshape.2") {
            if let actual = result?.actual {
                HStack(spacing: SpacingTokens.md) {
                    fact("Clause", actual.clause); fact("Token", actual.token.isEmpty ? "none" : "“\(actual.token)”"); fact("Results", "\(actual.titles.count)")
                }
                if actual.titles.isEmpty {
                    Text("Nothing offered.").font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                    if scenario.trigger == .typing, !actual.manualTitles.isEmpty {
                        Text("By hand (⌘.): \(actual.manualTitles.prefix(10).joined(separator: ", "))\(actual.manualTitles.count > 10 ? " and \(actual.manualTitles.count - 10) more" : "")")
                            .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(actual.titles.prefix(60).enumerated()), id: \.offset) { index, title in
                            HStack(spacing: 8) {
                                Text("\(index + 1)").font(.system(size: 10, design: .monospaced)).foregroundStyle(ColorTokens.Text.tertiary).frame(width: 22, alignment: .trailing)
                                Text(title).font(.system(size: 12, design: .monospaced))
                                Spacer()
                                if let insert = actual.insertText[title], insert != title {
                                    Text("inserts \(insert)").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                                }
                                Text(actual.kinds[title] ?? "").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                            }
                            .background(rowTint(title))
                        }
                        if actual.titles.count > 60 { Text("and \(actual.titles.count - 60) more").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary) }
                    }
                }
            } else {
                Text("Not run.").foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }

    /// Titles the expectation names are tinted green; ones it forbids, red.
    private func rowTint(_ title: String) -> Color {
        if expected?.excludes.contains(title) == true { return ColorTokens.Status.error.opacity(0.14) }
        if expected?.items.contains(title) == true { return ColorTokens.Status.success.opacity(0.12) }
        return .clear
    }

    private func fact(_ name: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(name).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            Text(value).font(TypographyTokens.standard.monospacedDigit())
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
            Label("Echo's editor rules are being moved into EchoSense so they run here too. Until then this is written down but not checked.", systemImage: "info.circle")
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

    private func useActual() {
        guard let actual = result?.actual else { return }
        scenario.echoSense = scenario.expectation(matching: actual)
    }

    private var outcomeBinding: Binding<EchoSenseExpectation.Outcome?> {
        Binding(get: { scenario.echoSense?.outcome }, set: { new in
            guard let new else { scenario.echoSense = nil; return }
            var value = scenario.echoSense ?? EchoSenseExpectation(outcome: new)
            value.outcome = new
            scenario.echoSense = value
        })
    }

    private func binding<T>(_ keyPath: WritableKeyPath<EchoSenseExpectation, T>) -> Binding<T> where T: Sendable {
        Binding(get: { scenario.echoSense![keyPath: keyPath] }, set: { scenario.echoSense?[keyPath: keyPath] = $0 })
    }

    private var itemsBinding: Binding<String> { listBinding(\.items) }
    private var excludesBinding: Binding<String> { listBinding(\.excludes) }

    private func listBinding(_ keyPath: WritableKeyPath<EchoSenseExpectation, [String]>) -> Binding<String> {
        Binding(get: { (scenario.echoSense?[keyPath: keyPath] ?? []).joined(separator: "\n") },
                set: { scenario.echoSense?[keyPath: keyPath] = $0.split(separator: "\n", omittingEmptySubsequences: true).map { $0.trimmingCharacters(in: .whitespaces) } })
    }

    private var insertBinding: Binding<String> {
        Binding(get: { (scenario.echoSense?.insertText ?? [:]).sorted { $0.key < $1.key }.map { "\($0.key) = \($0.value)" }.joined(separator: "\n") },
                set: { text in
                    var map: [String: String] = [:]
                    for line in text.split(separator: "\n") {
                        let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                        if parts.count == 2 { map[parts[0]] = parts[1] }
                    }
                    scenario.echoSense?.insertText = map
                })
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
