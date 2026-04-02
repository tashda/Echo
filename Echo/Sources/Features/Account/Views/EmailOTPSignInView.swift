import SwiftUI

/// Email + OTP sign-in flow: enter email → receive code → verify.
/// Uses grouped form rows matching the Settings visual guidelines.
struct EmailOTPSignInView: View {
    @Bindable var authState: AuthState
    var onBack: () -> Void

    @State private var email = ""
    @State private var otpCode = ""
    @State private var cooldownRemaining = 0
    @State private var cooldownTimer: Timer?

    private var canSendOTP: Bool {
        !email.isEmpty && email.contains("@") && cooldownRemaining == 0 && !authState.isLoading
    }

    private var canVerify: Bool {
        otpCode.count == 6 && otpCode.allSatisfy(\.isNumber) && !authState.isLoading
    }

    var body: some View {
        if authState.isAwaitingOTPVerification {
            verificationRow
        } else {
            emailRow
        }
    }

    // MARK: - Email Input Row

    private var emailRow: some View {
        HStack {
            Button { onBack() } label: {
                Image(systemName: "chevron.left")
                    .font(TypographyTokens.labelBold)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            .buttonStyle(.plain)
            .help("Back to sign-in options")

            VStack(alignment: .leading, spacing: 2) {
                Text("Sign in with Email")
                    .font(TypographyTokens.prominent)

                Text("We'll send a 6-digit code to your email")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            Spacer()

            TextField("", text: $email, prompt: Text("you@example.com"))
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .frame(width: 180)
                .onSubmit {
                    if canSendOTP {
                        Task { await authState.sendOTP(email: email) }
                        startCooldownTimer()
                    }
                }

            Button("Send Code") {
                Task { await authState.sendOTP(email: email) }
                startCooldownTimer()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!canSendOTP)
        }
        .padding(.vertical, SpacingTokens.xs)
    }

    // MARK: - Verification Row

    private var verificationRow: some View {
        HStack {
            Button { cancelVerification() } label: {
                Image(systemName: "chevron.left")
                    .font(TypographyTokens.labelBold)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            .buttonStyle(.plain)
            .help("Back")

            VStack(alignment: .leading, spacing: 2) {
                Text("Enter Code")
                    .font(TypographyTokens.prominent)

                Text("Sent to **\(email)**")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            Spacer()

            TextField("", text: $otpCode, prompt: Text("000000"))
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
                .multilineTextAlignment(.center)
                .font(.system(.body, design: .monospaced))
                .onSubmit {
                    if canVerify {
                        Task { await authState.verifyOTP(email: email, code: otpCode) }
                    }
                }

            Button("Verify") {
                Task { await authState.verifyOTP(email: email, code: otpCode) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .keyboardShortcut(.defaultAction)
            .disabled(!canVerify)

            if cooldownRemaining > 0 {
                Text("\(cooldownRemaining)s")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .monospacedDigit()
            } else {
                Button("Resend") {
                    Task { await authState.sendOTP(email: email) }
                    startCooldownTimer()
                }
                .buttonStyle(.plain)
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
        .padding(.vertical, SpacingTokens.xs)
    }

    // MARK: - Helpers

    private func cancelVerification() {
        authState.cancelOTP()
        otpCode = ""
        stopCooldownTimer()
        onBack()
    }

    private func startCooldownTimer() {
        cooldownRemaining = 60
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if cooldownRemaining > 0 {
                    cooldownRemaining -= 1
                } else {
                    stopCooldownTimer()
                }
            }
        }
    }

    private func stopCooldownTimer() {
        cooldownTimer?.invalidate()
        cooldownTimer = nil
        cooldownRemaining = 0
    }
}
