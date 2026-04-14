import SwiftUI

/// Prompts for the master password to unlock E2E encrypted credentials.
/// Shown when E2E is enrolled but the master key isn't in the local Keychain.
struct E2EUnlockView: View {
    @Bindable var enrollmentManager: E2EEnrollmentManager
    let onUnlock: () async -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showRecovery = false
    @State private var attemptCount = 0

    var body: some View {
        SheetLayoutCustomFooter(title: "Unlock Credentials") {
            Form {
                Section {
                    PropertyRow(
                        title: "Master Password",
                        subtitle: "Enter your master password to decrypt synced credentials on this Mac."
                    ) {
                        SecureField("", text: $password, prompt: Text("Enter password"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .onSubmit { Task { await unlock() } }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        } footer: {
            if let errorMessage {
                Text(errorMessage)
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Status.error)
                    .lineLimit(2)
            }

            Button("Skip") { dismiss() }

            if attemptCount >= 2 {
                Button("Forgot Password?") { showRecovery = true }
            }

            Spacer()

            Button("Unlock") {
                Task { await unlock() }
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.defaultAction)
            .disabled(password.isEmpty || isProcessing)
        }
        .frame(width: 400, height: 260)
        .sheet(isPresented: $showRecovery) {
            E2ERecoveryView(enrollmentManager: enrollmentManager) {
                await onUnlock()
            }
        }
    }

    private func unlock() async {
        errorMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await enrollmentManager.unlock(password: password)
            SyncPreferences.setCredentialSyncEnabled(true)
            await onUnlock()
            dismiss()
        } catch {
            attemptCount += 1
            errorMessage = attemptCount >= 3
                ? "Incorrect password. Use your recovery key to reset."
                : "Incorrect master password. Please try again."
            password = ""
        }
    }
}
