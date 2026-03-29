import Testing
import Foundation
@testable import Echo

@Suite("StubAuthBackend")
struct StubAuthBackendTests {

    private let backend = StubAuthBackend()

    // MARK: - Apple

    @Test func signInWithAppleReturnsUserAndTokens() async throws {
        let token = Data("identity".utf8)
        let code = Data("auth-code".utf8)
        var name = PersonNameComponents()
        name.givenName = "Jane"
        name.familyName = "Doe"

        let (user, tokens) = try await backend.signInWithApple(
            identityToken: token,
            authorizationCode: code,
            fullName: name
        )

        #expect(user.authMethod == .apple)
        #expect(user.displayName == "Jane Doe")
        #expect(user.userID.hasPrefix("apple-"))
        #expect(!tokens.accessToken.isEmpty)
        #expect(tokens.refreshToken != nil)
    }

    // MARK: - Google

    @Test func signInWithGoogleReturnsUserAndTokens() async throws {
        let (user, tokens) = try await backend.signInWithGoogle(
            authorizationCode: "code",
            codeVerifier: "verifier"
        )

        #expect(user.authMethod == .google)
        #expect(user.email == "user@gmail.com")
        #expect(user.userID.hasPrefix("google-"))
        #expect(!tokens.accessToken.isEmpty)
    }

    // MARK: - OTP

    @Test func sendOTPReturnsValidResult() async throws {
        let result = try await backend.sendOTP(email: "test@test.com")

        #expect(result.cooldownSeconds == 60)
        #expect(result.expiresAt > Date())
    }

    @Test func verifyOTPAcceptsValidSixDigitCode() async throws {
        let (user, tokens) = try await backend.verifyOTP(email: "test@test.com", code: "123456")

        #expect(user.authMethod == .email)
        #expect(user.email == "test@test.com")
        #expect(!tokens.accessToken.isEmpty)
    }

    @Test func verifyOTPRejectsInvalidCode() async {
        await #expect(throws: AuthError.self) {
            _ = try await backend.verifyOTP(email: "test@test.com", code: "abc")
        }
    }

    @Test func verifyOTPRejectsShortCode() async {
        await #expect(throws: AuthError.self) {
            _ = try await backend.verifyOTP(email: "test@test.com", code: "123")
        }
    }

    // MARK: - Session

    @Test func refreshTokensReturnsNewTokens() async throws {
        let tokens = try await backend.refreshTokens(refreshToken: "old-refresh")
        #expect(!tokens.accessToken.isEmpty)
        #expect(tokens.expiresAt != nil)
    }

    @Test func signOutCompletes() async throws {
        try await backend.signOut(accessToken: "token")
        // No error = success
    }

    @Test func deleteAccountCompletes() async throws {
        try await backend.deleteAccount(accessToken: "token")
        // No error = success
    }

    @Test func linkAccountReturnsUpdatedUser() async throws {
        let user = try await backend.linkAccount(
            method: .google,
            accessToken: "token",
            payload: Data()
        )
        #expect(user.linkedMethods.contains(.google))
    }
}
