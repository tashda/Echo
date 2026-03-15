import SwiftUI
import PostgresKit
import SQLServerKit

extension ObjectBrowserSidebarView {

    // MARK: - PostgreSQL Maintenance

    enum PostgresMaintenanceOp {
        case vacuum, vacuumFull, vacuumAnalyze, analyze, reindex
    }

    func runPostgresMaintenance(session: ConnectionSession, database: String, operation: PostgresMaintenanceOp) async {
        guard let pgSession = session.session as? PostgresSession else { return }

        let admin = pgSession.client.admin
        do {
            switch operation {
            case .vacuum:
                _ = try await admin.vacuum()
            case .vacuumFull:
                _ = try await admin.vacuum(full: true)
            case .vacuumAnalyze:
                _ = try await admin.vacuum(analyze: true)
            case .analyze:
                _ = try await admin.analyze()
            case .reindex:
                _ = try await admin.reindex(database: database)
            }
        } catch {
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .maintenanceFailed, message: "Maintenance failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - PostgreSQL Drop

    func dropPostgresDatabase(session: ConnectionSession, name: String, cascade: Bool, force: Bool) async {
        guard let pgSession = session.session as? PostgresSession else { return }

        do {
            _ = try await pgSession.client.admin.dropDatabase(name: name, ifExists: true, withForce: force)
            Task { @MainActor in
                await environmentState.refreshDatabaseStructure(for: session.id)
            }
        } catch {
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .generalError, message: "Drop failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - MSSQL Tasks

    enum MSSQLDatabaseTask {
        case shrink, takeOffline, bringOnline, drop
    }

    func runMSSQLTask(session: ConnectionSession, database: String, task: MSSQLDatabaseTask) async {
        guard let mssqlSession = session.session as? MSSQLSession else { return }
        let admin = mssqlSession.admin

        do {
            let messages: [SQLServerStreamMessage]
            switch task {
            case .shrink:
                messages = try await admin.shrinkDatabase(name: database)
            case .takeOffline:
                messages = try await admin.takeDatabaseOffline(name: database)
            case .bringOnline:
                messages = try await admin.bringDatabaseOnline(name: database)
            case .drop:
                messages = try await admin.dropDatabase(name: database)
            }

            // Show server info messages as toast
            let infoMessages = messages.filter { $0.kind == .info }
            let toastMessage = infoMessages.map(\.message).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            await MainActor.run {
                if !toastMessage.isEmpty {
                    environmentState.notificationEngine?.post(category: .maintenanceCompleted, message: toastMessage)
                }
                // Refresh structure to update database states in the sidebar
                Task {
                    await environmentState.refreshDatabaseStructure(for: session.id)
                }
            }
        } catch {
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .maintenanceFailed, message: "Task failed: \(error.localizedDescription)")
            }
        }
    }
}
