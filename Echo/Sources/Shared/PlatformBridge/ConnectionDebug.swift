import OSLog

enum ConnectionDebug {
    nonisolated static func log(_ message: String) {
        Logger.connection.debug("\(message)")
    }
}
