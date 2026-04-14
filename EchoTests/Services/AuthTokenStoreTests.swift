import Testing
import Foundation
@testable import Echo

@Suite("AuthTokenStore")
struct AuthTokenStoreTests {

    private let store = AuthTokenStore()

    // MARK: - Token Round-trip

    @Test func saveAndLoadTokens() async throws {
        let tokens = AuthTokens(
            accessToken: "access-123",
            refreshToken: "refresh-456",
            expiresAt: Date(timeIntervalSince1970: 1_700_000_000),
            identityToken: "identity-789"
        )

        try await store.saveTokens(tokens)
        let loaded = try await store.loadTokens()

        #expect(loaded != nil)
        #expect(loaded?.accessToken == "access-123")
        #expect(loaded?.refreshToken == "refresh-456")
        #expect(loaded?.identityToken == "identity-789")

        // Cleanup
        try await store.deleteTokens()
    }

    @Test func loadTokensReturnsNilWhenEmpty() async throws {
        // Ensure clean state
        try await store.deleteTokens()

        let loaded = try await store.loadTokens()
        #expect(loaded == nil)
    }

    @Test func deleteTokensRemovesFromKeychain() async throws {
        let tokens = AuthTokens(
            accessToken: "to-delete",
            refreshToken: nil,
            expiresAt: nil,
            identityToken: nil
        )

        try await store.saveTokens(tokens)
        try await store.deleteTokens()

        let loaded = try await store.loadTokens()
        #expect(loaded == nil)
    }

    // MARK: - User Round-trip

    @Test func saveAndLoadUser() async throws {
        let user = AuthUser(
            userID: "user-abc",
            email: "test@example.com",
            displayName: "Test User",
            authMethod: .google,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            linkedMethods: [.apple]
        )

        try await store.saveUser(user)
        let loaded = try await store.loadUser()

        #expect(loaded != nil)
        #expect(loaded?.userID == "user-abc")
        #expect(loaded?.email == "test@example.com")
        #expect(loaded?.displayName == "Test User")
        #expect(loaded?.authMethod == .google)
        #expect(loaded?.linkedMethods == [.apple])

        // Cleanup
        try await store.deleteUser()
    }

    @Test func loadUserReturnsNilWhenNoFile() async throws {
        try await store.deleteUser()

        let loaded = try await store.loadUser()
        #expect(loaded == nil)
    }

    // MARK: - Clear All

    @Test func clearAllRemovesBothTokensAndUser() async throws {
        let tokens = AuthTokens(
            accessToken: "access",
            refreshToken: nil,
            expiresAt: nil,
            identityToken: nil
        )
        let user = AuthUser(
            userID: "user",
            email: nil,
            displayName: nil,
            authMethod: .email,
            createdAt: Date(),
            linkedMethods: []
        )

        try await store.saveTokens(tokens)
        try await store.saveUser(user)

        try await store.clearAll()

        #expect(try await store.loadTokens() == nil)
        #expect(try await store.loadUser() == nil)
    }

    // MARK: - Overwrite

    @Test func saveTokensOverwritesPrevious() async throws {
        let first = AuthTokens(accessToken: "first", refreshToken: nil, expiresAt: nil, identityToken: nil)
        let second = AuthTokens(accessToken: "second", refreshToken: nil, expiresAt: nil, identityToken: nil)

        try await store.saveTokens(first)
        try await store.saveTokens(second)

        let loaded = try await store.loadTokens()
        #expect(loaded?.accessToken == "second")

        // Cleanup
        try await store.deleteTokens()
    }
}
