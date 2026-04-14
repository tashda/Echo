import AuthenticationServices
import Foundation
import Supabase

/// Real auth backend using the Supabase Swift SDK.
/// Handles OAuth (Google, Apple), Email OTP, session management, and token refresh.
nonisolated struct SupabaseAuthBackend: AuthBackend {

    private let client: SupabaseClient

    init?() {
        guard let client = SupabaseConfig.sharedClient else { return nil }
        self.client = client
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

        // Apple only provides the user's full name on the first sign-in.
        // Save it to user metadata immediately so it persists in Supabase.
        if let fullName {
            var nameParts: [String] = []
            if let givenName = fullName.givenName { nameParts.append(givenName) }
            if let familyName = fullName.familyName { nameParts.append(familyName) }
            let fullNameString = nameParts.joined(separator: " ")

            if !fullNameString.isEmpty {
                _ = try? await client.auth.update(
                    user: UserAttributes(
                        data: [
                            "full_name": .string(fullNameString),
                            "given_name": .string(fullName.givenName ?? ""),
                            "family_name": .string(fullName.familyName ?? ""),
                        ]
                    )
                )
            }
        }

        // Re-fetch the session to pick up the updated metadata
        let currentUser = try await client.auth.session.user
        let user = mapUser(from: currentUser, fallbackMethod: .apple)
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
    /// Forces the Google account picker so users can choose or switch accounts.
    func signInWithGoogleOAuth() async throws -> (AuthUser, AuthTokens) {
        let session = try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: SupabaseConfig.redirectURI),
            queryParams: [(name: "prompt", value: "select_account")]
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
        do {
            let response: DeleteAccountResponse = try await client.functions.invoke(
                "delete-account",
                options: FunctionInvokeOptions(
                    body: DeleteAccountRequest()
                )
            )

            if response.success != true {
                throw AuthError.unknown(response.error ?? "Delete account failed.")
            }
        } catch {
            throw mapDeleteAccountError(error)
        }
    }

    func linkAccount(method: AuthMethod, accessToken: String, payload: Data) async throws -> AuthUser {
        let session = try await client.auth.session
        return mapUser(from: session.user, fallbackMethod: method)
    }

    func updateDisplayName(_ name: String) async throws -> AuthUser {
        try await client.auth.update(
            user: UserAttributes(
                data: ["full_name": .string(name)]
            )
        )
        let updatedUser = try await client.auth.session.user
        return mapUser(from: updatedUser, fallbackMethod: .apple)
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

private extension SupabaseAuthBackend {
    struct DeleteAccountRequest: Encodable {}

    struct DeleteAccountResponse: Decodable {
        let success: Bool
        let error: String?
    }

    func mapDeleteAccountError(_ error: any Error) -> AuthError {
        if let functionsError = error as? FunctionsError {
            switch functionsError {
            case .relayError:
                return .unknown(
                    "Delete Account failed because the Supabase Edge Function relay could not reach 'delete-account'."
                )
            case .httpError(let code, let data):
                let body = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if code == 404 || code == 503 {
                    return .unknown(
                        "Delete Account requires a deployed Supabase Edge Function named 'delete-account'."
                    )
                }

                if let body, !body.isEmpty, let serverMessage = extractDeleteAccountMessage(from: body) {
                    return .unknown(serverMessage)
                }

                return .unknown("Delete Account failed with HTTP \(code).")
            }
        }

        let message = String(describing: error)
        if message.localizedCaseInsensitiveContains("delete-account") {
            return .unknown(
                "Delete Account requires a deployed Supabase Edge Function named 'delete-account'."
            )
        }
        return .unknown(message)
    }

    func extractDeleteAccountMessage(from body: String) -> String? {
        if let data = body.data(using: .utf8),
           let payload = try? JSONDecoder().decode(DeleteAccountResponse.self, from: data),
           let error = payload.error,
           !error.isEmpty {
            return error
        }

        if body.isEmpty {
            return nil
        }

        return body
    }
}
