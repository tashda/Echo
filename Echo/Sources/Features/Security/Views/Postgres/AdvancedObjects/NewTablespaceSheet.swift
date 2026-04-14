import SwiftUI
import PostgresKit

struct NewTablespaceSheet: View {
    let viewModel: PostgresAdvancedObjectsViewModel
    let onComplete: () -> Void

    @State private var name = ""
    @State private var location = ""
    @State private var owner = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New Tablespace",
            icon: "externaldrive",
            subtitle: "Create a storage location for database objects.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("Tablespace") {
                    PropertyRow(title: "Name") {
                        TextField("", text: $name, prompt: Text("e.g. fast_storage"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Location", info: "The absolute filesystem path on the server where tablespace data will be stored. Must be an existing empty directory owned by the PostgreSQL user.") {
                        TextField("", text: $location, prompt: Text("e.g. /mnt/ssd/pgdata"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Owner", info: "The role that will own this tablespace. Leave empty to use the current user.") {
                        TextField("", text: $owner, prompt: Text("e.g. postgres (blank = current user)"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 280)
    }

    private func submit() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedLocation.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        let ownerVal = owner.trimmingCharacters(in: .whitespacesAndNewlines)

        await viewModel.createTablespace(
            name: trimmedName,
            location: trimmedLocation,
            owner: ownerVal.isEmpty ? nil : ownerVal
        )

        if viewModel.tablespaces.contains(where: { $0.name == trimmedName }) {
            onComplete()
        } else {
            isSubmitting = false
            errorMessage = "Failed to create tablespace"
        }
    }
}
