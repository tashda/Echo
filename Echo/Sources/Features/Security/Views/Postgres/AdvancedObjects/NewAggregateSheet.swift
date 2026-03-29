import SwiftUI
import PostgresKit

struct NewAggregateSheet: View {
    let viewModel: PostgresAdvancedObjectsViewModel
    let onComplete: () -> Void

    @State private var name = ""
    @State private var inputType = "integer"
    @State private var stateFunction = ""
    @State private var stateType = "integer"
    @State private var initialValue = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !stateFunction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !stateType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !inputType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New Aggregate",
            icon: "sum",
            subtitle: "Create a custom aggregate function.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("Aggregate") {
                    PropertyRow(title: "Name") {
                        TextField("", text: $name, prompt: Text("e.g. my_sum"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Input Type", info: "The data type of the aggregate function's input argument.") {
                        PostgresDataTypePicker(selection: $inputType, prompt: "e.g. integer")
                    }
                }

                Section("State") {
                    PropertyRow(title: "State Function", info: "The function called for each input row. Must accept (state_type, input_type) and return state_type.") {
                        TextField("", text: $stateFunction, prompt: Text("e.g. int4pl"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "State Type", info: "The data type of the aggregate's internal state value.") {
                        PostgresDataTypePicker(selection: $stateType, prompt: "e.g. integer")
                    }
                    PropertyRow(title: "Initial Value", info: "The starting value for the aggregate state. If omitted, the state starts as NULL.") {
                        TextField("", text: $initialValue, prompt: Text("e.g. 0"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 380)
    }

    private func submit() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        let initCond = initialValue.trimmingCharacters(in: .whitespacesAndNewlines)

        await viewModel.createAggregate(
            name: trimmedName,
            inputType: inputType.trimmingCharacters(in: .whitespacesAndNewlines),
            sfunc: stateFunction.trimmingCharacters(in: .whitespacesAndNewlines),
            stype: stateType.trimmingCharacters(in: .whitespacesAndNewlines),
            initcond: initCond.isEmpty ? nil : initCond
        )

        if viewModel.aggregates.contains(where: { $0.name == trimmedName }) {
            onComplete()
        } else {
            isSubmitting = false
            errorMessage = "Failed to create aggregate"
        }
    }
}
