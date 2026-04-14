import Testing
import Foundation
@testable import Echo

@Suite("AuthTypes")
struct AuthTypesTests {

    // MARK: - AuthMethod

    @Test func authMethodDisplayNames() {
        #expect(AuthMethod.apple.displayName == "Apple")
        #expect(AuthMethod.google.displayName == "Google")
        #expect(AuthMethod.email.displayName == "Email")
    }

    @Test func authMethodSystemImages() {
        #expect(AuthMethod.apple.systemImage == "apple.logo")
        #expect(AuthMethod.google.systemImage == "globe")
        #expect(AuthMethod.email.systemImage == "envelope")
    }

    @Test func authMethodIdentifiable() {
        #expect(AuthMethod.apple.id == "apple")
        #expect(AuthMethod.google.id == "google")
        #expect(AuthMethod.email.id == "email")
    }

    @Test func authMethodCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for method in AuthMethod.allCases {
            let data = try encoder.encode(method)
            let decoded = try decoder.decode(AuthMethod.self, from: data)
            #expect(decoded == method)
        }
    }

    // MARK: - AuthUser

    @Test func authUserCodableRoundTrip() throws {
        let user = AuthUser(
            userID: "test-123",
            email: "user@example.com",
            displayName: "Test User",
            authMethod: .google,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            linkedMethods: [.apple, .email]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(user)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AuthUser.self, from: data)

        #expect(decoded == user)
    }

    @Test func authUserEquality() {
        let a = AuthUser(userID: "1", email: nil, displayName: nil, authMethod: .apple, createdAt: Date(), linkedMethods: [])
        let b = AuthUser(userID: "1", email: nil, displayName: nil, authMethod: .apple, createdAt: a.createdAt, linkedMethods: [])
        #expect(a == b)
    }

    // MARK: - AuthTokens

    @Test func authTokensCodableRoundTrip() throws {
        let tokens = AuthTokens(
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: Date(timeIntervalSince1970: 1_700_000_000),
            identityToken: "identity"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(tokens)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AuthTokens.self, from: data)

        #expect(decoded.accessToken == tokens.accessToken)
        #expect(decoded.refreshToken == tokens.refreshToken)
        #expect(decoded.identityToken == tokens.identityToken)
    }

    @Test func authTokensWithNilFields() throws {
        let tokens = AuthTokens(
            accessToken: "access-only",
            refreshToken: nil,
            expiresAt: nil,
            identityToken: nil
        )

        let data = try JSONEncoder().encode(tokens)
        let decoded = try JSONDecoder().decode(AuthTokens.self, from: data)

        #expect(decoded.accessToken == "access-only")
        #expect(decoded.refreshToken == nil)
        #expect(decoded.expiresAt == nil)
        #expect(decoded.identityToken == nil)
    }

    // MARK: - AuthError

    @Test func authErrorDescriptions() {
        #expect(AuthError.notAuthenticated.errorDescription != nil)
        #expect(AuthError.invalidCredentials.errorDescription != nil)
        #expect(AuthError.tokenExpired.errorDescription != nil)
        #expect(AuthError.rateLimited(retryAfterSeconds: 30).errorDescription?.contains("30") == true)
        #expect(AuthError.otpExpired.errorDescription != nil)
        #expect(AuthError.otpInvalid.errorDescription != nil)
        #expect(AuthError.networkFailure("timeout").errorDescription?.contains("timeout") == true)
        #expect(AuthError.cancelled.errorDescription != nil)
        #expect(AuthError.unknown("oops").errorDescription?.contains("oops") == true)
    }

    // MARK: - OTPSendResult

    @Test func otpSendResultProperties() {
        let result = OTPSendResult(
            expiresAt: Date().addingTimeInterval(600),
            cooldownSeconds: 60
        )
        #expect(result.cooldownSeconds == 60)
        #expect(result.expiresAt > Date())
    }
}
