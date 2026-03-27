import SwiftUI
import PostgresKit

struct NewDomainSheet: View {
    let viewModel: PostgresAdvancedObjectsViewModel
    let onComplete: () -> Void

    @State private var name = ""
    @State private var schema = "public"
    @State private var dataType = ""
    @State private var defaultValue = ""
    @State private var notNull = false
    @State private var checkExpression = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !dataType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New Domain",
            icon: "textformat.abc",
            subtitle: "Create a data type with optional constraints.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("Domain") {
                    PropertyRow(title: "Name") {
                        TextField("", text: $name, prompt: Text("e.g. email_address"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Schema") {
                        Picker("", selection: $schema) {
                            ForEach(viewModel.availableSchemas, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    PropertyRow(title: "Data Type", info: "The underlying PostgreSQL data type that this domain is based on.") {
                        PostgresDataTypePicker(selection: $dataType, prompt: "e.g. varchar(255)")
                    }
                }

                Section("Constraints") {
                    PropertyRow(title: "Default", info: "The default value for columns using this domain. Must be a valid expression for the data type.") {
                        TextField("", text: $defaultValue, prompt: Text("e.g. 'unknown'"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "NOT NULL", info: "When enabled, columns using this domain cannot contain NULL values.") {
                        Toggle("", isOn: $notNull)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    PropertyRow(title: "CHECK Expression", info: "A CHECK constraint expression that must evaluate to true. Use VALUE to refer to the domain value being tested.") {
                        TextField("", text: $checkExpression, prompt: Text("e.g. VALUE ~ '^.+@.+$'"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 400)
    }

    private func submit() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedType = dataType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedType.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        let defVal = defaultValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let checkExpr = checkExpression.trimmingCharacters(in: .whitespacesAndNewlines)

        await viewModel.createDomain(
            name: trimmedName,
            schema: schema,
            dataType: trimmedType,
            defaultValue: defVal.isEmpty ? nil : defVal,
            notNull: notNull,
            checkExpression: checkExpr.isEmpty ? nil : checkExpr
        )

        if viewModel.domains.contains(where: { $0.name == trimmedName }) {
            onComplete()
        } else {
            isSubmitting = false
            errorMessage = "Failed to create domain"
        }
    }
}
