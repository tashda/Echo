import Foundation

public struct ConnectionTestResult: Sendable {
    public let isSuccessful: Bool
    public let message: String
    public let responseTime: TimeInterval?
    public let serverVersion: String?

    public init(isSuccessful: Bool, message: String, responseTime: TimeInterval?, serverVersion: String?) {
        self.isSuccessful = isSuccessful
        self.message = message
        self.responseTime = responseTime
        self.serverVersion = serverVersion
    }

    public var success: Bool { isSuccessful }

    public var details: String {
        var parts: [String] = []
        if let responseTime {
            parts.append(String(format: "%.3fs", responseTime))
        }
        if let serverVersion, !serverVersion.isEmpty {
            parts.append(serverVersion)
        }
        return parts.isEmpty ? message : parts.joined(separator: " • ")
    }
}
