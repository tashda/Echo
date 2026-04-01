import SwiftUI

/// Recovery flow: enter 24-word mnemonic + set a new master password.
struct E2ERecoveryView: View {
    @Bindable var enrollmentManager: E2EEnrollmentManager
    @Environment(\.dismiss) private var dismiss

    @State private var mnemonicText = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var isRecovered = false

    var body: some View {
        if isRecovered {
            recoveredContent
        } else {
            recoveryForm
        }
    }

    private var recoveryForm: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    Label("Recovery", systemImage: "key.viewfinder")
                        .font(TypographyTokens.headline)

                    Text("Enter your 24-word recovery key to regain access to your encrypted credentials.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }

                TextEditor(text: $mnemonicText)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
                    )

                Text("Separate words with spaces")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }

            Section("New Master Password") {
                SecureField("", text: $newPassword, prompt: Text("New master password"))
                SecureField("", text: $confirmPassword, prompt: Text("Confirm new password"))
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Status.error)
                }
            }

            Section {
                HStack {
                    Button("Cancel") { dismiss() }
                    Spacer()
                    Button("Recover") {
                        Task { await recover() }
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canRecover || isProcessing)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(width: 460, height: 420)
    }

    private var canRecover: Bool {
        let words = mnemonicText.split(separator: " ").map(String.init)
        return words.count == 24 && newPassword.count >= 8 && newPassword == confirmPassword
    }

    private func recover() async {
        errorMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        let words = mnemonicText.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map { String($0).lowercased() }

        do {
            try await enrollmentManager.recover(mnemonic: words, newPassword: newPassword)
            isRecovered = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var recoveredContent: some View {
        VStack(spacing: SpacingTokens.lg) {
            Spacer()

            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.Status.success)

            Text("Recovery Successful")
                .font(TypographyTokens.headline)

            Text("Your master password has been reset and credentials are accessible again.")
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Text.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Spacer()

            Button("Done") { dismiss() }
                .buttonStyle(.bordered)
                    .keyboardShortcut(.defaultAction)
                .padding(.bottom, SpacingTokens.lg)
        }
        .frame(width: 460, height: 300)
    }
}
