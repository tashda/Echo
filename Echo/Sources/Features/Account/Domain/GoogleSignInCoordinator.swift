import AuthenticationServices
import CryptoKit
import Foundation

/// Coordinates Sign in with Google via OAuth 2.0 PKCE using ASWebAuthenticationSession.
final class GoogleSignInCoordinator {

    /// Google OAuth configuration.
    /// Replace these with real values when the backend is ready.
    private enum Config {
        static let clientID = "GOOGLE_CLIENT_ID_PLACEHOLDER"
        static let redirectURI = "dk.tippr.echo:/oauth2callback"
        static let authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
        static let scopes = "openid email profile"
    }

    /// Result of the OAuth flow: the authorization code and the PKCE code verifier.
    struct OAuthResult: Sendable {
        let authorizationCode: String
        let codeVerifier: String
    }

    /// Triggers the Google OAuth flow in a browser session and returns the auth code.
    func signIn() async throws -> OAuthResult {
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        var components = URLComponents(string: Config.authorizationEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Config.clientID),
            URLQueryItem(name: "redirect_uri", value: Config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Config.scopes),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let authURL = components.url else {
            throw AuthError.unknown("Failed to construct Google auth URL.")
        }

        let callbackScheme = "dk.tippr.echo"

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, any Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { url, error in
                if let error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: AuthError.cancelled)
                    } else {
                        continuation.resume(throwing: AuthError.unknown(error.localizedDescription))
                    }
                    return
                }
                guard let url else {
                    continuation.resume(throwing: AuthError.unknown("No callback URL received."))
                    return
                }
                continuation.resume(returning: url)
            }

            session.prefersEphemeralWebBrowserSession = true
            session.start()
        }

        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw AuthError.unknown("No authorization code in callback URL.")
        }

        return OAuthResult(authorizationCode: code, codeVerifier: codeVerifier)
    }

    // MARK: - PKCE

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
