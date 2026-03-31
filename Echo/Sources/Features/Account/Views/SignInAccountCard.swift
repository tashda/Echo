import SwiftUI
import AuthenticationServices

/// Sign-in card shown at the top of General settings when not signed in.
struct SignInAccountCard: View {
    @Bindable var authState: AuthState

    @State private var email = ""
    @State private var showOTPVerification = false

    var body: some View {
        Section {
            VStack(spacing: SpacingTokens.lg) {
                headerContent
                oauthButtons
                dividerRow
                emailSection

                if let error = authState.error {
                    errorBanner(error)
                }
            }
            .padding(.vertical, SpacingTokens.sm)
            .frame(maxWidth: 320)
            .frame(maxWidth: .infinity)
        } header: {
            Text("Echo Account")
        }
    }

    // MARK: - Header

    private var headerContent: some View {
        VStack(spacing: SpacingTokens.xs) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)

            Text("Sign in to Echo")
                .font(TypographyTokens.prominent)

            Text("Sync connections, settings, and snippets across your devices.")
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Text.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - OAuth Buttons

    private var oauthButtons: some View {
        VStack(spacing: SpacingTokens.xs) {
            // Apple — use the native SignInWithAppleButton for compliance
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleAppleResult(result)
            }
            .signInWithAppleButtonStyle(.whiteOutline)
            .frame(height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Google — styled to match Apple button height and weight
            Button {
                Task { await signInWithGoogle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .font(.system(size: 14, weight: .medium))
                    Text("Sign in with Google")
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.3), lineWidth: 1)
            }
        }
    }

    // MARK: - Divider

    private var dividerRow: some View {
        HStack(spacing: SpacingTokens.sm) {
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
            Text("OR")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ColorTokens.Text.tertiary)
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
        }
    }

    // MARK: - Email Section

    @ViewBuilder
    private var emailSection: some View {
        if showOTPVerification {
            EmailOTPSignInView(authState: authState)
        } else {
            emailInputContent
        }
    }

    private var emailInputContent: some View {
        VStack(spacing: SpacingTokens.xs) {
            TextField("", text: $email, prompt: Text("Email address"))
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)

            Button {
                Task {
                    await authState.sendOTP(email: email)
                    if authState.error == nil {
                        showOTPVerification = true
                    }
                }
            } label: {
                Text("Continue with Email")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Color.primary, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(email.isEmpty || !email.contains("@") || authState.isLoading)
            .opacity(email.isEmpty || !email.contains("@") ? 0.4 : 1)
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: AuthError) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 12))

            Text(friendlyErrorMessage(error))
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }

    private func friendlyErrorMessage(_ error: AuthError) -> String {
        switch error {
        case .otpInvalid:
            return "That verification code is incorrect. Please try again."
        case .otpExpired:
            return "Your verification code has expired. Request a new one."
        case .invalidCredentials:
            return "Unable to verify your credentials. Please try again."
        case .rateLimited(let seconds):
            return "Too many attempts. Please wait \(seconds) seconds."
        case .networkFailure:
            return "Unable to connect. Check your internet and try again."
        case .cancelled:
            return "Sign-in was cancelled."
        default:
            return error.localizedDescription
        }
    }

    // MARK: - Apple Sign In

    private func handleAppleResult(_ result: Result<ASAuthorization, any Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken,
                  let authorizationCode = credential.authorizationCode else {
                authState.setError(.unknown("Missing Apple credential data."))
                return
            }
            Task {
                await authState.signInWithApple(
                    identityToken: identityToken,
                    authorizationCode: authorizationCode,
                    fullName: credential.fullName
                )
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            authState.setError(.unknown(error.localizedDescription))
        }
    }

    // MARK: - Google Sign In

    private func signInWithGoogle() async {
        await authState.signInWithGoogleOAuth()
    }
}
