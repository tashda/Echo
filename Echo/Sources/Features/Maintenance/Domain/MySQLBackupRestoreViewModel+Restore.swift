import Foundation
import MySQLKit

extension MySQLBackupRestoreViewModel {
    func executeRestore(customToolPath: String? = nil) async {
        guard canRestore else { return }
        guard let mysql = MySQLToolLocator.mysqlURL(customPath: customToolPath) else {
            restorePhase = .failed(message: "mysql client not found")
            return
        }

        let inputURL = URL(fileURLWithPath: inputPath)
        guard let inputHandle = FileHandle(forReadingAtPath: inputURL.path) else {
            restorePhase = .failed(message: "Unable to open backup file")
            return
        }
        defer { try? inputHandle.close() }

        let handle = activityEngine?.begin("Restore \(databaseName)", connectionSessionID: connectionSessionID)
        restorePhase = .running
        restoreOutput = []

        let trimmedCharacterSet = defaultCharacterSet.trimmingCharacters(in: .whitespacesAndNewlines)
        let command = (session as? MySQLSession)?.client.backupRestore.restoreCommand(
            host: connection.host,
            port: connection.port,
            username: resolvedUsername ?? connection.username,
            database: databaseName,
            inputPath: inputPath,
            defaultCharacterSet: trimmedCharacterSet.isEmpty ? nil : trimmedCharacterSet,
            force: forceRestore
        ) ?? [
            "mysql",
            "--host=\(connection.host)",
            "--port=\(connection.port)",
            "--user=\(resolvedUsername ?? connection.username)",
        ] + (trimmedCharacterSet.isEmpty ? [] : ["--default-character-set=\(trimmedCharacterSet)"])
            + (forceRestore ? ["--force"] : [])
            + [databaseName]

        do {
            let result = try await processRunner.run(
                executable: mysql,
                arguments: Array(command.dropFirst()).filter { $0 != "<" && $0 != inputPath },
                environment: processEnvironment(),
                standardInput: inputHandle
            )
            restoreOutput = result.stderrLines

            if result.exitCode == 0 {
                let message = "Restore completed from \(inputPath)"
                restorePhase = .completed(message: message)
                handle?.succeed()
            } else {
                let message = result.stderrLines.last ?? "mysql restore failed with exit code \(result.exitCode)"
                restorePhase = .failed(message: message)
                handle?.fail(message)
            }
        } catch {
            let message = error.localizedDescription
            restorePhase = .failed(message: message)
            handle?.fail(message)
        }
    }
}
