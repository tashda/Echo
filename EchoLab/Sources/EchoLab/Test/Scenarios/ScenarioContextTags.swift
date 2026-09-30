import EchoSenseScenarios
import SwiftUI

/// Every setting the scenario runs with, always visible as tags: dialect, schema, trigger, system
/// schemas, qualified inserts. Each tag is a menu; picking another value tries it without saving,
/// and a tag that differs from the saved scenario is tinted.
struct ScenarioContextTags: View {
    let saved: CompletionScenario
    @Binding var shown: CompletionScenario

    var body: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            tag("Dialect", shown.dialect.title, changed: shown.dialect != saved.dialect) {
                Picker("Dialect", selection: $shown.dialect) {
                    ForEach(ScenarioDialect.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            }
            tag("Schema", shown.schema, changed: shown.schema != saved.schema) {
                Picker("Schema", selection: $shown.schema) { ForEach(ScenarioSchemas.ids, id: \.self) { Text($0).tag($0) } }
            }
            tag("Trigger", shown.trigger == .typing ? "While typing" : "By hand (⌘.)", changed: shown.trigger != saved.trigger) {
                Picker("Trigger", selection: $shown.trigger) {
                    Text("While typing").tag(ScenarioTrigger.typing)
                    Text("By hand (⌘.)").tag(ScenarioTrigger.manual)
                }
            }
            tag("System schemas", shown.options.includeSystemSchemas ? "On" : "Off",
                changed: shown.options.includeSystemSchemas != saved.options.includeSystemSchemas) {
                Toggle("Include system schemas", isOn: $shown.options.includeSystemSchemas)
            }
            tag("Qualify inserts", shown.options.qualifyTableInsertions ? "On" : "Off",
                changed: shown.options.qualifyTableInsertions != saved.options.qualifyTableInsertions) {
                Toggle("Qualify table inserts", isOn: $shown.options.qualifyTableInsertions)
            }
        }
    }

    private func tag<Items: View>(_ name: String, _ value: String, changed: Bool, @ViewBuilder items: () -> Items) -> some View {
        Menu {
            items().pickerStyle(.inline)
        } label: {
            HStack(spacing: SpacingTokens.xxs) {
                Text(name).foregroundStyle(ColorTokens.Text.secondary)
                Text(value).foregroundStyle(changed ? ColorTokens.accent : ColorTokens.Text.primary).fontWeight(.medium)
            }
            .font(TypographyTokens.detail)
        }
        .menuStyle(.button)
        .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent, isOn: changed))
        .fixedSize()
        .help(changed ? "Trying \(value); the saved scenario says otherwise" : "\(name): \(value). Pick another value to try it without saving.")
    }
}
