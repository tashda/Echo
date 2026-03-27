import Foundation

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

        let arguments = [
            "--host=\(connection.host)",
            "--port=\(connection.port)",
            "--user=\(resolvedUsername ?? connection.username)",
        ] + (forceRestore ? ["--force"] : []) + [databaseName]

        do {
            let result = try await processRunner.run(
                executable: mysql,
                arguments: arguments,
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
