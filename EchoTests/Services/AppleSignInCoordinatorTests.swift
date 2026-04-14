import AuthenticationServices
import Foundation
import Testing
@testable import Echo

@Suite("AppleSignInCoordinator")
struct AppleSignInCoordinatorTests {

    @Test func mapAuthErrorReturnsCancelledForCanceledAuthorization() {
        let error = ASAuthorizationError(.canceled)

        let mapped = AppleSignInCoordinator.mapAuthError(error)

        #expect(mapped == .cancelled)
    }

    @Test func mapAuthErrorReturnsUnknownForOtherErrors() {
        let error = NSError(domain: "AppleSignInCoordinatorTests", code: 42, userInfo: [
            NSLocalizedDescriptionKey: "Unexpected failure"
        ])

        let mapped = AppleSignInCoordinator.mapAuthError(error)

        switch mapped {
        case .unknown(let message):
            #expect(message == "Unexpected failure")
        default:
            Issue.record("Expected unknown auth error, got \(mapped)")
        }
    }
}
