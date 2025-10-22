import Foundation

enum ConnectionDebug {
    private static let truthyValues: Set<String> = ["1", "true", "yes", "on"]

    static let isEnabled: Bool = {
        guard let rawValue = ProcessInfo.processInfo.environment["ECHO_CONNECTION_DEBUG"]?.lowercased() else {
            return false
        }
        return truthyValues.contains(rawValue)
    }()

    static func log(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        print("[ECHO_CONNECTION_DEBUG] \(message())")
    }
}
