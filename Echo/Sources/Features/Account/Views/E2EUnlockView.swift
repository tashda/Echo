import SwiftUI

/// Prompts for the master password to unlock E2E encrypted credentials.
/// Shown when E2E is enrolled but the master key isn't in the local Keychain.
struct E2EUnlockView: View {
    @Bindable var enrollmentManager: E2EEnrollmentManager
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showRecovery = false
    @State private var attemptCount = 0

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    Label("Unlock Credentials", systemImage: "lock.shield")
                        .font(TypographyTokens.headline)

                    Text("Enter your master password to decrypt your synced credentials on this device.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }

                SecureField("", text: $password, prompt: Text("Master password"))
                    .onSubmit { Task { await unlock() } }

                if let errorMessage {
                    Text(errorMessage)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Status.error)
                }
            }

            Section {
                HStack {
                    Button("Skip") { dismiss() }

                    if attemptCount >= 2 {
                        Button("Forgot Password?") { showRecovery = true }
                            .font(TypographyTokens.formDescription)
                    }

                    Spacer()

                    Button("Unlock") {
                        Task { await unlock() }
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty || isProcessing)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(width: 400, height: 260)
        .sheet(isPresented: $showRecovery) {
            E2ERecoveryView(enrollmentManager: enrollmentManager)
        }
    }

    private func unlock() async {
        errorMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await enrollmentManager.unlock(password: password)
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
