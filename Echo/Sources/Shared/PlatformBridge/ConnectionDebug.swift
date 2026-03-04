import Foundation

enum ConnectionDebug {
    nonisolated static var isEnabled: Bool {
        guard let rawValue = ProcessInfo.processInfo.environment["ECHO_CONNECTION_DEBUG"]?.lowercased() else {
            return false
        }
        return ["1", "true", "yes", "on"].contains(rawValue)
    }

    nonisolated static func log(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        print("[ECHO_CONNECTION_DEBUG] \(message())")
    }
}
