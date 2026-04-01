import SwiftUI
import SQLServerKit

struct NewColumnEncryptionKeySheet: View {
    let session: ConnectionSession
    let database: String?
    let onComplete: () -> Void

    @State private var keyName = ""
    @State private var availableCMKs: [ColumnMasterKeyInfo] = []
    @State private var selectedCMK: String?
    @State private var encryptedValue = ""
    @State private var isSubmitting = false
    @State private var isLoadingCMKs = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        let name = keyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = encryptedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && selectedCMK != nil && !value.isEmpty && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New Column Encryption Key",
            icon: "lock.fill",
            subtitle: "Create a column encryption key for Always Encrypted.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("Column Encryption Key") {
                    PropertyRow(title: "Key Name") {
                        TextField("", text: $keyName, prompt: Text("e.g. CEK_Auto"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }

                    PropertyRow(title: "Column Master Key") {
                        Picker("", selection: $selectedCMK) {
                            Text("Select a CMK").tag(nil as String?)
                            ForEach(availableCMKs) { cmk in
                                Text(cmk.name).tag(cmk.name as String?)
                            }
                        }
                        .labelsHidden()
                    }

                    PropertyRow(title: "Algorithm") {
                        Text("RSA_OAEP")
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    PropertyRow(title: "Encrypted Value") {
                        TextField("", text: $encryptedValue, prompt: Text("0x01234ABCDEF..."))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .font(TypographyTokens.code)
                    }
                }

                Section {
                    HStack(spacing: SpacingTokens.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(ColorTokens.Status.warning)
                        Text("Never enter a plaintext column encryption key value. Use key management tools to generate the encrypted value.")
                            .font(TypographyTokens.formDescription)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 440, idealWidth: 480, minHeight: 340)
        .task { await loadCMKs() }
    }

    private func loadCMKs() async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isLoadingCMKs = true
        defer { isLoadingCMKs = false }
        do {
            if let db = database {
                _ = try? await session.session.sessionForDatabase(db)
            }
            availableCMKs = try await mssql.alwaysEncrypted.listColumnMasterKeys()
        } catch {
            availableCMKs = []
        }
    }

    private func submit() async {
        guard let mssql = session.session as? MSSQLSession,
              let cmkName = selectedCMK else { return }

        let name = keyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = encryptedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !value.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            if let db = database {
                _ = try? await session.session.sessionForDatabase(db)
            }
            try await mssql.alwaysEncrypted.createColumnEncryptionKey(
                name: name,
                cmkName: cmkName,
                algorithm: "RSA_OAEP",
                encryptedValue: value
            )
            onComplete()
        } catch {
            isSubmitting = false
            errorMessage = error.localizedDescription
        }
    }
}
