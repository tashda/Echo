import SwiftUI
import AuthenticationServices

/// The sign-in screen shown when the user is not authenticated.
/// Offers Apple, Google, and Email OTP sign-in methods.
struct SignInView: View {
    @Bindable var authState: AuthState

    @State private var showEmailOTP = false
    @State private var appleCoordinator = AppleSignInCoordinator()
    @State private var googleCoordinator = GoogleSignInCoordinator()

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            header

            if showEmailOTP {
                EmailOTPSignInView(authState: authState)
                    .frame(maxWidth: 320)

                Button("Back to sign-in options") {
                    showEmailOTP = false
                    authState.cancelOTP()
                }
                .buttonStyle(.plain)
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Text.secondary)
            } else {
                signInButtons
            }
        }
        .padding(SpacingTokens.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: SpacingTokens.xs) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.Text.tertiary)

            Text("Sign in to Echo")
                .font(TypographyTokens.title)

            Text("Sign in to sync your connections, settings, and snippets across devices.")
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Text.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
    }

    // MARK: - Buttons

    private var signInButtons: some View {
        VStack(spacing: SpacingTokens.sm) {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleAppleResult(result)
            }
            .signInWithAppleButtonStyle(.whiteOutline)
            .frame(width: 260, height: 40)

            Button {
                Task { await signInWithGoogle() }
            } label: {
                HStack(spacing: SpacingTokens.xs) {
                    Image(systemName: "globe")
                    Text("Sign in with Google")
                }
                .frame(width: 240, height: 20)
            }
            .buttonStyle(.bordered)

            Button {
                showEmailOTP = true
            } label: {
                HStack(spacing: SpacingTokens.xs) {
                    Image(systemName: "envelope")
                    Text("Sign in with Email")
                }
                .frame(width: 240, height: 20)
            }
            .buttonStyle(.bordered)

            if let error = authState.error {
                Text(error.localizedDescription)
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Status.error)
                    .frame(maxWidth: 280)
                    .multilineTextAlignment(.center)
            }
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
        do {
            let result = try await googleCoordinator.signIn()
            await authState.signInWithGoogle(
                authorizationCode: result.authorizationCode,
                codeVerifier: result.codeVerifier
            )
        } catch let error as AuthError where error == .cancelled {
            // User cancelled — do nothing
        } catch {
            authState.setError(.unknown(error.localizedDescription))
        }
    }
}

// MARK: - AuthError Equatable

extension AuthError: Equatable {
    static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.cancelled, .cancelled): return true
        default: return false
        }
    }
}
