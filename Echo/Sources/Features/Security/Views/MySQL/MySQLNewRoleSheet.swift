import MySQLKit
import SwiftUI

struct MySQLNewRoleSheet: View {
    let viewModel: MySQLDatabaseSecurityViewModel
    let onComplete: () -> Void

    @State private var roleName = ""
    @State private var host = "%"
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !roleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New MySQL Role",
            icon: "person.2.badge.plus",
            subtitle: "Create a reusable MySQL role for grants and role assignments.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: onComplete
        ) {
            Form {
                Section {
                    PropertyRow(title: "Role Name") {
                        TextField("", text: $roleName, prompt: Text("e.g. app_readonly"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Host") {
                        TextField("", text: $host, prompt: Text("e.g. %"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 380, idealWidth: 420, minHeight: 220)
    }

    private func submit() async {
        let trimmedName = roleName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedHost.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        await viewModel.createRole(name: trimmedName, host: trimmedHost)

        if viewModel.roles.contains(where: { $0.name == trimmedName && $0.host == trimmedHost }) {
            onComplete()
        } else {
            isSubmitting = false
            errorMessage = "Failed to create MySQL role"
        }
    }
}
