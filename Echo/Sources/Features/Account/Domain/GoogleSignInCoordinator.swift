import AuthenticationServices
import CryptoKit
import Foundation

/// Coordinates OAuth sign-in via Supabase's PKCE flow using ASWebAuthenticationSession.
/// Works for any Supabase-supported provider (Google, Apple, etc.).
final class GoogleSignInCoordinator {

    /// Result of the OAuth flow: the Supabase authorization code and the PKCE code verifier.
    struct OAuthResult: Sendable {
        let authorizationCode: String
        let codeVerifier: String
    }

    /// Triggers the Supabase OAuth flow for Google in a browser session and returns the auth code.
    func signIn() async throws -> OAuthResult {
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        guard let baseURL = SupabaseConfig.baseURL else {
            throw AuthError.unknown("Supabase is not configured.")
        }

        // Build the Supabase authorize URL — Supabase handles the Google redirect internally
        var components = URLComponents(string: baseURL.absoluteString + "/auth/v1/authorize")!
        components.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(name: "redirect_to", value: SupabaseConfig.redirectURI),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let authURL = components.url else {
            throw AuthError.unknown("Failed to construct Supabase auth URL.")
        }

        let callbackScheme = "dev.echodb.echo"

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

        // Supabase returns the auth code as a query parameter in the redirect
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
