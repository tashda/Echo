import SwiftUI
import PostgresKit
import SQLServerKit

extension ObjectBrowserSidebarView {
    enum MSSQLDatabaseTask {
        case shrink
        case takeOffline
        case bringOnline
        case drop
    }

    func loadAgentJobs(session: ConnectionSession) {
        guard let mssql = session.session as? MSSQLSession else { return }
        let key = ExplorerSourceKey(connectionID: session.connection.id, source: .agentJobs)
        viewModel.beginLoading(key)

        Task {
            var jobs: [ExplorerItem] = []
            do {
                jobs = try await mssql.agent.listJobDetails().map {
                    ExplorerItem(id: $0.jobId, name: $0.name, detail: $0.lastRunOutcome, isDisabled: !$0.enabled)
                }
            } catch {
                jobs = (try? await mssql.agent.listJobs().map {
                    ExplorerItem(id: $0.name, name: $0.name, detail: $0.lastRunOutcome, isDisabled: !$0.enabled)
                }) ?? []
            }
            viewModel.finishLoading(key, items: [.agentJobs: jobs])
        }
    }

    func loadLinkedServers(session: ConnectionSession) {
        guard let mssql = session.session as? MSSQLSession else { return }
        let key = ExplorerSourceKey(connectionID: session.connection.id, source: .linkedServers)
        viewModel.beginLoading(key)

        Task {
            let servers = (try? await mssql.linkedServers.list()) ?? []
            viewModel.finishLoading(key, items: [.linkedServers: servers.map {
                ExplorerItem(
                    id: $0.name,
                    name: $0.name,
                    detail: $0.dataSource.isEmpty ? nil : $0.dataSource,
                    isDisabled: !$0.isDataAccessEnabled,
                    payload: .linkedServer
                )
            }])
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
        guard let mssql = session.session as? MSSQLSession else { return }
        let key = ExplorerSourceKey(connectionID: session.connection.id, source: .integrationServices)
        viewModel.beginLoading(key)

        var folders: [SQLServerSSISFolder] = []
        if (try? await mssql.ssis.isSSISCatalogAvailable()) == true {
            folders = (try? await mssql.ssis.listFolders()) ?? []
        }
        viewModel.finishLoading(key, items: [.integrationServices: folders.map {
            ExplorerItem(id: $0.name, name: $0.name, payload: .ssisFolder($0))
        }])
    }

    func loadDatabaseSnapshots(session: ConnectionSession) {
        let key = ExplorerSourceKey(connectionID: session.connection.id, source: .databaseSnapshots)
        viewModel.beginLoading(key)

        Task {
            let snapshots = (try? await session.session.listDatabaseSnapshots()) ?? []
            viewModel.finishLoading(key, items: [.databaseSnapshots: snapshots.map {
                ExplorerItem(id: $0.name, name: $0.name, detail: $0.sourceDatabaseName, payload: .snapshot($0))
            }])
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
        guard let mssql = session.session as? MSSQLSession else { return }
        let key = ExplorerSourceKey(connectionID: session.connection.id, source: .serverTriggers)
        viewModel.beginLoading(key)

        Task {
            let triggers = (try? await mssql.triggers.listServerTriggers()) ?? []
            viewModel.finishLoading(key, items: [.serverTriggers: triggers.map {
                ExplorerItem(
                    id: $0.name,
                    name: $0.name,
                    detail: $0.isDisabled ? "Disabled" : nil,
                    isDisabled: $0.isDisabled,
                    payload: .serverTrigger
                )
            }])
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
