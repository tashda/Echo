import Foundation
import OSLog

/// Launches the native psql CLI in Terminal.app, pre-connected to a specific database.
nonisolated struct PostgresTerminalLauncher {

    private static let logger = Logger(subsystem: "com.echo.app", category: "PostgresTerminalLauncher")

    /// Opens Terminal.app with psql connected to the given database.
    /// Uses `PostgresToolLocator` to find the psql binary on the user's system.
    ///
    /// - Parameters:
    ///   - host: The database server hostname.
    ///   - port: The database server port.
    ///   - username: The username for authentication.
    ///   - database: The database to connect to.
    ///   - customToolPath: Optional custom directory containing psql.
    /// - Returns: `true` if Terminal was opened, `false` if psql was not found.
    @discardableResult
    static func openInTerminal(
        host: String,
        port: Int,
        username: String,
        database: String,
        customToolPath: String? = nil
    ) async -> Bool {
        guard let psqlURL = PostgresToolLocator.psqlURL(customPath: customToolPath) else {
            logger.warning("psql binary not found on this system")
            return false
        }

        let psqlPath = psqlURL.path

        // Build the psql command with connection arguments.
        // Quote all arguments to handle special characters.
        var parts = [shellQuote(psqlPath)]
        parts.append("-h \(shellQuote(host))")
        parts.append("-p \(shellQuote(String(port)))")
        parts.append("-U \(shellQuote(username))")
        parts.append(shellQuote(database))

        let command = parts.joined(separator: " ")

        // Use AppleScript to open Terminal.app and run the command.
        // This is the standard macOS pattern for launching CLI tools from GUI apps.
        let script = """
        tell application "Terminal"
            activate
            do script "\(command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))"
        end tell
        """

        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?
        appleScript?.executeAndReturnError(&errorDict)

        if let error = errorDict {
            logger.error("Failed to open Terminal: \(error)")
            return false
        }

        logger.info("Opened psql in Terminal for \(username)@\(host):\(port)/\(database)")
        return true
    }

    private static func shellQuote(_ value: String) -> String {
        if value.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "." || $0 == "/" }) {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
