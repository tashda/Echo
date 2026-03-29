import Foundation
import SQLServerKit

// MARK: - Shrink Option Choice

enum ShrinkOptionChoice: String, CaseIterable, Identifiable {
    case defaultBehavior = "Default"
    case noTruncate = "No Truncate"
    case truncateOnly = "Truncate Only"

    var id: String { rawValue }
}

extension MSSQLMaintenanceViewModel {

    func refreshHealth() async {
        do {
            if let db = selectedDatabase {
                _ = try await session.sessionForDatabase(db)
            }
            healthStats = try await session.getDatabaseHealth()
            healthPermissionError = nil
        } catch {
            healthStats = nil
            let msg = "\(error)"
            if msg.contains("permission was denied") || msg.contains("not have permission") {
                healthPermissionError = "Health statistics require access to the master database (sys.master_files)."
            } else {
                healthPermissionError = nil
                notificationEngine?.post(category: .maintenanceFailed, message: "Failed to load health stats: \(error.localizedDescription)")
            }
        }
    }

    func runIntegrityCheck() async {
        let db = selectedDatabase ?? "database"
        isCheckingIntegrity = true
        defer { isCheckingIntegrity = false }
        let handle = activityEngine?.begin("Integrity check \(db)", connectionSessionID: connectionSessionID)
        logOperation("Executing: DBCC CHECKDB(N'\(db)')", category: "Integrity Check")
        do {
            let result = try await session.checkDatabaseIntegrity()
            for msg in result.messages {
                logOperation(msg, severity: result.succeeded ? .info : .warning, category: "Integrity Check")
            }
            let summary = result.succeeded
                ? "Integrity check completed successfully for \(db)."
                : "Integrity check finished with issues: \(result.messages.first ?? "Unknown")"
            logOperation(summary, severity: result.succeeded ? .success : .warning, category: "Integrity Check")
            notificationEngine?.post(category: .maintenanceCompleted, message: summary)
            if result.succeeded { handle?.succeed() } else { handle?.fail(summary) }
            await refreshHealth()
        } catch {
            logOperation("Integrity check failed: \(error.localizedDescription)", severity: .error, category: "Integrity Check")
            notificationEngine?.post(category: .maintenanceFailed, message: "Integrity check failed: \(error.localizedDescription)")
            handle?.fail(error.localizedDescription)
        }
    }

    func runShrink() async {
        let db = selectedDatabase ?? "database"
        let sizeBefore = healthStats?.sizeMB ?? 0
        isShrinking = true
        defer { isShrinking = false }
        let handle = activityEngine?.begin("Shrink \(db)", connectionSessionID: connectionSessionID)
        logOperation("Executing: DBCC SHRINKDATABASE(N'\(db)')", category: "Shrink Database")
        do {
            _ = try await session.shrinkDatabase()
            await refreshHealth()
            let sizeAfter = healthStats?.sizeMB ?? 0
            let summary = "Database shrunk from \(String(format: "%.1f", sizeBefore)) MB to \(String(format: "%.1f", sizeAfter)) MB."
            logOperation(summary, severity: .success, category: "Shrink Database")
            notificationEngine?.post(category: .maintenanceCompleted, message: summary)
            handle?.succeed()
        } catch {
            logOperation("Shrink failed: \(error.localizedDescription)", severity: .error, category: "Shrink Database")
            notificationEngine?.post(category: .maintenanceFailed, message: "Shrink failed: \(error.localizedDescription)")
            handle?.fail(error.localizedDescription)
        }
    }

    func runShrinkWithOptions() async {
        let db = selectedDatabase ?? "database"
        let sizeBefore = healthStats?.sizeMB ?? 0
        isShrinking = true
        defer { isShrinking = false }
        let handle = activityEngine?.begin("Shrink \(db) (\(shrinkOption.rawValue))", connectionSessionID: connectionSessionID)
        let truncateOnly = shrinkOption == .truncateOnly
        logOperation("Executing: DBCC SHRINKDATABASE(N'\(db)', \(shrinkTargetPercent), \(shrinkOption.rawValue))", category: "Shrink Database")
        do {
            _ = try await session.shrinkDatabase(targetPercent: shrinkTargetPercent, truncateOnly: truncateOnly)
            await refreshHealth()
            let sizeAfter = healthStats?.sizeMB ?? 0
            let summary = "Database shrunk from \(String(format: "%.1f", sizeBefore)) MB to \(String(format: "%.1f", sizeAfter)) MB."
            logOperation(summary, severity: .success, category: "Shrink Database")
            notificationEngine?.post(category: .maintenanceCompleted, message: summary)
            handle?.succeed()
        } catch {
            logOperation("Shrink failed: \(error.localizedDescription)", severity: .error, category: "Shrink Database")
            notificationEngine?.post(category: .maintenanceFailed, message: "Shrink failed: \(error.localizedDescription)")
            handle?.fail(error.localizedDescription)
        }
    }

    func runShrinkFile() async {
        guard !shrinkFileName.isEmpty else { return }
        let db = selectedDatabase ?? "database"
        isShrinkingFile = true
        defer { isShrinkingFile = false }
        let handle = activityEngine?.begin("Shrink file \(shrinkFileName) in \(db)", connectionSessionID: connectionSessionID)
        logOperation("Executing: DBCC SHRINKFILE(N'\(shrinkFileName)', \(shrinkFileTargetMB))", category: "Shrink File")
        do {
            let result = try await session.shrinkFile(fileName: shrinkFileName, targetSizeMB: shrinkFileTargetMB)
            let summary = result.succeeded
                ? "File '\(shrinkFileName)' shrunk successfully to target \(shrinkFileTargetMB) MB."
                : "Shrink file finished with issues: \(result.messages.first ?? "Unknown")"
            logOperation(summary, severity: result.succeeded ? .success : .warning, category: "Shrink File")
            notificationEngine?.post(category: .maintenanceCompleted, message: summary)
            if result.succeeded { handle?.succeed() } else { handle?.fail(summary) }
            await refreshHealth()
        } catch {
            logOperation("Shrink file failed: \(error.localizedDescription)", severity: .error, category: "Shrink File")
            notificationEngine?.post(category: .maintenanceFailed, message: "Shrink file failed: \(error.localizedDescription)")
            handle?.fail(error.localizedDescription)
        }
    }

    func loadDatabaseFiles() async {
        isLoadingFiles = true
        defer { isLoadingFiles = false }
        do {
            databaseFiles = try await session.listDatabaseFiles()
            if shrinkFileName.isEmpty, let first = databaseFiles.first {
                shrinkFileName = first.name
            }
        } catch {
            databaseFiles = []
        }
    }
}
