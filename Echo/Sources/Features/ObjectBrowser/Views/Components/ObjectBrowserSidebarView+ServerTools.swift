import AppKit
import PostgresKit
import SwiftUI

/// Which PostgreSQL server backup the Management section asked for.
struct PgServerBackupRequest: Identifiable {
    let id = UUID()
    let connectionID: UUID
    let globalsOnly: Bool
}

/// PostgreSQL's server sections (round 16): Activity Monitor's pages, the server-wide
/// maintenance and backup tools, and tablespaces.
extension ObjectBrowserSidebarView {
    /// Opens a server tool that isn't one of SQL Server's.
    func performServerTool(_ kind: ExplorerNodeKind, session: ConnectionSession) {
        let connectionID = session.connection.id
        if let page = Self.postgresActivityPage(for: kind) {
            environmentState.openActivityMonitorTab(connectionID: connectionID, section: page.rawValue)
            return
        }
        switch kind {
        case .backUpServer:
            sheetState.pgServerBackup = PgServerBackupRequest(connectionID: connectionID, globalsOnly: false)
        case .backUpGlobals:
            sheetState.pgServerBackup = PgServerBackupRequest(connectionID: connectionID, globalsOnly: true)
        case .psqlConsole:
            environmentState.openPSQLTab(for: session)
        default:
            break
        }
    }

    /// The Activity Monitor page a tool row opens.
    static func postgresActivityPage(for kind: ExplorerNodeKind) -> PostgresActivityMonitorView.PostgresActivitySection? {
        switch kind {
        case .pgSessions: .sessions
        case .pgLocks: .locks
        case .pgDatabaseStatistics: .database
        case .pgOperations: .operations
        case .pgQueries: .queries
        case .pgReplication: .replication
        case .pgIOStatistics: .ioStats
        case .pgWAL: .wal
        case .pgBackgroundWriter: .bgWriter
        case .pgPreparedTransactions: .preparedTxns
        case .pgConfiguration: .configuration
        default: nil
        }
    }

    // MARK: - Tablespaces

    func loadTablespaces(session: ConnectionSession) {
        Task {
            let key = ExplorerSourceKey(connectionID: session.connection.id, source: .tablespaces)
            let handle = AppDirector.shared.activityEngine.begin("Loading tablespaces", connectionSessionID: session.id)
            viewModel.beginLoading(key)
            guard let pg = session.session as? PostgresSession else {
                viewModel.finishLoading(key, items: [:])
                handle.succeed()
                return
            }
            do {
                let tablespaces: [PostgresTablespaceInfo] = try await pg.client.metadata.listTablespaces()
                let items = tablespaces.map { tablespace in
                    ExplorerItem(id: tablespace.name, name: tablespace.name,
                                 detail: tablespace.location.isEmpty ? tablespace.owner : tablespace.location)
                }
                viewModel.finishLoading(key, items: [.tablespaces: items])
                handle.succeed()
            } catch {
                viewModel.finishLoading(key, items: [:])
                handle.fail(error.localizedDescription)
            }
        }
    }

    // MARK: - Menus

    /// Menus for PostgreSQL's server sections, or nil for other kinds.
    func postgresServerSectionMenu(kind: ExplorerNodeKind, session: ConnectionSession) -> NSMenu? {
        let connectionID = session.connection.id
        let menu = NSMenu()
        switch kind {
        case .activity:
            menu.addActionItem("Open Activity Monitor", systemImage: "gauge.high") {
                environmentState.openActivityMonitorTab(connectionID: connectionID)
            }
        case .tablespaces:
            menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
                loadTablespaces(session: session)
            }
            menu.addDivider()
            menu.addActionItem("Manage Tablespaces", systemImage: "square.stack.3d.up") {
                environmentState.openAdvancedObjectsTab(connectionID: connectionID, section: .tablespaces)
            }
        case .management where session.connection.databaseType == .postgresql:
            menu.addActionItem("Maintenance", systemImage: "wrench.and.screwdriver") {
                environmentState.openMaintenanceTab(connectionID: connectionID)
            }
            menu.addActionItem("Back Up Server", systemImage: "externaldrive.badge.timemachine") {
                sheetState.pgServerBackup = PgServerBackupRequest(connectionID: connectionID, globalsOnly: false)
            }
        default:
            return nil
        }
        return menu
    }

    // MARK: - Sheets

    func applyServerToolSheets<V: View>(to content: V) -> some View {
        content
            .sheet(item: $sheetState.pgServerBackup) { request in
                if let session = environmentState.sessionGroup.sessionForConnection(request.connectionID) {
                    PgServerBackupSheetContainer(connection: session.connection, globalsOnly: request.globalsOnly) {
                        sheetState.pgServerBackup = nil
                    }
                }
            }
            .sheet(item: $sheetState.dockCustomization) { customization in
                ExplorerDockCustomizationSheet(customization: customization) { keys, scope in
                    if let session = environmentState.sessionGroup.sessionForConnection(customization.connectionID) {
                        saveDock(keys, for: session, scope: scope)
                    }
                    sheetState.dockCustomization = nil
                } onCancel: {
                    sheetState.dockCustomization = nil
                }
            }
    }
}

/// Back Up Server or Back Up Globals, with the connection's credentials and pg_dump path.
struct PgServerBackupSheetContainer: View {
    let connection: SavedConnection
    let globalsOnly: Bool
    let onDismiss: () -> Void

    @Environment(ProjectStore.self) private var projectStore

    var body: some View {
        let auth = AppDirector.shared.identityRepository.resolveAuthenticationConfiguration(for: connection, overridePassword: nil)
        if globalsOnly {
            PgBackupGlobalsSheet(connection: connection, authentication: auth,
                                 customToolPath: projectStore.globalSettings.pgToolCustomPath, onDismiss: onDismiss)
        } else {
            PgBackupServerSheet(connection: connection, authentication: auth,
                                customToolPath: projectStore.globalSettings.pgToolCustomPath, onDismiss: onDismiss)
        }
    }
}
