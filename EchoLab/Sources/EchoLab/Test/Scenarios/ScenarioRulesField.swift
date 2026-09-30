import EchoSenseScenarios
import SwiftUI

/// The shared rules a scenario follows: follow one from the list (or drop it here from the left
/// column), open one to change it for every scenario, or turn this scenario's "never offers" into a
/// new rule other scenarios can follow too.
struct ScenarioRulesField: View {
    @Binding var scenario: CompletionScenario
    let store: ScenarioStore
    @Binding var editingRule: ScenarioRule?

    var body: some View {
        LabReadingCard(title: "Shared rules", symbol: "link") {
            Text("A rule holds wherever it is followed, in any area. Changing it changes every scenario that follows it.")
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).fixedSize(horizontal: false, vertical: true)
            if scenario.rules.isEmpty {
                Text("Follows no rules.").font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.tertiary)
            }
            ForEach(scenario.rules, id: \.self) { id in ruleRow(id) }
            HStack(spacing: SpacingTokens.xs) {
                Menu("Follow a rule", systemImage: "plus") {
                    ForEach(store.ruleLibrary.rules.filter { !scenario.rules.contains($0.id) }) { rule in
                        Button("\(rule.title) (\(rule.id), \(store.scenarios(following: rule.id).count) scenarios)") { scenario.rules.append(rule.id) }
                    }
                    Divider()
                    Button("New rule") {
                        let rule = store.addRule(title: "New rule")
                        scenario.rules.append(rule.id)
                        editingRule = rule
                    }
                }
                .fixedSize()
                if let excludes = scenario.echoSense?.excludes, !excludes.isEmpty {
                    Button("Make “never offers” a rule", systemImage: "arrow.up.forward.square") { makeRule(from: excludes) }
                        .buttonStyle(LabPillButtonStyle())
                        .help("Moves \(excludes.joined(separator: ", ")) into a new shared rule this scenario follows, so other scenarios can follow it too")
                }
            }
            .dropDestination(for: String.self) { texts, _ in
                if case .rule(let id)? = ScenarioDragItem.first(in: texts), !scenario.rules.contains(id) { scenario.rules.append(id) }
            }
        }
    }

    private func ruleRow(_ id: String) -> some View {
        let rule = store.rule(id: id)
        let others = store.scenarios(following: id).filter { $0.id != scenario.id }
        let areas = Set(others.map(\.group)).count
        return HStack(spacing: SpacingTokens.xs) {
            Image(systemName: rule == nil ? "exclamationmark.triangle" : "link").foregroundStyle(rule == nil ? ColorTokens.Status.warning : ColorTokens.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(rule?.title ?? "\(id) doesn't exist").font(TypographyTokens.standard.weight(.medium))
                Text("\(id) · also followed by \(others.count) scenario\(others.count == 1 ? "" : "s") in \(areas) area\(areas == 1 ? "" : "s")")
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            }
            Spacer()
            if let rule { Button("Open") { editingRule = rule }.buttonStyle(LabPillButtonStyle()) }
            Button("Stop following", systemImage: "xmark") { scenario.rules.removeAll { $0 == id } }
                .labelStyle(.iconOnly).buttonStyle(.borderless)
        }
        .padding(SpacingTokens.xs).labField(cornerRadius: 8)
    }

    private func makeRule(from excludes: [String]) {
        let rule = store.addRule(title: "Never offers \(excludes.prefix(3).joined(separator: ", "))", excludes: excludes)
        scenario.echoSense?.excludes = []
        scenario.rules.append(rule.id)
        editingRule = rule
    }
}
