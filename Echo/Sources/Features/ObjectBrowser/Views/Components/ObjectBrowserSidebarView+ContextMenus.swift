import AppKit
import SwiftUI

/// The tree's context menus, chosen by what a row is. The menus themselves live by area:
/// `+ServerMenus`, `+DatabaseMenus`, `+ObjectMenus`.
extension ObjectBrowserSidebarView {
    func contextMenu(for node: ObjectBrowserNode) -> NSMenu? {
        switch node.row {
        case .pendingConnection(let pending):
            pendingConnectionMenu(for: pending)
        case .server(let session):
            connectionMenu(for: session)
        case .section(let folder), .folder(let folder):
            folderMenu(folder)
        case .database(let session, let database, _):
            databaseMenu(for: database, session: session)
        case .object(let session, let databaseName, let object):
            objectMenu(for: object, databaseName: databaseName, session: session)
        case .item(let row):
            itemMenu(row)
        case .topSpacer, .column, .action, .placeholder, .loading, .message, .dock:
            nil
        }
    }

    private func folderMenu(_ folder: ExplorerFolder) -> NSMenu? {
        let session = folder.session
        if folder.kind == .databases {
            return databasesFolderMenu(for: session)
        }
        if let databaseName = folder.databaseName {
            if let type = folder.kind.objectType {
                return objectGroupMenu(for: type, databaseName: databaseName, session: session)
            }
            switch folder.kind {
            case .databaseSecurity, .databaseTriggers, .serviceBroker, .externalResources:
                return databaseFolderMenu(kind: folder.kind, databaseName: databaseName, session: session)
            default:
                return databaseSubfolderMenu(kind: folder.kind, databaseName: databaseName, session: session)
            }
        }
        switch folder.kind {
        case .logins, .certificateLogins, .serverRoles, .credentials, .loginRoles, .groupRoles:
            return securitySectionMenu(kind: folder.kind, session: session)
        default:
            return postgresServerSectionMenu(kind: folder.kind, session: session)
                ?? serverFolderMenu(kind: folder.kind, session: session)
        }
    }

    private func itemMenu(_ row: ExplorerItemRow) -> NSMenu? {
        let session = row.session
        switch row.item.payload {
        case .login(let type):
            return securityLoginMenu(login: row.item, loginType: type, session: session)
        case .serverRole(let isFixed):
            return securityServerRoleMenu(role: row.item, isFixed: isFixed, session: session)
        case .credential(let identity):
            return securityCredentialMenu(credential: row.item, identity: identity, session: session)
        case .snapshot(let snapshot):
            return snapshotMenu(snapshot: snapshot, session: session)
        case .linkedServer:
            return linkedServerMenu(server: row.item, session: session)
        case .serverTrigger:
            return serverTriggerMenu(trigger: row.item, session: session)
        case .ssisFolder, .plain:
            return row.kind == .agentJob ? agentJobMenu(for: session) : nil
        }
    }

    func pendingConnectionMenu(for pending: PendingConnection) -> NSMenu {
        let menu = NSMenu()

        switch pending.phase {
        case .connecting:
            menu.addActionItem("Cancel Connection", systemImage: "xmark.circle") {
                environmentState.cancelPendingConnection(for: pending.connection.id)
            }
            menu.addActionItem("Edit Connection", systemImage: "pencil") {
                ManageConnectionsWindowController.shared.present()
            }
        case .failed:
            menu.addActionItem("Retry", systemImage: "arrow.clockwise") {
                environmentState.retryPendingConnection(for: pending.connection.id)
            }
            menu.addActionItem("Edit Connection", systemImage: "pencil") {
                ManageConnectionsWindowController.shared.present()
            }
            menu.addDivider()
            menu.addActionItem("Remove", systemImage: "trash") {
                environmentState.removePendingConnection(for: pending.connection.id)
            }
        }

        return menu
    }

    func connectionMenu(for session: ConnectionSession) -> NSMenu {
        let menu = NSMenu()

        menu.addActionItem("Refresh All", systemImage: "arrow.clockwise") {
            Task {
                let handle = AppDirector.shared.activityEngine.begin("Refreshing all databases", connectionSessionID: session.id)
                await environmentState.refreshDatabaseStructure(for: session.id, scope: .full)
                handle.succeed()
            }
        }
        menu.addActionItem("New Query", systemImage: "doc.text") {
            environmentState.openQueryTab(for: session)
        }
        menu.addDivider()
        menu.addActionItem("Activity Monitor", systemImage: "gauge.with.dots.needle.33percent") {
            environmentState.openActivityMonitorTab(connectionID: session.connection.id)
        }
        menu.addDivider()
        menu.addActionItem("Maintenance", systemImage: "wrench.and.screwdriver") {
            environmentState.openMaintenanceTab(connectionID: session.connection.id)
        }

        if session.connection.databaseType == .microsoftSQL {
            menu.addActionItem("Database Mail", systemImage: "envelope") {
                let value = environmentState.prepareDatabaseMailEditorWindow(connectionSessionID: session.connection.id)
                openWindow(id: DatabaseMailEditorWindow.sceneID, value: value)
            }
            menu.addActionItem("Central Management Servers", systemImage: "server.rack") {
                sheetState.cmsConnectionID = session.connection.id
                sheetState.showCMSSheet = true
            }
            menu.addActionItem("Extended Events", systemImage: "waveform.path.ecg") {
                environmentState.openActivityMonitorTab(connectionID: session.connection.id, section: "XEvents")
            }
            menu.addActionItem("Availability Groups", systemImage: "server.rack") {
                environmentState.openAvailabilityGroupsTab(connectionID: session.connection.id)
            }
            menu.addDivider()

            let connID = session.connection.id
            let item = menu.addActionItem(hideOfflineDatabasesTitle(for: connID), systemImage: "eye.slash") {
                self.toggleHideOffline(for: connID)
            }
            item.state = (viewModel.hideOfflineDatabasesBySession[connID] ?? false) ? .on : .off
        }

        menu.addDivider()
        menu.addActionItem("Manage Connection", systemImage: "slider.horizontal.3") {
            ManageConnectionsWindowController.shared.present(
                initialSection: .connections,
                selectedConnectionID: session.connection.id
            )
        }
        menu.addActionItem("Disconnect", systemImage: "xmark.circle") {
            Task { await environmentState.disconnectSession(withID: session.id) }
        }

        menu.addDivider()
        if session.connection.databaseType == .microsoftSQL {
            menu.addActionItem("Properties", systemImage: "info.circle") {
                let value = environmentState.prepareServerEditorWindow(connectionSessionID: session.connection.id)
                openWindow(id: ServerEditorWindow.sceneID, value: value)
            }
        } else if session.connection.databaseType == .mysql {
            menu.addActionItem("Server Properties", systemImage: "info.circle") {
                environmentState.openServerPropertiesTab(connectionID: session.connection.id)
            }
        }

        return menu
    }

    func hideOfflineDatabasesTitle(for connectionID: UUID) -> String {
        let isHidden = viewModel.hideOfflineDatabasesBySession[connectionID] ?? false
        return isHidden ? "Show Offline Databases" : "Hide Offline Databases"
    }

    func toggleHideOffline(for connectionID: UUID) {
        let newValue = !(viewModel.hideOfflineDatabasesBySession[connectionID] ?? false)
        viewModel.setHideOffline(newValue, for: connectionID)
    }
}
