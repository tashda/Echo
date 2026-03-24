import SwiftUI
import SQLServerKit

struct NewAppRoleSheet: View {
    let viewModel: DatabaseSecurityViewModel
    let onComplete: () -> Void

    @State private var roleName = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var defaultSchema = "dbo"
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        let name = roleName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && !password.isEmpty && password == confirmPassword && !isSubmitting
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("New Application Role") {
                    PropertyRow(title: "Role Name") {
                        TextField("", text: $roleName, prompt: Text("e.g. web_app_role"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Default Schema") {
                        TextField("", text: $defaultSchema, prompt: Text("e.g. dbo"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Authentication") {
                    PropertyRow(title: "Password") {
                        SecureField("", text: $password, prompt: Text("Required"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Confirm Password") {
                        SecureField("", text: $confirmPassword, prompt: Text("Re-enter password"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }

                    if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                        Text("Passwords do not match")
                            .font(TypographyTokens.formDescription)
                            .foregroundStyle(ColorTokens.Status.error)
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
        .frame(minWidth: 420, idealWidth: 460, minHeight: 320)
        .navigationTitle("New Application Role")
    }

    private func submit() async {
        let name = roleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !password.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        let schema = defaultSchema.trimmingCharacters(in: .whitespacesAndNewlines)
        await viewModel.createAppRole(name: name, password: password, defaultSchema: schema.isEmpty ? nil : schema)

        if viewModel.appRoles.contains(where: { $0.name == name }) {
            onComplete()
        } else {
            isSubmitting = false
            errorMessage = "Failed to create application role"
        }
    }
}
