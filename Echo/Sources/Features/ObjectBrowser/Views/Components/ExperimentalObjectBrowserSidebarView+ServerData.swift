import SwiftUI
import PostgresKit
import SQLServerKit

extension ExperimentalObjectBrowserSidebarView {
    enum ExperimentalMSSQLDatabaseTask {
        case shrink
        case takeOffline
        case bringOnline
        case drop
    }

    func loadAgentJobs(session: ConnectionSession) {
        let connID = session.connection.id
        guard let mssql = session.session as? MSSQLSession else { return }
        viewModel.agentJobsLoadingBySession[connID] = true

        Task {
            defer { viewModel.agentJobsLoadingBySession[connID] = false }

            do {
                let detailed = try await mssql.agent.listJobDetails()
                viewModel.agentJobsBySession[connID] = detailed.map { job in
                    .init(
                        id: job.jobId,
                        name: job.name,
                        enabled: job.enabled,
                        lastOutcome: job.lastRunOutcome
                    )
                }
            } catch {
                do {
                    let basic = try await mssql.agent.listJobs()
                    viewModel.agentJobsBySession[connID] = basic.map { job in
                        .init(
                            id: job.name,
                            name: job.name,
                            enabled: job.enabled,
                            lastOutcome: job.lastRunOutcome
                        )
                    }
                } catch {
                    viewModel.agentJobsBySession[connID] = []
                }
            }
        }
    }

    func loadLinkedServers(session: ConnectionSession) {
        let connID = session.connection.id
        guard let mssql = session.session as? MSSQLSession else { return }
        viewModel.linkedServersLoadingBySession[connID] = true

        Task {
            defer { viewModel.linkedServersLoadingBySession[connID] = false }

            do {
                let servers = try await mssql.linkedServers.list()
                viewModel.linkedServersBySession[connID] = servers.map { server in
                    .init(
                        id: server.name,
                        name: server.name,
                        provider: server.provider,
                        dataSource: server.dataSource,
                        product: server.product,
                        isDataAccessEnabled: server.isDataAccessEnabled
                    )
                }
            } catch {
                viewModel.linkedServersBySession[connID] = []
            }
        }
    }

    func testLinkedServer(name: String, session: ConnectionSession) {
        guard let mssql = session.session as? MSSQLSession else { return }

        Task {
            do {
                let success = try await mssql.linkedServers.test(name: name)
                environmentState.toastPresenter.show(
                    icon: success ? "checkmark.circle" : "xmark.circle",
                    message: success ? "Connection to \"\(name)\" succeeded." : "Connection to \"\(name)\" failed.",
                    style: success ? .success : .error
                )
            } catch {
                environmentState.toastPresenter.show(
                    icon: "xmark.circle",
                    message: "Connection test failed: \(error.localizedDescription)",
                    style: .error
                )
            }
        }
    }

    func executeDropLinkedServer(_ target: SidebarSheetState.DropLinkedServerTarget, session: ConnectionSession) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            try await mssql.linkedServers.drop(name: target.serverName, dropLogins: true)
            loadLinkedServers(session: session)
        } catch {
            environmentState.toastPresenter.show(
                icon: "xmark.circle",
                message: "Failed to drop linked server: \(error.localizedDescription)",
                style: .error
            )
        }
    }

    func loadSSISFoldersAsync(session: ConnectionSession) async {
        let connID = session.connection.id
        guard let mssql = session.session as? MSSQLSession else { return }

        viewModel.ssisLoadingBySession[connID] = true
        defer { viewModel.ssisLoadingBySession[connID] = false }

        do {
            if try await mssql.ssis.isSSISCatalogAvailable() {
                viewModel.ssisFoldersBySession[connID] = try await mssql.ssis.listFolders()
            } else {
                viewModel.ssisFoldersBySession[connID] = []
            }
        } catch {
            viewModel.ssisFoldersBySession[connID] = []
        }
    }

    func loadDatabaseSnapshots(session: ConnectionSession) {
        let connID = session.connection.id
        viewModel.databaseSnapshotsLoadingBySession[connID] = true

        Task {
            defer { viewModel.databaseSnapshotsLoadingBySession[connID] = false }

            do {
                viewModel.databaseSnapshotsBySession[connID] = try await session.session.listDatabaseSnapshots()
            } catch {
                viewModel.databaseSnapshotsBySession[connID] = []
            }
        }
    }

    func revertSnapshot(_ snapshot: SQLServerDatabaseSnapshot, session: ConnectionSession) {
        Task {
            let handle = AppDirector.shared.activityEngine.begin(
                "Revert \(snapshot.sourceDatabaseName) to snapshot \(snapshot.name)",
                connectionSessionID: session.id
            )
            do {
                try await session.session.revertToSnapshot(snapshotName: snapshot.name)
                handle.succeed()
                environmentState.notificationEngine?.post(
                    category: .maintenanceCompleted,
                    message: "Reverted \(snapshot.sourceDatabaseName) to snapshot \(snapshot.name)."
                )
            } catch {
                handle.fail(error.localizedDescription)
                environmentState.notificationEngine?.post(
                    category: .maintenanceFailed,
                    message: "Revert failed: \(error.localizedDescription)"
                )
            }
        }
    }

    func deleteSnapshot(_ snapshot: SQLServerDatabaseSnapshot, session: ConnectionSession) {
        Task {
            let handle = AppDirector.shared.activityEngine.begin(
                "Delete snapshot \(snapshot.name)",
                connectionSessionID: session.id
            )
            do {
                try await session.session.deleteDatabaseSnapshot(name: snapshot.name)
                handle.succeed()
                environmentState.notificationEngine?.post(
                    category: .maintenanceCompleted,
                    message: "Snapshot \(snapshot.name) deleted."
                )
                loadDatabaseSnapshots(session: session)
            } catch {
                handle.fail(error.localizedDescription)
                environmentState.notificationEngine?.post(
                    category: .maintenanceFailed,
                    message: "Delete snapshot failed: \(error.localizedDescription)"
                )
            }
        }
    }

    func loadServerTriggers(session: ConnectionSession) {
        let connID = session.connection.id
        guard let mssql = session.session as? MSSQLSession else { return }
        viewModel.serverTriggersLoadingBySession[connID] = true

        Task {
            defer { viewModel.serverTriggersLoadingBySession[connID] = false }

            do {
                let triggers = try await mssql.triggers.listServerTriggers()
                viewModel.serverTriggersBySession[connID] = triggers.map { trigger in
                    .init(
                        id: trigger.name,
                        name: trigger.name,
                        isDisabled: trigger.isDisabled,
                        typeDescription: trigger.typeDescription,
                        events: trigger.events
                    )
                }
            } catch {
                viewModel.serverTriggersBySession[connID] = []
            }
        }
    }

    func setServerTrigger(_ name: String, enabled: Bool, session: ConnectionSession) {
        guard let mssql = session.session as? MSSQLSession else { return }
        Task {
            do {
                if enabled {
                    try await mssql.triggers.enableServerTrigger(name: name)
                } else {
                    try await mssql.triggers.disableServerTrigger(name: name)
                }
                loadServerTriggers(session: session)
            } catch {
                environmentState.toastPresenter.show(
                    icon: "xmark.circle",
                    message: "Failed to \(enabled ? "enable" : "disable") trigger: \(error.localizedDescription)",
                    style: .error
                )
            }
        }
    }

    func dropServerTrigger(name: String, session: ConnectionSession) {
        guard let mssql = session.session as? MSSQLSession else { return }
        Task {
            do {
                try await mssql.triggers.dropServerTrigger(name: name)
                loadServerTriggers(session: session)
            } catch {
                environmentState.toastPresenter.show(
                    icon: "xmark.circle",
                    message: "Failed to drop trigger: \(error.localizedDescription)",
                    style: .error
                )
            }
        }
    }

    func scriptServerTrigger(name: String, session: ConnectionSession) {
        guard let mssql = session.session as? MSSQLSession else { return }
        Task {
            do {
                if let definition = try await mssql.triggers.getServerTriggerDefinition(name: name) {
                    environmentState.openQueryTab(for: session, presetQuery: definition)
                }
            } catch {
                environmentState.toastPresenter.show(
                    icon: "xmark.circle",
                    message: "Failed to get trigger definition: \(error.localizedDescription)",
                    style: .error
                )
            }
        }
    }

    func dropPostgresDatabase(session: ConnectionSession, name: String, cascade: Bool, force: Bool) async {
        guard let pgSession = session.session as? PostgresSession else { return }

        do {
            _ = try await pgSession.client.admin.dropDatabase(name: name, ifExists: true, withForce: force)
            await environmentState.refreshDatabaseStructure(for: session.id)
        } catch {
            environmentState.notificationEngine?.post(
                category: .generalError,
                message: "Drop failed: \(error.localizedDescription)"
            )
        }
    }

    func runMSSQLTask(session: ConnectionSession, database: String, task: ExperimentalMSSQLDatabaseTask) async {
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

            let infoMessages = messages.filter { $0.kind == .info }
            let toastMessage = infoMessages.map(\.message).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !toastMessage.isEmpty {
                environmentState.notificationEngine?.post(category: .maintenanceCompleted, message: toastMessage)
            }
            await environmentState.refreshDatabaseStructure(for: session.id)
        } catch {
            environmentState.notificationEngine?.post(
                category: .maintenanceFailed,
                message: "Task failed: \(error.localizedDescription)"
            )
        }
    }
}
