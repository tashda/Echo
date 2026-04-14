import SwiftUI
import PostgresKit

struct NewEventTriggerSheet: View {
    let viewModel: PostgresAdvancedObjectsViewModel
    let onComplete: () -> Void

    @State private var name = ""
    @State private var event = "ddl_command_end"
    @State private var functionName = ""
    @State private var tagsText = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let events = ["ddl_command_start", "ddl_command_end", "table_rewrite", "sql_drop"]

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !functionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New Event Trigger",
            icon: "bolt",
            subtitle: "Create a trigger that fires on DDL events.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("Trigger") {
                    PropertyRow(title: "Name") {
                        TextField("", text: $name, prompt: Text("e.g. audit_ddl_changes"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Event", info: "The DDL event type that triggers this event trigger.") {
                        Picker("", selection: $event) {
                            ForEach(events, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }

                Section("Execution") {
                    PropertyRow(title: "Function", info: "The function to call when the trigger fires. Must return event_trigger.") {
                        TextField("", text: $functionName, prompt: Text("e.g. log_ddl_event"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Tags", info: "Comma-separated DDL command tags to filter on, e.g. CREATE TABLE, DROP INDEX. Leave empty to trigger on all commands.") {
                        TextField("", text: $tagsText, prompt: Text("e.g. CREATE TABLE, DROP TABLE"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 340)
    }

    private func submit() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFunction = functionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedFunction.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        let tags: [String]? = {
            let trimmed = tagsText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }()

        await viewModel.createEventTrigger(name: trimmedName, event: event, function: trimmedFunction, tags: tags)

        if viewModel.eventTriggers.contains(where: { $0.name == trimmedName }) {
            onComplete()
        } else {
            isSubmitting = false
            errorMessage = "Failed to create event trigger"
        }
    }
}
