import Foundation

/// The method used to authenticate with Echo's cloud service.
enum AuthMethod: String, Codable, Sendable, Identifiable, CaseIterable {
    case apple
    case google
    case email

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        case .email: return "Email"
        }
    }

    var systemImage: String {
        switch self {
        case .apple: return "apple.logo"
        case .google: return "globe"
        case .email: return "envelope"
        }
    }
}

/// Represents the currently signed-in user.
struct AuthUser: Codable, Sendable, Equatable {
    let userID: String
    let email: String?
    let displayName: String?
    let authMethod: AuthMethod
    let createdAt: Date

    /// Linked auth methods beyond the primary sign-in.
    var linkedMethods: [AuthMethod]
}

/// Tokens returned by the auth backend after successful authentication.
struct AuthTokens: Codable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let identityToken: String?
}

/// Result of an OTP send request.
struct OTPSendResult: Sendable {
    let expiresAt: Date
    let cooldownSeconds: Int
}

/// Errors from the auth layer.
enum AuthError: Error, LocalizedError, Sendable {
    case notAuthenticated
    case invalidCredentials
    case tokenExpired
    case rateLimited(retryAfterSeconds: Int)
    case otpExpired
    case otpInvalid
    case networkFailure(String)
    case cancelled
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not signed in."
        case .invalidCredentials: return "Invalid credentials."
        case .tokenExpired: return "Session expired. Please sign in again."
        case .rateLimited(let seconds): return "Too many attempts. Try again in \(seconds) seconds."
        case .otpExpired: return "The verification code has expired. Please request a new one."
        case .otpInvalid: return "Invalid verification code."
        case .networkFailure(let message): return "Network error: \(message)"
        case .cancelled: return "Authentication was cancelled."
        case .unknown(let message): return message
        }
    }
}
