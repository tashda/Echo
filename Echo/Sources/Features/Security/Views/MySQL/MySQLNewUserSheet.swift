import MySQLKit
import SwiftUI

struct MySQLNewUserSheet: View {
    let viewModel: MySQLDatabaseSecurityViewModel
    let onComplete: () -> Void

    @State private var username = ""
    @State private var host = "%"
    @State private var password = ""
    @State private var plugin = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New MySQL User",
            icon: "person.badge.plus",
            subtitle: "Create a new MySQL account using the same workflow as the other database security tabs.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: onComplete
        ) {
            Form {
                Section {
                    PropertyRow(title: "Username") {
                        TextField("", text: $username, prompt: Text("e.g. app_user"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Host") {
                        TextField("", text: $host, prompt: Text("e.g. %"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Password") {
                        SecureField("", text: $password, prompt: Text("optional initial password"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Plugin") {
                        TextField("", text: $plugin, prompt: Text("e.g. caching_sha2_password"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 260)
    }

    private func submit() async {
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUser.isEmpty, !trimmedHost.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlugin = plugin.trimmingCharacters(in: .whitespacesAndNewlines)
        await viewModel.createUser(
            username: trimmedUser,
            host: trimmedHost,
            password: trimmedPassword.isEmpty ? nil : trimmedPassword,
            plugin: trimmedPlugin.isEmpty ? nil : trimmedPlugin
        )

        if viewModel.users.contains(where: { $0.username == trimmedUser && $0.host == trimmedHost }) {
            onComplete()
        } else {
            isSubmitting = false
            errorMessage = "Failed to create MySQL user"
        }
    }
}
