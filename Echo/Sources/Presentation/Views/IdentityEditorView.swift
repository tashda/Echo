import SwiftUI

struct IdentityEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    @State private var name: String = ""
    @State private var username: String = ""
    @State private var password: String = ""

    let onSave: (SavedIdentity, String?) -> Void

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    LabeledContent("Name") {
                        TextField("", text: $name, prompt: Text("My Identity"))
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Username") {
                        TextField("", text: $username, prompt: Text("username"))
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Password") {
                        SecureField("", text: $password, prompt: Text("password"))
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Identity Details")
                } footer: {
                    Text("Identities can be reused across multiple connections.")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack(spacing: 12) {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    let identity = SavedIdentity(
                        projectID: appModel.selectedProject?.id,
                        name: name,
                        username: username,
                        keychainIdentifier: "echo.identity.\(UUID().uuidString)",
                        folderID: nil
                    )
                    onSave(identity, password.isEmpty ? nil : password)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
        }
        .frame(width: 400, height: 280)
    }
}
