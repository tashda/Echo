import Foundation
import Observation

/// Observable auth state that drives the Account settings UI.
/// Lives as a singleton on AppDirector and is injected into the environment.
@Observable
final class AuthState {
    private let backend: any AuthBackend
    private let tokenStore: AuthTokenStore

    // MARK: - Published State

    /// The currently signed-in user, or nil if signed out.
    private(set) var currentUser: AuthUser?

    /// Whether an auth operation is in progress.
    private(set) var isLoading = false

    /// The most recent error, cleared on next operation.
    private(set) var error: AuthError?

    // MARK: - OTP State

    /// Whether an OTP has been sent and we're awaiting verification.
    private(set) var isAwaitingOTPVerification = false

    /// When the current OTP expires.
    private(set) var otpExpiresAt: Date?

    /// Cooldown remaining before another OTP can be sent.
    private(set) var otpCooldownEnd: Date?

    var isSignedIn: Bool { currentUser != nil }

    // MARK: - Init

    init(backend: any AuthBackend = StubAuthBackend(), tokenStore: AuthTokenStore = AuthTokenStore()) {
        self.backend = backend
        self.tokenStore = tokenStore
    }

    // MARK: - Restore Session

    /// Called at app launch to restore a previously saved session.
    func restoreSession() async {
        do {
            let user = try await tokenStore.loadUser()
            let tokens = try await tokenStore.loadTokens()
            if let user, tokens != nil {
                currentUser = user
            }
        } catch {
            // No saved session — stay signed out
        }
    }

    // MARK: - Sign In with Apple

    func signInWithApple(identityToken: Data, authorizationCode: Data, fullName: PersonNameComponents?) async {
        await performAuth {
            try await self.backend.signInWithApple(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                fullName: fullName
            )
        }
    }

    // MARK: - Sign In with Google

    func signInWithGoogle(authorizationCode: String, codeVerifier: String) async {
        await performAuth {
            try await self.backend.signInWithGoogle(
                authorizationCode: authorizationCode,
                codeVerifier: codeVerifier
            )
        }
    }

    /// SDK-managed Google OAuth — opens ASWebAuthenticationSession internally.
    func signInWithGoogleOAuth() async {
        guard let supabaseBackend = backend as? SupabaseAuthBackend else {
            error = .unknown("Google sign-in requires Supabase backend.")
            return
        }
        await performAuth {
            try await supabaseBackend.signInWithGoogleOAuth()
        }
    }

    // MARK: - Email OTP

    func sendOTP(email: String) async {
        error = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await backend.sendOTP(email: email)
            isAwaitingOTPVerification = true
            otpExpiresAt = result.expiresAt
            otpCooldownEnd = Date().addingTimeInterval(TimeInterval(result.cooldownSeconds))
        } catch let authError as AuthError {
            error = authError
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
    }

    func verifyOTP(email: String, code: String) async {
        await performAuth {
            let result = try await self.backend.verifyOTP(email: email, code: code)
            self.isAwaitingOTPVerification = false
            self.otpExpiresAt = nil
            self.otpCooldownEnd = nil
            return result
        }
    }

    func cancelOTP() {
        isAwaitingOTPVerification = false
        otpExpiresAt = nil
        otpCooldownEnd = nil
    }

    // MARK: - Sign Out

    func signOut() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if let tokens = try await tokenStore.loadTokens() {
                try? await backend.signOut(accessToken: tokens.accessToken)
            }
            try await tokenStore.clearAll()
            currentUser = nil
            error = nil
        } catch {
            // Clear local state even if server sign-out fails
            try? await tokenStore.clearAll()
            currentUser = nil
        }
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        isLoading = true
        defer { isLoading = false }

        guard let tokens = try await tokenStore.loadTokens() else {
            throw AuthError.notAuthenticated
        }

        try await backend.deleteAccount(accessToken: tokens.accessToken)
        try await tokenStore.clearAll()
        currentUser = nil
    }

    // MARK: - Error Reporting

    /// Set an error from external callers (e.g. sign-in view callbacks).
    func setError(_ error: AuthError) {
        self.error = error
    }

    // MARK: - Private

    private func performAuth(_ operation: () async throws -> (AuthUser, AuthTokens)) async {
        error = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let (user, tokens) = try await operation()
            try await tokenStore.saveTokens(tokens)
            try await tokenStore.saveUser(user)
            currentUser = user
        } catch let authError as AuthError {
            error = authError
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
    }
}
