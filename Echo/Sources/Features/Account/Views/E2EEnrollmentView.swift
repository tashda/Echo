import SwiftUI
import UniformTypeIdentifiers

/// Multi-step wizard for E2E credential sync enrollment.
/// Step 1: Master password → Step 2: Recovery key display → Step 3: Confirmation.
struct E2EEnrollmentView: View {
    @Bindable var enrollmentManager: E2EEnrollmentManager
    @Environment(\.dismiss) private var dismiss

    @State private var step: EnrollmentStep = .password
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var recoveryWords: [String] = []
    @State private var savedRecoveryKey = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    private enum EnrollmentStep {
        case password
        case recoveryKey
        case done
    }

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .password:
                passwordStep
            case .recoveryKey:
                recoveryKeyStep
            case .done:
                doneStep
            }
        }
        .frame(width: 460, height: 400)
    }

    // MARK: - Step 1: Master Password

    private var passwordStep: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    Label("Create Master Password", systemImage: "lock.shield")
                        .font(TypographyTokens.headline)

                    Text("This password encrypts your database credentials before they leave this device. Echo cannot reset it.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .padding(.bottom, SpacingTokens.xs)

                SecureField("", text: $password, prompt: Text("Master password"))

                SecureField("", text: $confirmPassword, prompt: Text("Confirm master password"))

                if let errorMessage {
                    Text(errorMessage)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Status.error)
                }
            }

            Section {
                HStack {
                    Button("Cancel") { dismiss() }

                    Spacer()

                    Button("Continue") {
                        Task { await beginEnrollment() }
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canContinue || isProcessing)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var canContinue: Bool {
        password.count >= 8 && password == confirmPassword
    }

    private func saveRecoveryKeyToFile() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Echo Recovery Key.txt"
        panel.allowedContentTypes = [.plainText]
        panel.message = "Save your recovery key somewhere safe. You'll need it if you forget your master password."
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let numbered = recoveryWords.enumerated().map { "\($0.offset + 1). \($0.element)" }
            let content = """
            Echo Recovery Key
            =================

            Keep this file in a safe place. If you forget your master
            password, these 24 words are the ONLY way to recover your
            encrypted database credentials.

            \(numbered.joined(separator: "\n"))

            Generated: \(Date().formatted(date: .long, time: .shortened))
            """
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func beginEnrollment() async {
        errorMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        do {
            recoveryWords = try await enrollmentManager.enroll(password: password)
            step = .recoveryKey
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Step 2: Recovery Key

    private var recoveryKeyStep: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    Label("Save Your Recovery Key", systemImage: "key")
                        .font(TypographyTokens.headline)

                    Text("If you forget your master password, this is the **only way** to recover your encrypted credentials. Write it down and store it somewhere safe.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .padding(.bottom, SpacingTokens.xs)

                // 3 columns × 8 rows grid
                Grid(alignment: .leading, horizontalSpacing: SpacingTokens.lg, verticalSpacing: SpacingTokens.xs) {
                    ForEach(0..<8, id: \.self) { row in
                        GridRow {
                            ForEach(0..<3, id: \.self) { col in
                                let idx = row * 3 + col
                                HStack(spacing: 4) {
                                    Text("\(idx + 1).")
                                        .font(TypographyTokens.detailMono)
                                        .foregroundStyle(ColorTokens.Text.tertiary)
                                        .frame(width: 22, alignment: .trailing)
                                    Text(recoveryWords[idx])
                                        .font(TypographyTokens.codeMedium)
                                }
                                .frame(minWidth: 110, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(SpacingTokens.md)
                .background(ColorTokens.Background.secondary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))

                HStack(spacing: SpacingTokens.sm) {
                    Button("Copy to Clipboard") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(recoveryWords.joined(separator: " "), forType: .string)
                    }

                    Button("Save to File…") {
                        saveRecoveryKeyToFile()
                    }
                }
                .font(TypographyTokens.formDescription)
            }

            Section {
                Toggle("I have saved this recovery key in a safe place", isOn: $savedRecoveryKey)
                    .toggleStyle(.checkbox)

                HStack {
                    Button("Back") { step = .password }
                    Spacer()
                    Button("Finish") { step = .done }
                        .buttonStyle(.bordered)
                    .keyboardShortcut(.defaultAction)
                        .disabled(!savedRecoveryKey)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Step 3: Done

    private var doneStep: some View {
        VStack(spacing: SpacingTokens.lg) {
            Spacer()

            Image(systemName: "checkmark.shield.fill")
                .font(TypographyTokens.iconHero)
                .foregroundStyle(ColorTokens.Status.success)

            Text("Credential Sync Active")
                .font(TypographyTokens.headline)

            Text("Your database passwords are now encrypted before leaving this device. Only you can decrypt them.")
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
        .frame(maxWidth: .infinity)
    }
}
