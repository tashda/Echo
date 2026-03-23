import Foundation

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
}
