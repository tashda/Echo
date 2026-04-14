import SwiftUI
import PostgresKit

struct NewOperatorSheet: View {
    let viewModel: PostgresAdvancedObjectsViewModel
    let onComplete: () -> Void

    @State private var name = ""
    @State private var leftType = ""
    @State private var rightType = ""
    @State private var procedure = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !procedure.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && (!leftType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !rightType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New Operator",
            icon: "plus.forwardslash.minus",
            subtitle: "Create a custom operator with a backing function.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("Operator") {
                    PropertyRow(title: "Name") {
                        TextField("", text: $name, prompt: Text("e.g. ##"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Left Type", info: "The data type of the left operand. Leave empty for a prefix (unary) operator.") {
                        PostgresDataTypePicker(selection: $leftType, prompt: "e.g. integer (optional)")
                    }
                    PropertyRow(title: "Right Type", info: "The data type of the right operand. Leave empty for a postfix operator.") {
                        PostgresDataTypePicker(selection: $rightType, prompt: "e.g. integer")
                    }
                }

                Section("Implementation") {
                    PropertyRow(title: "Procedure", info: "The function that implements this operator. Must accept the operand types and return a result.") {
                        TextField("", text: $procedure, prompt: Text("e.g. my_operator_func"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 320)
    }

    private func submit() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        let left = leftType.trimmingCharacters(in: .whitespacesAndNewlines)
        let right = rightType.trimmingCharacters(in: .whitespacesAndNewlines)

        await viewModel.createOperator(
            name: trimmedName,
            leftType: left.isEmpty ? nil : left,
            rightType: right.isEmpty ? nil : right,
            procedure: procedure.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        if viewModel.operators.contains(where: { $0.name == trimmedName }) {
            onComplete()
        } else {
            isSubmitting = false
            errorMessage = "Failed to create operator"
        }
    }
}
