import SwiftUI

/// Email + OTP sign-in flow: enter email → receive code → verify.
struct EmailOTPSignInView: View {
    @Bindable var authState: AuthState

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
        VStack(spacing: SpacingTokens.md) {
            if authState.isAwaitingOTPVerification {
                verificationSection
            } else {
                emailInputSection
            }

            if let error = authState.error {
                Text(error.localizedDescription)
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Status.error)
            }
        }
    }

    // MARK: - Email Input

    private var emailInputSection: some View {
        VStack(spacing: SpacingTokens.sm) {
            Text("Sign in with Email")
                .font(TypographyTokens.headline)

            Text("Enter your email address. We'll send you a 6-digit verification code.")
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Text.secondary)
                .multilineTextAlignment(.center)

            TextField("", text: $email, prompt: Text("you@example.com"))
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .frame(maxWidth: 280)

            Button("Send Code") {
                Task { await authState.sendOTP(email: email) }
                startCooldownTimer()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSendOTP)
        }
    }

    // MARK: - Verification

    private var verificationSection: some View {
        VStack(spacing: SpacingTokens.sm) {
            Text("Enter Verification Code")
                .font(TypographyTokens.headline)

            Text("A 6-digit code was sent to **\(email)**")
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Text.secondary)
                .multilineTextAlignment(.center)

            TextField("", text: $otpCode, prompt: Text("000000"))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 160)
                .multilineTextAlignment(.center)
                .font(.system(.title3, design: .monospaced))

            HStack(spacing: SpacingTokens.sm) {
                Button("Verify") {
                    Task { await authState.verifyOTP(email: email, code: otpCode) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canVerify)

                Button("Cancel") {
                    authState.cancelOTP()
                    otpCode = ""
                    stopCooldownTimer()
                }
                .buttonStyle(.bordered)
            }

            if cooldownRemaining > 0 {
                Text("Resend available in \(cooldownRemaining)s")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            } else if authState.isAwaitingOTPVerification {
                Button("Resend Code") {
                    Task { await authState.sendOTP(email: email) }
                    startCooldownTimer()
                }
                .buttonStyle(.plain)
                .font(TypographyTokens.formDescription)
            }
        }
    }

    // MARK: - Cooldown Timer

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
