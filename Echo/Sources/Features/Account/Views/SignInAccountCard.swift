import AuthenticationServices
import SwiftUI

/// Compact sign-in row shown in General settings when not signed in.
struct SignInAccountCard: View {
    @Bindable var authState: AuthState

    @State private var showOTPVerification = false
    @State private var hoveredProvider: AuthMethod?

    var body: some View {
        Section {
            if showOTPVerification {
                otpContent
            } else {
                signInRow
            }

            if let error = authState.error {
                errorBanner(error)
            }
        } header: {
            Text("Echo Account")
        }
    }

    // MARK: - Compact Sign-In Row

    private var signInRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sign in to Echo")
                    .font(TypographyTokens.prominent)

                Text("Sync connections and settings across devices")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            Spacer()

            HStack(spacing: SpacingTokens.sm) {
                appleSignInButton
                googleSignInButton
                emailSignInButton
            }
        }
        .padding(.vertical, SpacingTokens.xs)
    }

    // MARK: - Provider Buttons

    private var appleSignInButton: some View {
        Button {
            Task { await signInWithApple() }
        } label: {
            providerButton(method: .apple) {
                Image(systemName: "apple.logo")
                    .font(TypographyTokens.displayMedium)
            }
        }
        .buttonStyle(.plain)
        .help("Sign in with Apple")
    }

    private var googleSignInButton: some View {
        Button {
            Task { await authState.signInWithGoogleOAuth() }
        } label: {
            providerButton(method: .google) {
                Image("GoogleLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
            }
        }
        .buttonStyle(.plain)
        .help("Sign in with Google")
    }

    private var emailSignInButton: some View {
        Button {
            showOTPVerification = true
        } label: {
            providerButton(method: .email) {
                Image(systemName: "envelope.fill")
                    .font(TypographyTokens.prominent)
            }
        }
        .buttonStyle(.plain)
        .help("Sign in with Email")
    }

    private func providerButton<Icon: View>(method: AuthMethod, @ViewBuilder icon: () -> Icon) -> some View {
        icon()
            .foregroundStyle(ColorTokens.Text.primary)
            .frame(width: 40, height: 40)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(hoveredProvider == method ? Color.primary.opacity(0.08) : Color.clear)
                    .animation(.easeInOut(duration: 0.15), value: hoveredProvider)
            }
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.75)
            }
            .onHover { isHovered in
                hoveredProvider = isHovered ? method : nil
            }
    }

    // MARK: - OTP Flow

    private var otpContent: some View {
        EmailOTPSignInView(authState: authState, onBack: {
            showOTPVerification = false
            authState.cancelOTP()
        })
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: AuthError) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(TypographyTokens.caption2)

            Text(friendlyErrorMessage(error))
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.Status.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }

    private func friendlyErrorMessage(_ error: AuthError) -> String {
        switch error {
        case .otpInvalid: "That verification code is incorrect. Please try again."
        case .otpExpired: "Your verification code has expired. Request a new one."
        case .invalidCredentials: "Unable to verify your credentials. Please try again."
        case .rateLimited(let seconds): "Too many attempts. Please wait \(seconds) seconds."
        case .networkFailure: "Unable to connect. Check your internet and try again."
        case .cancelled: "Sign-in was cancelled."
        default: error.localizedDescription
        }
    }

    // MARK: - Apple Sign In

    private func signInWithApple() async {
        let coordinator = AppleSignInCoordinator()
        do {
            let credential = try await coordinator.signIn()
            guard let identityToken = credential.identityToken,
                  let authorizationCode = credential.authorizationCode else {
                authState.setError(.unknown("Missing Apple credential data."))
                return
            }
            await authState.signInWithApple(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                fullName: credential.fullName
            )
        } catch let error as AuthError {
            if case .cancelled = error { return }
            authState.setError(error)
            return
        } catch {
            authState.setError(.unknown(error.localizedDescription))
        }
    }
}
