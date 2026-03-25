import SwiftUI
import SQLServerKit

/// Sheet for configuring SQL Server replication distribution.
struct ConfigureDistributionSheet: View {
    let session: ConnectionSession
    let onComplete: () -> Void

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var distributionDBName = "distribution"
    @State private var snapshotFolder = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var currentStep = 0

    private var isFormValid: Bool {
        !password.isEmpty && password == confirmPassword && !isSubmitting
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Distribution Password") {
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

                Section("Distribution Database") {
                    PropertyRow(title: "Database Name") {
                        TextField("", text: $distributionDBName, prompt: Text("e.g. distribution"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Snapshot Folder") {
                        TextField("", text: $snapshotFolder, prompt: Text("Optional — server default if empty"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }

                if isSubmitting {
                    Section {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text(stepMessage)
                                .font(TypographyTokens.detail)
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
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
                        .lineLimit(2)
                }

                Spacer()

                Button("Cancel") { onComplete() }
                    .keyboardShortcut(.cancelAction)

                Button("Configure") { Task { await submit() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isFormValid)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, SpacingTokens.md2)
            .padding(.vertical, SpacingTokens.sm2)
            .background(.bar)
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 320)
        .navigationTitle("Configure Distribution")
    }

    private var stepMessage: String {
        switch currentStep {
        case 0: return "Configuring distributor..."
        case 1: return "Creating distribution database..."
        case 2: return "Enabling publishing..."
        default: return "Finishing..."
        }
    }

    private func submit() async {
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not connected to SQL Server"
            return
        }

        isSubmitting = true
        errorMessage = nil

        do {
            currentStep = 0
            try await mssql.replication.configureDistributor(password: password)

            currentStep = 1
            let folder = snapshotFolder.trimmingCharacters(in: .whitespacesAndNewlines)
            try await mssql.replication.configureDistributionDB(
                name: distributionDBName.trimmingCharacters(in: .whitespacesAndNewlines),
                snapshotFolder: folder.isEmpty ? nil : folder
            )

            currentStep = 2
            try await mssql.replication.enablePublishing(
                distributionDB: distributionDBName.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )

            onComplete()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}
