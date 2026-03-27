import SwiftUI
import PostgresKit

struct NewRuleSheet: View {
    let viewModel: PostgresAdvancedObjectsViewModel
    let onComplete: () -> Void

    @State private var name = ""
    @State private var ruleSchema = "public"
    @State private var selectedTable = ""
    @State private var availableTables: [String] = []
    @State private var event = "SELECT"
    @State private var doInstead = false
    @State private var condition = ""
    @State private var commands = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let events = ["SELECT", "INSERT", "UPDATE", "DELETE"]

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !selectedTable.isEmpty
        && !commands.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New Rule",
            icon: "list.bullet.rectangle",
            subtitle: "Create a query rewrite rule on a table.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("Rule") {
                    PropertyRow(title: "Name") {
                        TextField("", text: $name, prompt: Text("e.g. prevent_delete"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Schema") {
                        Picker("", selection: $ruleSchema) {
                            ForEach(viewModel.availableSchemas, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    PropertyRow(title: "Table", info: "The table that this rule applies to.") {
                        Picker("", selection: $selectedTable) {
                            Text("Select a table…").tag("")
                            ForEach(availableTables, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    PropertyRow(title: "Event", info: "The SQL command type that triggers this rule.") {
                        Picker("", selection: $event) {
                            ForEach(events, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    PropertyRow(title: "DO INSTEAD", info: "When enabled, the rule's commands replace the original command. When disabled, they execute in addition to it.") {
                        Toggle("", isOn: $doInstead)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }

                Section("Action") {
                    PropertyRow(title: "Condition", info: "An optional WHERE clause condition. The rule only fires when this condition is true.") {
                        TextField("", text: $condition, prompt: Text("e.g. old.status = 'active'"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Commands", info: "The SQL commands to execute when the rule fires. Use NOTHING for a do-nothing rule.") {
                        TextField("", text: $commands, prompt: Text("e.g. NOTHING"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 420)
        .task { await loadTables(schema: ruleSchema) }
        .onChange(of: ruleSchema) { _, newSchema in
            selectedTable = ""
            Task { await loadTables(schema: newSchema) }
        }
    }

    private func submit() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCommands = commands.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !selectedTable.isEmpty, !trimmedCommands.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        let cond = condition.trimmingCharacters(in: .whitespacesAndNewlines)

        await viewModel.createRule(
            name: trimmedName,
            table: selectedTable,
            schema: ruleSchema,
            event: event,
            doInstead: doInstead,
            condition: cond.isEmpty ? nil : cond,
            commands: trimmedCommands
        )

        if viewModel.rules.contains(where: { $0.name == trimmedName }) {
            onComplete()
        } else {
            isSubmitting = false
            errorMessage = "Failed to create rule"
        }
    }

    private func loadTables(schema: String) async {
        guard let pg = viewModel.session as? PostgresSession else { return }
        do {
            let objects = try await pg.client.introspection.listTablesAndViews(schema: schema)
            availableTables = objects.filter { $0.kind == .table }.map(\.name).sorted()
        } catch {
            availableTables = []
        }
    }
}
