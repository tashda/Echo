import SwiftUI
import SQLServerKit

struct NewDatabaseRoleSheet: View {
    let viewModel: DatabaseSecurityViewModel
    let onComplete: () -> Void

    @State private var roleName = ""
    @State private var owner = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !roleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("New Database Role") {
                    PropertyRow(title: "Role Name") {
                        TextField("", text: $roleName, prompt: Text("e.g. app_readonly"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Owner") {
                        TextField("", text: $owner, prompt: Text("e.g. dbo (optional)"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack(spacing: SpacingTokens.sm) {
                if let error = errorMessage {
                    Text(error)
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Status.error)
                        .lineLimit(1)
                }

                Spacer()

                Button("Cancel") { onComplete() }
                    .keyboardShortcut(.cancelAction)

                Button("Create") { Task { await submit() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isFormValid)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, SpacingTokens.md2)
            .padding(.vertical, SpacingTokens.sm2)
            .background(.bar)
        }
        .frame(minWidth: 380, idealWidth: 420, minHeight: 200)
        .navigationTitle("New Database Role")
    }

    private func submit() async {
        let name = roleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        let ownerName = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        await viewModel.createRole(name: name, owner: ownerName.isEmpty ? nil : ownerName)

        if viewModel.roles.contains(where: { $0.name == name }) {
            onComplete()
        } else {
            isSubmitting = false
            errorMessage = "Failed to create role"
        }
    }
}
