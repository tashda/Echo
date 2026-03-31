import Foundation

/// Real auth backend that communicates with self-hosted Supabase (GoTrue).
/// Replaces StubAuthBackend for production use.
nonisolated struct SupabaseAuthBackend: AuthBackend {

    private let baseURL: URL
    private let anonKey: String

    init?(baseURL: URL? = SupabaseConfig.baseURL, anonKey: String? = SupabaseConfig.anonKey) {
        guard let baseURL, let anonKey else { return nil }
        self.baseURL = baseURL
        self.anonKey = anonKey
    }

    // MARK: - Apple Sign In

    func signInWithApple(identityToken: Data, authorizationCode: Data, fullName: PersonNameComponents?) async throws -> (AuthUser, AuthTokens) {
        guard let idToken = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidCredentials
        }

        // Exchange Apple identity token for a Supabase session
        var body: [String: Any] = [
            "provider": "apple",
            "id_token": idToken
        ]

        // Include name if available (Apple only sends it on first sign-in)
        if let fullName {
            var nameData: [String: String] = [:]
            if let given = fullName.givenName { nameData["full_name"] = given }
            if let family = fullName.familyName {
                nameData["full_name"] = [fullName.givenName, family].compactMap { $0 }.joined(separator: " ")
            }
            if !nameData.isEmpty {
                body["data"] = nameData
            }
        }

        let (data, response) = try await post(path: "/auth/v1/token", query: "grant_type=id_token", body: body)
        try checkResponse(response, data: data)

        let session = try decodeSession(from: data)
        let user = try await fetchUser(accessToken: session.accessToken, fallbackMethod: .apple)
        return (user, session)
    }

    // MARK: - Google Sign In (Supabase PKCE flow)

    func signInWithGoogle(authorizationCode: String, codeVerifier: String) async throws -> (AuthUser, AuthTokens) {
        // Exchange the Supabase PKCE auth code for a session
        let body: [String: Any] = [
            "auth_code": authorizationCode,
            "code_verifier": codeVerifier
        ]

        let (data, response) = try await post(path: "/auth/v1/token", query: "grant_type=pkce", body: body)
        try checkResponse(response, data: data)

        let session = try decodeSession(from: data)
        let user = try await fetchUser(accessToken: session.accessToken, fallbackMethod: .google)
        return (user, session)
    }

    // MARK: - Email OTP

    func sendOTP(email: String) async throws -> OTPSendResult {
        let body: [String: Any] = ["email": email]
        let (data, response) = try await post(path: "/auth/v1/otp", body: body)
        try checkResponse(response, data: data)

        // Supabase OTP endpoint returns minimal data on success (empty or {})
        return OTPSendResult(
            expiresAt: Date().addingTimeInterval(600),
            cooldownSeconds: 60
        )
    }

    func verifyOTP(email: String, code: String) async throws -> (AuthUser, AuthTokens) {
        let body: [String: Any] = [
            "email": email,
            "token": code,
            "type": "email"
        ]

        let (data, response) = try await post(path: "/auth/v1/verify", body: body)
        try checkResponse(response, data: data)

        let session = try decodeSession(from: data)
        let user = try await fetchUser(accessToken: session.accessToken, fallbackMethod: .email)
        return (user, session)
    }

    // MARK: - Session

    func refreshTokens(refreshToken: String) async throws -> AuthTokens {
        let body: [String: Any] = ["refresh_token": refreshToken]
        let (data, response) = try await post(path: "/auth/v1/token", query: "grant_type=refresh_token", body: body)
        try checkResponse(response, data: data)
        return try decodeSession(from: data)
    }

    func signOut(accessToken: String) async throws {
        let (data, response) = try await post(path: "/auth/v1/logout", body: nil, accessToken: accessToken)
        try checkResponse(response, data: data)
    }

    // MARK: - Account Management

    func deleteAccount(accessToken: String) async throws {
        let url = baseURL.appendingPathComponent("/auth/v1/user")
        var request = makeRequest(url: url, method: "DELETE")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkFailure("Invalid response")
        }
        try checkResponse(httpResponse, data: data)
    }

    func linkAccount(method: AuthMethod, accessToken: String, payload: Data) async throws -> AuthUser {
        // Supabase handles account linking through the identity endpoints
        // For now, fetch the current user — linking is done via the OAuth flow
        return try await fetchUser(accessToken: accessToken, fallbackMethod: method)
    }

    // MARK: - Private: Networking

    private func post(path: String, query: String? = nil, body: [String: Any]?, accessToken: String? = nil) async throws -> (Data, HTTPURLResponse) {
        var urlString = baseURL.absoluteString + path
        if let query { urlString += "?\(query)" }

        guard let url = URL(string: urlString) else {
            throw AuthError.networkFailure("Invalid URL: \(urlString)")
        }

        var request = makeRequest(url: url, method: "POST")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.networkFailure("Invalid response")
            }
            return (data, httpResponse)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkFailure(error.localizedDescription)
        }
    }

    private func makeRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        return request
    }

    // MARK: - Private: Response Handling

    private func checkResponse(_ response: HTTPURLResponse, data: Data) throws {
        guard (200...299).contains(response.statusCode) else {
            // Try to parse Supabase error response
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let message = errorJSON["msg"] as? String
                    ?? errorJSON["error_description"] as? String
                    ?? errorJSON["message"] as? String
                    ?? "Unknown error"
                let errorCode = errorJSON["error_code"] as? String ?? ""

                switch response.statusCode {
                case 401:
                    if errorCode == "session_not_found" || errorCode == "invalid_grant" {
                        throw AuthError.tokenExpired
                    }
                    throw AuthError.invalidCredentials
                case 422:
                    if message.lowercased().contains("otp") || errorCode == "otp_expired" {
                        throw AuthError.otpExpired
                    }
                    if errorCode == "otp_disabled" || message.lowercased().contains("invalid") {
                        throw AuthError.otpInvalid
                    }
                    throw AuthError.invalidCredentials
                case 429:
                    let retryAfter = Int(response.value(forHTTPHeaderField: "Retry-After") ?? "60") ?? 60
                    throw AuthError.rateLimited(retryAfterSeconds: retryAfter)
                default:
                    throw AuthError.unknown("\(response.statusCode): \(message)")
                }
            }
            throw AuthError.unknown("HTTP \(response.statusCode)")
        }
    }

    private func decodeSession(from data: Data) throws -> AuthTokens {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthError.unknown("Failed to decode session response")
        }

        guard let accessToken = json["access_token"] as? String else {
            throw AuthError.unknown("Missing access_token in response")
        }

        let refreshToken = json["refresh_token"] as? String
        let expiresIn = json["expires_in"] as? TimeInterval
        let expiresAt = expiresIn.map { Date().addingTimeInterval($0) }

        return AuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            identityToken: nil
        )
    }

    /// Fetch the authenticated user's profile from Supabase.
    private func fetchUser(accessToken: String, fallbackMethod: AuthMethod) async throws -> AuthUser {
        let url = baseURL.appendingPathComponent("/auth/v1/user")
        var request = makeRequest(url: url, method: "GET")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkFailure("Invalid response")
        }
        try checkResponse(httpResponse, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthError.unknown("Failed to decode user response")
        }

        let userID = json["id"] as? String ?? ""
        let email = json["email"] as? String
        let metadata = json["user_metadata"] as? [String: Any]
        let displayName = metadata?["full_name"] as? String
            ?? metadata?["name"] as? String

        // Determine auth method from provider
        let appMetadata = json["app_metadata"] as? [String: Any]
        let provider = appMetadata?["provider"] as? String
        let authMethod: AuthMethod = switch provider {
        case "apple": .apple
        case "google": .google
        case "email": .email
        default: fallbackMethod
        }

        // Determine linked methods from identities
        let identities = json["identities"] as? [[String: Any]] ?? []
        let linkedMethods: [AuthMethod] = identities.compactMap { identity in
            switch identity["provider"] as? String {
            case "apple": return .apple
            case "google": return .google
            case "email": return .email
            default: return nil
            }
        }.filter { $0 != authMethod }

        let createdAtString = json["created_at"] as? String
        let createdAt = createdAtString.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()

        return AuthUser(
            userID: userID,
            email: email,
            displayName: displayName,
            authMethod: authMethod,
            createdAt: createdAt,
            linkedMethods: linkedMethods
        )
    }
}
