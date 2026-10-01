import EchoSenseScenarios
import SwiftUI

/// Right-click on a scenario: move it to another area, copy it (to an area or another dialect), and
/// follow or stop following a shared rule. Dragging does the same: onto an area, or a rule onto it.
struct ScenarioRowMenu: View {
    let scenario: CompletionScenario
    let store: ScenarioStore
    let select: (String) -> Void

    var body: some View {
        Menu("Move to area") {
            ForEach(store.groups.filter { $0 != scenario.group }, id: \.self) { group in
                Button(group) { store.move(scenario.id, toArea: group) }
            }
        }
        Menu("Copy to area") {
            ForEach(store.groups, id: \.self) { group in
                Button(group) { if let id = store.duplicate(scenario.id, toArea: group) { select(id) } }
            }
        }
        Menu("Copy for another dialect") {
            ForEach(ScenarioDialect.allCases.filter { $0 != scenario.dialect }, id: \.self) { dialect in
                Button(dialect.title) { if let id = store.duplicate(scenario.id, dialect: dialect) { select(id) } }
            }
        }
        Divider()
        Menu("Rules") {
            ForEach(store.ruleLibrary.rules) { rule in
                Toggle("\(rule.title) (\(rule.id))", isOn: Binding(
                    get: { scenario.rules.contains(rule.id) },
                    set: { store.setFollows(rule.id, $0, scenario: scenario.id) }))
            }
        }
    }
}
