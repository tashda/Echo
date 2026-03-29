import AuthenticationServices

/// Coordinates Sign in with Apple using AuthenticationServices.
/// Wraps ASAuthorizationController in an async interface.
final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate {
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, any Error>?

    /// Triggers the Sign in with Apple flow and returns the credential.
    func signIn() async throws -> ASAuthorizationAppleIDCredential {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    // MARK: - ASAuthorizationControllerDelegate

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            Task { @MainActor in
                continuation?.resume(throwing: AuthError.unknown("Unexpected credential type."))
                continuation = nil
            }
            return
        }
        Task { @MainActor in
            continuation?.resume(returning: credential)
            continuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: any Error
    ) {
        let authError: AuthError
        if let asError = error as? ASAuthorizationError, asError.code == .canceled {
            authError = .cancelled
        } else {
            authError = .unknown(error.localizedDescription)
        }
        Task { @MainActor in
            continuation?.resume(throwing: authError)
            continuation = nil
        }
    }
}
