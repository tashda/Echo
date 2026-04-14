import Foundation

/// Protocol abstracting the auth backend so a real API can be swapped in later.
/// The stub implementation uses local storage; the production implementation
/// will call a cloud endpoint.
protocol AuthBackend: Sendable {

    // MARK: - Apple

    /// Exchange an Apple identity token for Echo auth tokens.
    func signInWithApple(identityToken: Data, authorizationCode: Data, fullName: PersonNameComponents?) async throws -> (AuthUser, AuthTokens)

    // MARK: - Google

    /// Exchange a Google OAuth authorization code for Echo auth tokens.
    func signInWithGoogle(authorizationCode: String, codeVerifier: String) async throws -> (AuthUser, AuthTokens)

    // MARK: - Email OTP

    /// Request a one-time password sent to the given email.
    func sendOTP(email: String) async throws -> OTPSendResult

    /// Verify the OTP and receive auth tokens.
    func verifyOTP(email: String, code: String) async throws -> (AuthUser, AuthTokens)

    // MARK: - Session

    /// Refresh an expired access token using a refresh token.
    func refreshTokens(refreshToken: String) async throws -> AuthTokens

    /// Sign out and invalidate all tokens server-side.
    func signOut(accessToken: String) async throws

    // MARK: - Account Management

    /// Delete the user's account permanently.
    func deleteAccount(accessToken: String) async throws

    /// Link an additional auth method to an existing account.
    func linkAccount(method: AuthMethod, accessToken: String, payload: Data) async throws -> AuthUser

    /// Update the user's display name in the auth backend.
    func updateDisplayName(_ name: String) async throws -> AuthUser
}
