import Foundation
import MySQLKit

extension MySQLProcessRunner {
    /// Whose tool this is (MySQL's or MariaDB's), from its `--version` line: their TLS options differ.
    func flavor(of tool: URL) async -> MySQLToolFlavor {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = tool
            process.arguments = ["--version"]
            let output = Pipe()
            process.standardOutput = output
            process.standardError = Pipe()
            process.terminationHandler = { _ in
                let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                continuation.resume(returning: MySQLToolFlavor(versionOutput: text))
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(returning: MySQLToolFlavor(versionOutput: tool.lastPathComponent))
            }
        }
    }
}
