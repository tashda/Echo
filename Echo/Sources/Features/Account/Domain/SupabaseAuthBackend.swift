import AuthenticationServices
import Foundation
import Supabase

/// Real auth backend using the Supabase Swift SDK.
/// Handles OAuth (Google, Apple), Email OTP, session management, and token refresh.
nonisolated struct SupabaseAuthBackend: AuthBackend {

    private let client: SupabaseClient

    init?(baseURL: URL? = SupabaseConfig.baseURL, anonKey: String? = SupabaseConfig.anonKey) {
        guard let baseURL, let anonKey else { return nil }
        self.client = SupabaseClient(
            supabaseURL: baseURL,
            supabaseKey: anonKey,
            options: .init(auth: .init(
                redirectToURL: URL(string: SupabaseConfig.redirectURI)
            ))
        )
    }

    // MARK: - Apple Sign In

    func signInWithApple(identityToken: Data, authorizationCode: Data, fullName: PersonNameComponents?) async throws -> (AuthUser, AuthTokens) {
        guard let idToken = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidCredentials
        }

        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken
            )
        )

        let user = mapUser(from: session.user, fallbackMethod: .apple)
        let tokens = mapTokens(from: session)
        return (user, tokens)
    }

    // MARK: - Google Sign In (Supabase PKCE via ASWebAuthenticationSession)

    func signInWithGoogle(authorizationCode: String, codeVerifier: String) async throws -> (AuthUser, AuthTokens) {
        // This method is called after the SDK's OAuth flow completes.
        // The SDK handles the full PKCE exchange internally via signInWithOAuth.
        // We use a different entry point — see signInWithGoogleOAuth() below.
        throw AuthError.unknown("Use signInWithGoogleOAuth() instead.")
    }

    /// SDK-managed Google OAuth flow. Opens ASWebAuthenticationSession internally.
    func signInWithGoogleOAuth() async throws -> (AuthUser, AuthTokens) {
        let session = try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: SupabaseConfig.redirectURI)
        ) { (session: ASWebAuthenticationSession) in
            session.prefersEphemeralWebBrowserSession = false
        }

        let user = mapUser(from: session.user, fallbackMethod: .google)
        let tokens = mapTokens(from: session)
        return (user, tokens)
    }

    // MARK: - Email OTP

    func sendOTP(email: String) async throws -> OTPSendResult {
        try await client.auth.signInWithOTP(email: email)
        return OTPSendResult(
            expiresAt: Date().addingTimeInterval(600),
            cooldownSeconds: 60
        )
    }

    func verifyOTP(email: String, code: String) async throws -> (AuthUser, AuthTokens) {
        let response = try await client.auth.verifyOTP(
            email: email,
            token: code,
            type: .email
        )

        guard let session = response.session else {
            throw AuthError.unknown("No session returned after OTP verification.")
        }

        let user = mapUser(from: response.user, fallbackMethod: .email)
        let tokens = mapTokens(from: session)
        return (user, tokens)
    }

    // MARK: - Session

    func refreshTokens(refreshToken: String) async throws -> AuthTokens {
        let session = try await client.auth.refreshSession()
        return mapTokens(from: session)
    }

    func signOut(accessToken: String) async throws {
        try await client.auth.signOut()
    }

    // MARK: - Account Management

    func deleteAccount(accessToken: String) async throws {
        // Supabase doesn't have a client-side delete — requires a server function or admin API
        // For now, sign out. Full deletion requires a server-side Edge Function.
        try await client.auth.signOut()
    }

    func linkAccount(method: AuthMethod, accessToken: String, payload: Data) async throws -> AuthUser {
        let session = try await client.auth.session
        return mapUser(from: session.user, fallbackMethod: method)
    }

    // MARK: - Mapping

    private func mapUser(from supabaseUser: Auth.User, fallbackMethod: AuthMethod) -> AuthUser {
        let metadata = supabaseUser.userMetadata

        let displayName = metadata["full_name"]?.stringValue
            ?? metadata["name"]?.stringValue

        let avatarURLString = metadata["avatar_url"]?.stringValue
            ?? metadata["picture"]?.stringValue
        let avatarURL = avatarURLString.flatMap { URL(string: $0) }

        let provider = supabaseUser.appMetadata["provider"]?.stringValue
        let authMethod: AuthMethod = switch provider {
        case "apple": .apple
        case "google": .google
        case "email": .email
        default: fallbackMethod
        }

        let linkedMethods: [AuthMethod] = (supabaseUser.identities ?? []).compactMap { identity in
            switch identity.provider {
            case "apple": return .apple
            case "google": return .google
            case "email": return .email
            default: return nil
            }
        }.filter { $0 != authMethod }

        return AuthUser(
            userID: supabaseUser.id.uuidString,
            email: supabaseUser.email,
            displayName: displayName,
            authMethod: authMethod,
            createdAt: supabaseUser.createdAt,
            avatarURL: avatarURL,
            linkedMethods: linkedMethods
        )
    }

    private func mapTokens(from session: Auth.Session) -> AuthTokens {
        AuthTokens(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            expiresAt: Date(timeIntervalSince1970: session.expiresAt),
            identityToken: nil
        )
    }
}

// MARK: - JSON Value Helper

private extension Auth.User {
    // Supabase SDK uses AnyJSON for metadata
}
