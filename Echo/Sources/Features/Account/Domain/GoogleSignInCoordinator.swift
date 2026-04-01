import AppKit
import AuthenticationServices
import CryptoKit
import Foundation

/// Coordinates OAuth sign-in via Supabase's PKCE flow using ASWebAuthenticationSession.
nonisolated final class GoogleSignInCoordinator: NSObject,
                                                 ASWebAuthenticationPresentationContextProviding,
                                                 Sendable {

    struct OAuthResult: Sendable {
        let authorizationCode: String
        let codeVerifier: String
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
        }
    }

    func signIn() async throws -> OAuthResult {
        guard let baseURL = SupabaseConfig.baseURL else {
            throw AuthError.unknown("Supabase is not configured.")
        }

        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        let redirect = SupabaseConfig.redirectURI
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? SupabaseConfig.redirectURI

        let urlString = "\(baseURL.absoluteString)/auth/v1/authorize?provider=google&redirect_to=\(redirect)&code_challenge=\(codeChallenge)&code_challenge_method=S256"

        guard let authURL = URL(string: urlString) else {
            throw AuthError.unknown("Failed to construct auth URL.")
        }

        return try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<OAuthResult, any Error>) in
            // Must create and start the session on the main thread
            DispatchQueue.main.async { [self] in
                let session = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: "dev.echodb.echo"
                ) { callbackURL, error in
                    if let error {
                        let nsError = error as NSError
                        if nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                            continuation.resume(throwing: AuthError.cancelled)
                        } else {
                            continuation.resume(throwing: AuthError.unknown("Authentication failed."))
                        }
                        return
                    }

                    guard let callbackURL,
                          let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                          let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                        continuation.resume(throwing: AuthError.unknown("No authorization code received."))
                        return
                    }

                    continuation.resume(returning: OAuthResult(
                        authorizationCode: code,
                        codeVerifier: codeVerifier
                    ))
                }

                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false

                if !session.start() {
                    continuation.resume(throwing: AuthError.unknown("Could not start authentication session."))
                }
            }
        }
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
