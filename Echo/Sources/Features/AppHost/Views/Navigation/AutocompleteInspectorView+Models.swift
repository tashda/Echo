import SwiftUI

struct RuleDefinitionRow: View {
    let definition: SQLAutocompleteRuleDefinition
    @State private var notes: String = ""

    init(definition: SQLAutocompleteRuleDefinition) {
        self.definition = definition
        _notes = State(initialValue: UserDefaults.standard.string(forKey: definition.storageKey) ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(definition.title)
                .font(.subheadline.weight(.semibold))
            Text(definition.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField("Add notes\u{2026}", text: $notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3, reservesSpace: true)
        }
        .onChange(of: notes) {
            UserDefaults.standard.set(notes, forKey: definition.storageKey)
        }
    }
}

struct SQLAutocompleteRuleDefinition: Identifiable {
    let id: String
    let title: String
    let summary: String
    let storageKey: String
}

extension SQLAutocompleteRuleDefinition {
    static let core: [SQLAutocompleteRuleDefinition] = [
        SQLAutocompleteRuleDefinition(
            id: "suppression-gate",
            title: "Suppression Gate",
            summary: "Determines when completions should stay hidden because the user already accepted an object and no additional follow-ups are available.",
            storageKey: "autocomplete.rule.suppression"
        ),
        SQLAutocompleteRuleDefinition(
            id: "column-follow-ups",
            title: "Column Follow-Ups",
            summary: "Inspects engine results and structure metadata to confirm whether columns or alternative objects justify reopening suggestions.",
            storageKey: "autocomplete.rule.columns"
        ),
        SQLAutocompleteRuleDefinition(
            id: "structure-fallback",
            title: "Structure Fallback",
            summary: "Falls back to database structure when the completion engine returns no direct match so users can reveal schema-driven suggestions with \u{2318}.",
            storageKey: "autocomplete.rule.structure"
        )
    ]
}
