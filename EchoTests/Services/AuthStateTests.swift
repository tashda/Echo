import Testing
import Foundation
@testable import Echo

@Suite("AuthState")
struct AuthStateTests {

    // MARK: - Helpers

    /// Creates an AuthState backed by the stub backend and a fresh token store.
    private func makeAuthState() -> AuthState {
        AuthState(backend: StubAuthBackend(), tokenStore: AuthTokenStore())
    }

    // MARK: - Initial State

    @Test func initialStateIsSignedOut() {
        let state = makeAuthState()
        #expect(state.currentUser == nil)
        #expect(!state.isSignedIn)
        #expect(!state.isLoading)
        #expect(state.error == nil)
        #expect(!state.isAwaitingOTPVerification)
    }

    // MARK: - Sign In with Apple

    @Test func signInWithAppleSetsCurrentUser() async {
        let state = makeAuthState()
        let token = Data("fake-identity-token".utf8)
        let code = Data("fake-auth-code".utf8)
        var name = PersonNameComponents()
        name.givenName = "Test"
        name.familyName = "User"

        await state.signInWithApple(identityToken: token, authorizationCode: code, fullName: name)

        #expect(state.isSignedIn)
        #expect(state.currentUser?.authMethod == .apple)
        #expect(state.currentUser?.displayName == "Test User")
        #expect(state.error == nil)
    }

    @Test func signInWithAppleNilNameStillSucceeds() async {
        let state = makeAuthState()
        let token = Data("token".utf8)
        let code = Data("code".utf8)

        await state.signInWithApple(identityToken: token, authorizationCode: code, fullName: nil)

        #expect(state.isSignedIn)
        #expect(state.currentUser?.authMethod == .apple)
    }

    // MARK: - Sign In with Google

    @Test func signInWithGoogleSetsCurrentUser() async {
        let state = makeAuthState()

        await state.signInWithGoogle(authorizationCode: "fake-code", codeVerifier: "fake-verifier")

        #expect(state.isSignedIn)
        #expect(state.currentUser?.authMethod == .google)
        #expect(state.currentUser?.email == "user@gmail.com")
        #expect(state.error == nil)
    }

    // MARK: - Email OTP

    @Test func sendOTPSetsAwaitingState() async {
        let state = makeAuthState()

        await state.sendOTP(email: "test@example.com")

        #expect(state.isAwaitingOTPVerification)
        #expect(state.otpExpiresAt != nil)
        #expect(state.otpCooldownEnd != nil)
        #expect(state.error == nil)
    }

    @Test func verifyOTPWithValidCodeSignsIn() async {
        let state = makeAuthState()

        await state.sendOTP(email: "test@example.com")
        await state.verifyOTP(email: "test@example.com", code: "123456")

        #expect(state.isSignedIn)
        #expect(state.currentUser?.authMethod == .email)
        #expect(state.currentUser?.email == "test@example.com")
        #expect(!state.isAwaitingOTPVerification)
    }

    @Test func verifyOTPWithInvalidCodeSetsError() async {
        let state = makeAuthState()

        await state.sendOTP(email: "test@example.com")
        await state.verifyOTP(email: "test@example.com", code: "abc")

        #expect(!state.isSignedIn)
        #expect(state.error != nil)
    }

    @Test func cancelOTPResetsState() async {
        let state = makeAuthState()

        await state.sendOTP(email: "test@example.com")
        state.cancelOTP()

        #expect(!state.isAwaitingOTPVerification)
        #expect(state.otpExpiresAt == nil)
        #expect(state.otpCooldownEnd == nil)
    }

    // MARK: - Sign Out

    @Test func signOutClearsUser() async {
        let state = makeAuthState()
        await state.signInWithGoogle(authorizationCode: "code", codeVerifier: "verifier")
        #expect(state.isSignedIn)

        await state.signOut()

        #expect(!state.isSignedIn)
        #expect(state.currentUser == nil)
    }

    // MARK: - Delete Account

    @Test func deleteAccountClearsUser() async throws {
        let state = makeAuthState()
        await state.signInWithGoogle(authorizationCode: "code", codeVerifier: "verifier")
        #expect(state.isSignedIn)

        try await state.deleteAccount()

        #expect(!state.isSignedIn)
        #expect(state.currentUser == nil)
    }

    @Test func deleteAccountThrowsWhenNotSignedIn() async {
        let state = makeAuthState()

        await #expect(throws: AuthError.self) {
            try await state.deleteAccount()
        }
    }

    // MARK: - Error Reporting

    @Test func setErrorUpdatesErrorProperty() {
        let state = makeAuthState()

        state.setError(.invalidCredentials)

        #expect(state.error != nil)
    }

    @Test func newOperationClearsError() async {
        let state = makeAuthState()
        state.setError(.invalidCredentials)
        #expect(state.error != nil)

        await state.signInWithGoogle(authorizationCode: "code", codeVerifier: "verifier")

        #expect(state.error == nil)
    }
}
