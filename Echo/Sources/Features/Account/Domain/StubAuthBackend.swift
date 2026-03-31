import Foundation

/// Local stub backend for development. Simulates all auth flows with local state.
/// Replaced by a real cloud backend when the server is ready.
struct StubAuthBackend: AuthBackend {

    func signInWithApple(identityToken: Data, authorizationCode: Data, fullName: PersonNameComponents?) async throws -> (AuthUser, AuthTokens) {
        // Simulate network latency
        try await Task.sleep(for: .milliseconds(600))

        let userID = "apple-\(UUID().uuidString.prefix(8))"
        let name = [fullName?.givenName, fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")

        let user = AuthUser(
            userID: userID,
            email: nil,
            displayName: name.isEmpty ? nil : name,
            authMethod: .apple,
            createdAt: Date(),
            avatarURL: nil,
            linkedMethods: []
        )
        let tokens = makeStubTokens(identityToken: String(data: identityToken, encoding: .utf8))
        return (user, tokens)
    }

    func signInWithGoogle(authorizationCode: String, codeVerifier: String) async throws -> (AuthUser, AuthTokens) {
        try await Task.sleep(for: .milliseconds(600))

        let userID = "google-\(UUID().uuidString.prefix(8))"
        let user = AuthUser(
            userID: userID,
            email: "user@gmail.com",
            displayName: "Google User",
            authMethod: .google,
            createdAt: Date(),
            avatarURL: nil,
            linkedMethods: []
        )
        let tokens = makeStubTokens()
        return (user, tokens)
    }

    func sendOTP(email: String) async throws -> OTPSendResult {
        try await Task.sleep(for: .milliseconds(300))
        return OTPSendResult(
            expiresAt: Date().addingTimeInterval(600),
            cooldownSeconds: 60
        )
    }

    func verifyOTP(email: String, code: String) async throws -> (AuthUser, AuthTokens) {
        try await Task.sleep(for: .milliseconds(400))

        // Accept any 6-digit code in stub mode
        guard code.count == 6, code.allSatisfy(\.isNumber) else {
            throw AuthError.otpInvalid
        }

        let userID = "email-\(UUID().uuidString.prefix(8))"
        let user = AuthUser(
            userID: userID,
            email: email,
            displayName: nil,
            authMethod: .email,
            createdAt: Date(),
            avatarURL: nil,
            linkedMethods: []
        )
        let tokens = makeStubTokens()
        return (user, tokens)
    }

    func refreshTokens(refreshToken: String) async throws -> AuthTokens {
        try await Task.sleep(for: .milliseconds(200))
        return makeStubTokens()
    }

    func signOut(accessToken: String) async throws {
        try await Task.sleep(for: .milliseconds(200))
    }

    func deleteAccount(accessToken: String) async throws {
        try await Task.sleep(for: .milliseconds(400))
    }

    func linkAccount(method: AuthMethod, accessToken: String, payload: Data) async throws -> AuthUser {
        try await Task.sleep(for: .milliseconds(400))
        return AuthUser(
            userID: "stub-linked",
            email: "user@example.com",
            displayName: "Stub User",
            authMethod: .apple,
            createdAt: Date(),
            avatarURL: nil,
            linkedMethods: [method]
        )
    }

    // MARK: - Private

    private func makeStubTokens(identityToken: String? = nil) -> AuthTokens {
        AuthTokens(
            accessToken: "stub-access-\(UUID().uuidString)",
            refreshToken: "stub-refresh-\(UUID().uuidString)",
            expiresAt: Date().addingTimeInterval(3600),
            identityToken: identityToken
        )
    }
}
