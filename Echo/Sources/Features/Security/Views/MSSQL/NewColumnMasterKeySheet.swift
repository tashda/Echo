import SwiftUI
import SQLServerKit

struct NewColumnMasterKeySheet: View {
    let session: ConnectionSession
    let database: String?
    let onComplete: () -> Void

    @State private var keyName = ""
    @State private var keyStoreProvider = "MSSQL_CERTIFICATE_STORE"
    @State private var keyPath = ""
    @State private var allowEnclaveComputations = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let providers = [
        "MSSQL_CERTIFICATE_STORE",
        "AZURE_KEY_VAULT",
        "MSSQL_CNG_STORE",
        "MSSQL_CSP_PROVIDER",
        "MSSQL_JAVA_KEYSTORE"
    ]

    private var keyPathPrompt: String {
        switch keyStoreProvider {
        case "MSSQL_CERTIFICATE_STORE":
            return "CurrentUser/My/thumbprint"
        case "AZURE_KEY_VAULT":
            return "https://vault.azure.net/keys/name/version"
        case "MSSQL_CNG_STORE":
            return "KSP_name/key_identifier"
        case "MSSQL_CSP_PROVIDER":
            return "CSP_name/key_identifier"
        case "MSSQL_JAVA_KEYSTORE":
            return "keystore_path/alias"
        default:
            return "key path"
        }
    }

    private var isFormValid: Bool {
        let name = keyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = keyPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && !path.isEmpty && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New Column Master Key",
            icon: "key.fill",
            subtitle: "Create a column master key for Always Encrypted.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("Column Master Key") {
                    PropertyRow(title: "Key Name") {
                        TextField("", text: $keyName, prompt: Text("e.g. CMK_Auto"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }

                    PropertyRow(title: "Key Store") {
                        Picker("", selection: $keyStoreProvider) {
                            ForEach(providers, id: \.self) { provider in
                                Text(provider).tag(provider)
                            }
                        }
                        .labelsHidden()
                    }

                    PropertyRow(title: "Key Path") {
                        TextField("", text: $keyPath, prompt: Text(keyPathPrompt))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Advanced") {
                    PropertyRow(title: "Allow Enclave Computations") {
                        Toggle("", isOn: $allowEnclaveComputations)
                            .labelsHidden()
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 440, idealWidth: 480, minHeight: 280)
    }

    private func submit() async {
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not connected to SQL Server"
            return
        }

        let name = keyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = keyPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !path.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            if let db = database {
                _ = try? await session.session.sessionForDatabase(db)
            }
            try await mssql.alwaysEncrypted.createColumnMasterKey(
                name: name,
                keyStoreProviderName: keyStoreProvider,
                keyPath: path,
                allowEnclaveComputations: allowEnclaveComputations
            )
            onComplete()
        } catch {
            isSubmitting = false
            errorMessage = error.localizedDescription
        }
    }
}
