import Foundation
import MySQLKit

extension MySQLBackupRestoreViewModel {
    func executeConfiguredBackup(customToolPath: String? = nil) async {
        guard canBackup else { return }
        guard let mysqlSession = session as? MySQLSession else {
            backupPhase = .failed(message: "Not a MySQL session")
            return
        }
        guard let mysqldump = MySQLToolLocator.mysqldumpURL(customPath: customToolPath) else {
            backupPhase = .failed(message: "mysqldump not found")
            return
        }

        let handle = activityEngine?.begin("Backup \(databaseName)", connectionSessionID: connectionSessionID)
        backupPhase = .running
        backupOutput = []

        let options = MySQLDumpOptions(
            includeRoutines: includeRoutines,
            includeTriggers: includeTriggers,
            includeEvents: includeEvents,
            includeData: includeData,
            includeSchema: includeSchema,
            singleTransaction: singleTransaction,
            lockTables: lockTables,
            compressConnection: compressConnection,
            useExtendedInsert: useExtendedInsert,
            tables: backupTableList
        )
        let tls: MySQLToolTLS?
        do {
            tls = try await toolTLS(for: mysqldump)
        } catch {
            let message = error.localizedDescription
            backupPhase = .failed(message: message)
            handle?.fail(message)
            return
        }
        let command = mysqlSession.client.backupRestore.backupCommand(
            host: connection.host,
            port: connection.port,
            username: resolvedUsername ?? connection.username,
            database: databaseName,
            outputPath: outputPath,
            options: options,
            tlsArguments: tls?.arguments ?? []
        )

        do {
            let result = try await processRunner.run(
                executable: mysqldump,
                arguments: Array(command.dropFirst()),
                environment: processEnvironment()
            )
            withExtendedLifetime(tls) {}
            backupOutput = result.stderrLines

            if result.exitCode == 0 {
                let message = "Backup completed at \(outputPath)"
                backupPhase = .completed(message: message)
                handle?.succeed()
                notificationEngine?.post(.backupCompleted(database: databaseName, destination: outputPath))
            } else {
                let message = result.stderrLines.last ?? "mysqldump failed with exit code \(result.exitCode)"
                backupPhase = .failed(message: message)
                handle?.fail(message)
                notificationEngine?.post(.backupFailed(database: databaseName, reason: message))
            }
        } catch {
            let message = error.localizedDescription
            backupPhase = .failed(message: message)
            handle?.fail(message)
            notificationEngine?.post(.backupFailed(database: databaseName, reason: message))
        }
    }
}
