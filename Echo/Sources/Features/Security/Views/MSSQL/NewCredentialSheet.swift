import SwiftUI
import SQLServerKit

struct NewCredentialSheet: View {
    let session: ConnectionSession
    let onComplete: () -> Void

    @State private var credentialName = ""
    @State private var identity = ""
    @State private var secret = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        let name = credentialName.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = identity.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && !id.isEmpty && !isSubmitting
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("New Credential") {
                    PropertyRow(title: "Credential Name") {
                        TextField("", text: $credentialName, prompt: Text("e.g. my_credential"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }

                    PropertyRow(title: "Identity") {
                        TextField("", text: $identity, prompt: Text("e.g. DOMAIN\\account"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }

                    PropertyRow(title: "Secret") {
                        SecureField("", text: $secret, prompt: Text("Password or key"))
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
        .frame(minWidth: 420, idealWidth: 460, minHeight: 240)
        .navigationTitle("New Credential")
    }

    private func submit() async {
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not connected to SQL Server"
            return
        }

        let name = credentialName.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = identity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !id.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            try await mssql.serverSecurity.createCredential(name: name, identity: id, secret: secret)
            onComplete()
        } catch {
            isSubmitting = false
            errorMessage = error.localizedDescription
        }
    }
}
