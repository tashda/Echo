import SwiftUI
import PostgresKit

struct PostgresNewSchemaSheet: View {
    let viewModel: PostgresDatabaseSecurityViewModel
    let onComplete: () -> Void

    @State private var schemaName = ""
    @State private var owner = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !schemaName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New Schema",
            icon: "rectangle.3.group",
            subtitle: "Create a new schema to organize database objects.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section {
                    PropertyRow(title: "Schema Name") {
                        TextField("", text: $schemaName, prompt: Text("e.g. reporting"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Owner") {
                        TextField("", text: $owner, prompt: Text("e.g. postgres (optional)"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 380, idealWidth: 420, minHeight: 240)
    }

    private func submit() async {
        let name = schemaName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        let ownerTrimmed = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        await viewModel.createSchema(name: name, owner: ownerTrimmed.isEmpty ? nil : ownerTrimmed)

        if viewModel.schemas.contains(where: { $0.name == name }) {
            onComplete()
        } else {
            isSubmitting = false
            errorMessage = "Failed to create schema"
        }
    }
}
