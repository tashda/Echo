import SwiftUI
import PostgresKit

struct NewRangeTypeSheet: View {
    let viewModel: PostgresAdvancedObjectsViewModel
    let onComplete: () -> Void

    @State private var name = ""
    @State private var schema = "public"
    @State private var subtype = ""
    @State private var opClass = ""
    @State private var collation = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !subtype.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New Range Type",
            icon: "arrow.left.and.right",
            subtitle: "Create a range type over an existing data type.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("Range Type") {
                    PropertyRow(title: "Name") {
                        TextField("", text: $name, prompt: Text("e.g. float8_range"))
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
                    PropertyRow(title: "Subtype", info: "The element data type that this range contains, e.g. integer, timestamp, numeric.") {
                        PostgresDataTypePicker(selection: $subtype, prompt: "e.g. float8")
                    }
                }

                Section("Options") {
                    PropertyRow(title: "Operator Class", info: "The B-tree operator class for the subtype. Leave empty to use the default operator class.") {
                        TextField("", text: $opClass, prompt: Text("e.g. float8_ops"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Collation", info: "The collation to use for the range. Only relevant for collatable subtypes like text.") {
                        TextField("", text: $collation, prompt: Text("e.g. en_US"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 360)
    }

    private func submit() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubtype = subtype.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedSubtype.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        let opVal = opClass.trimmingCharacters(in: .whitespacesAndNewlines)
        let colVal = collation.trimmingCharacters(in: .whitespacesAndNewlines)

        await viewModel.createRangeType(
            name: trimmedName,
            schema: schema,
            subtype: trimmedSubtype,
            opClass: opVal.isEmpty ? nil : opVal,
            collation: colVal.isEmpty ? nil : colVal
        )

        if viewModel.rangeTypes.contains(where: { $0.name == trimmedName }) {
            onComplete()
        } else {
            isSubmitting = false
            errorMessage = "Failed to create range type"
        }
    }
}
