import EchoSenseScenarios
import SwiftUI

/// Edits what EchoSense should do, by hand or by dragging: the expected titles in order (drag to
/// reorder, drag suggestions in from the popup on the right), titles it must never offer, insert
/// text, and the shared rules the scenario follows.
struct ScenarioExpectationEditor: View {
    @Binding var scenario: CompletionScenario
    let actual: ScenarioActual?
    var store = ScenarioStore.shared

    @State private var newItem = ""
    @State private var newNever = ""
    @State private var editingRule: ScenarioRule?

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.md) {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                LabReadingCard(title: "What EchoSense should do", symbol: "target") { expectation }
                ScenarioRulesField(scenario: $scenario, store: store, editingRule: $editingRule)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            ScenarioActualColumn(scenario: $scenario, actual: actual)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .sheet(item: $editingRule) { rule in ScenarioRuleEditor(rule: rule, store: store) }
    }

    @ViewBuilder
    private var expectation: some View {
        Picker("", selection: outcome) {
            Text("Not set").tag(Optional<EchoSenseExpectation.Outcome>.none)
            Text("Suggests").tag(Optional(EchoSenseExpectation.Outcome.suggests))
            Text("Nothing").tag(Optional(EchoSenseExpectation.Outcome.nothing))
            Text("Silent while typing").tag(Optional(EchoSenseExpectation.Outcome.silent))
        }
        .pickerStyle(.segmented).labelsHidden()
        switch scenario.echoSense?.outcome {
        case .suggests?: suggests
        case .nothing?: note("Nothing is offered, not even when asked by hand (⌘.).")
        case .silent?: note("Nothing while typing; asking by hand (⌘.) may show something.")
        case nil: note("No expectation yet. Pick Suggests and drag the right suggestions in from the popup.")
        }
        if let actual {
            Button("Use what it does now", systemImage: "equal.circle") { scenario.echoSense = scenario.expectation(matching: actual) }
                .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent))
                .help("The popup's suggestions, in its order, become the expected ones")
        }
    }

    @ViewBuilder
    private var suggests: some View {
        if scenario.popup != nil {
            Label("This scenario's popup is judged by its block rule, not by the titles below. Change the rule in Test › Popup Referee.", systemImage: "flag.checkered")
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.warning)
        }
        Picker("Order", selection: order) {
            Text("These first, in this order").tag(EchoSenseExpectation.Order.leading)
            Text("Exactly these, in this order").tag(EchoSenseExpectation.Order.exact)
            if scenario.echoSense?.order == .includes { Text("In any order (old)").tag(EchoSenseExpectation.Order.includes) }
        }
        .fixedSize()
        section("Expected, in this order", hint: "Drag to reorder. Drag suggestions here from the popup.") {
            let items = scenario.echoSense?.items ?? []
            ForEach(Array(items.enumerated()), id: \.offset) { index, title in
                ScenarioExpectedRow(position: index + 1, title: title, rank: actual?.rank(of: title)) { edit { $0.items.remove(at: index) } }
                    .draggable(ScenarioDragItem.expected(index).text)
                    .dropDestination(for: String.self) { texts, _ in drop(texts, intoExpectedAt: index) }
            }
            ScenarioDropField(prompt: "Add a title, or drop one here", text: $newItem) { add(newItem); newItem = "" }
                .dropDestination(for: String.self) { texts, _ in drop(texts, intoExpectedAt: nil) }
        }
        section("Never offers", hint: "Drop suggestions here that must not appear.") {
            LabFlowLayout {
                ForEach(scenario.echoSense?.excludes ?? [], id: \.self) { title in
                    ScenarioChip(text: title, tint: ColorTokens.Status.error) { edit { $0.excludes.removeAll { $0 == title } } }
                        .draggable(ScenarioDragItem.never(title).text)
                }
            }
            ScenarioDropField(prompt: "Add a title, or drop one here", text: $newNever) { forbid(newNever); newNever = "" }
                .dropDestination(for: String.self) { texts, _ in dropIntoNever(texts) }
        }
        section("Inserts", hint: "What accepting a title writes, where it matters.") {
            ScenarioInsertRows(insertText: Binding(get: { scenario.echoSense?.insertText ?? [:] }, set: { value in edit { $0.insertText = value } }))
        }
    }

    // MARK: Pieces

    private func section<Content: View>(_ title: String, hint: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(TypographyTokens.standard.weight(.semibold))
                Text(hint).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            }
            content()
        }
        .padding(.top, SpacingTokens.xxs)
    }

    private func note(_ text: String) -> some View {
        Text(text).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
    }

    // MARK: Editing

    private var outcome: Binding<EchoSenseExpectation.Outcome?> {
        Binding(get: { scenario.echoSense?.outcome }, set: { new in
            guard let new else { scenario.echoSense = nil; return }
            var value = scenario.echoSense ?? EchoSenseExpectation(outcome: new)
            value.outcome = new
            scenario.echoSense = value
        })
    }

    private var order: Binding<EchoSenseExpectation.Order> {
        Binding(get: { scenario.echoSense?.order ?? .leading }, set: { value in edit { $0.order = value } })
    }

    /// Changes the expectation, making it "suggests" if there was none.
    private func edit(_ change: (inout EchoSenseExpectation) -> Void) {
        var value = scenario.echoSense ?? EchoSenseExpectation(outcome: .suggests)
        change(&value)
        scenario.echoSense = value
    }

    private func add(_ title: String, at index: Int? = nil) {
        let title = CompletionScenarioRunner.unquoted(title.trimmingCharacters(in: .whitespaces))
        guard !title.isEmpty else { return }
        edit { value in
            value.outcome = .suggests
            value.excludes.removeAll { $0 == title }
            if let existing = value.items.firstIndex(of: title) {
                value.items.remove(at: existing)
                let target = index.map { $0 > existing ? $0 - 1 : $0 } ?? value.items.count
                value.items.insert(title, at: min(target, value.items.count))
            } else {
                value.items.insert(title, at: min(index ?? value.items.count, value.items.count))
            }
        }
    }

    private func forbid(_ title: String) {
        let title = CompletionScenarioRunner.unquoted(title.trimmingCharacters(in: .whitespaces))
        guard !title.isEmpty else { return }
        edit { value in
            value.items.removeAll { $0 == title }
            if !value.excludes.contains(title) { value.excludes.append(title) }
        }
    }

    private func drop(_ texts: [String], intoExpectedAt index: Int?) {
        switch ScenarioDragItem.first(in: texts) {
        case .expected(let from)?:
            guard let title = scenario.echoSense?.items[safe: from] else { return }
            add(title, at: index)
        case let item? where item.title != nil:
            add(item.title ?? "", at: index)
        default:
            break
        }
    }

    private func dropIntoNever(_ texts: [String]) {
        switch ScenarioDragItem.first(in: texts) {
        case .expected(let from)?: if let title = scenario.echoSense?.items[safe: from] { forbid(title) }
        case let item? where item.title != nil: forbid(item.title ?? "")
        default: break
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
