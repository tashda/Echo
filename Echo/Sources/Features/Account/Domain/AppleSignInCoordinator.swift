import AuthenticationServices

/// Coordinates Sign in with Apple using AuthenticationServices.
/// Wraps ASAuthorizationController in an async interface.
final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate {
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, any Error>?
    private var controller: ASAuthorizationController?

    /// Triggers the Sign in with Apple flow and returns the credential.
    func signIn() async throws -> ASAuthorizationAppleIDCredential {
        guard continuation == nil else {
            throw AuthError.unknown("Apple sign-in is already in progress.")
        }

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        self.controller = controller

        return try await withCheckedThrowingContinuation { continuation in
            register(continuation)
            controller.performRequests()
        }
    }

    // MARK: - ASAuthorizationControllerDelegate

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            resumeFromDelegate(with: .failure(AuthError.unknown("Unexpected credential type.")))
            return
        }
        resumeFromDelegate(with: .success(credential))
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: any Error
    ) {
        resumeFromDelegate(with: .failure(Self.mapAuthError(error)))
    }

    func register(_ continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, any Error>) {
        self.continuation = continuation
    }

    func complete(with result: Result<ASAuthorizationAppleIDCredential, any Error>) {
        let continuation = self.continuation
        self.continuation = nil
        controller = nil

        switch result {
        case .success(let credential):
            continuation?.resume(returning: credential)
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
    }

    nonisolated static func mapAuthError(_ error: any Error) -> AuthError {
        if let asError = error as? ASAuthorizationError, asError.code == .canceled {
            return .cancelled
        }
        return .unknown(error.localizedDescription)
    }

    nonisolated private func resumeFromDelegate(
        with result: Result<ASAuthorizationAppleIDCredential, any Error>
    ) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                complete(with: result)
            }
            return
        }

        Task(priority: .userInitiated) { @MainActor in
            complete(with: result)
        }
    }
}
