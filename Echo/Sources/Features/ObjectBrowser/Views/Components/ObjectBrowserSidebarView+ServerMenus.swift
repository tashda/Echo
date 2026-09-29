import AppKit
import SwiftUI
import SQLServerKit

/// Menus for server-level folders and the items loaded into them.
extension ObjectBrowserSidebarView {
    func serverFolderMenu(
        kind: ExplorerNodeKind,
        session: ConnectionSession
    ) -> NSMenu? {
        let menu = NSMenu()

        switch kind {
        case .serverSecurity:
            menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
                Task {
                    let handle = AppDirector.shared.activityEngine.begin("Refreshing security", connectionSessionID: session.id)
                    await loadServerSecurityAsync(session: session)
                    handle.succeed()
                }
            }
            switch session.connection.databaseType {
            case .microsoftSQL:
                menu.addActionItem("New Login", systemImage: "person.badge.plus") {
                    let value = environmentState.prepareLoginEditorWindow(
                        connectionSessionID: session.connection.id,
                        existingLogin: nil
                    )
                    openWindow(id: LoginEditorWindow.sceneID, value: value)
                }
                menu.addDivider()
                menu.addActionItem("Open Security Management", systemImage: "lock.shield") {
                    environmentState.openServerSecurityTab(connectionID: session.connection.id)
                }
            case .postgresql:
                menu.addActionItem("New Login Role", systemImage: "person.badge.plus") {
                    sheetState.securityPGRoleSheetSessionID = session.connection.id
                    sheetState.securityPGRoleSheetEditName = nil
                    sheetState.showSecurityPGRoleSheet = true
                }
                menu.addActionItem("New Group Role", systemImage: "person.2.badge.plus") {
                    sheetState.securityPGRoleSheetSessionID = session.connection.id
                    sheetState.securityPGRoleSheetEditName = nil
                    sheetState.showSecurityPGRoleSheet = true
                }
            case .mysql, .sqlite:
                break
            }
        case .agentJobs:
            menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
                loadAgentJobs(session: session)
            }
            menu.addDivider()
            menu.addActionItem("Open in Tab", systemImage: "list.bullet.rectangle") {
                environmentState.openJobQueueTab(for: session)
            }
            menu.addActionItem("Open in New Window", systemImage: "rectangle.portrait.and.arrow.right") {
                let sessionID = environmentState.prepareJobQueueWindow(for: session)
                openWindow(id: JobQueueWindow.sceneID, value: sessionID)
            }
        case .databaseSnapshots:
            menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
                loadDatabaseSnapshots(session: session)
            }
            menu.addDivider()
            menu.addActionItem("New Snapshot", systemImage: "camera.badge.ellipsis") {
                sheetState.createSnapshotConnectionID = session.connection.id
                sheetState.showCreateSnapshotSheet = true
            }
        case .integrationServices:
            menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
                Task { await loadSSISFoldersAsync(session: session) }
            }
        case .linkedServers:
            menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
                loadLinkedServers(session: session)
            }
            menu.addDivider()
            menu.addActionItem("New Linked Server", systemImage: "link.badge.plus") {
                sheetState.newLinkedServerSessionID = session.connection.id
                sheetState.showNewLinkedServerSheet = true
            }
        case .serverTriggers:
            menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
                loadServerTriggers(session: session)
            }
            menu.addActionItem("New Server Trigger", systemImage: "bolt") {
                sheetState.newServerTriggerConnectionID = session.connection.id
                sheetState.showNewServerTriggerSheet = true
            }
        default:
            return nil
        }

        return menu
    }

    func securitySectionMenu(
        kind: ExplorerNodeKind,
        session: ConnectionSession
    ) -> NSMenu {
        let menu = NSMenu()
        menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
            Task {
                let handle = AppDirector.shared.activityEngine.begin("Refreshing \(kind.title.lowercased())", connectionSessionID: session.id)
                await loadServerSecurityAsync(session: session)
                handle.succeed()
            }
        }

        switch kind {
        case .logins:
            menu.addActionItem("New Login", systemImage: "person.badge.plus") {
                let value = environmentState.prepareLoginEditorWindow(
                    connectionSessionID: session.connection.id,
                    existingLogin: nil
                )
                openWindow(id: LoginEditorWindow.sceneID, value: value)
            }
        case .serverRoles:
            menu.addActionItem("New Server Role", systemImage: "person.2.badge.plus") {
                createMSSQLServerRole(session: session)
            }
        case .credentials:
            menu.addActionItem("New Credential", systemImage: "key.fill") {
                createMSSQLCredential(session: session)
            }
        case .loginRoles:
            menu.addActionItem("New Login Role", systemImage: "person.badge.plus") {
                sheetState.securityPGRoleSheetSessionID = session.connection.id
                sheetState.securityPGRoleSheetEditName = nil
                sheetState.showSecurityPGRoleSheet = true
            }
        case .groupRoles:
            menu.addActionItem("New Group Role", systemImage: "person.2.badge.plus") {
                sheetState.securityPGRoleSheetSessionID = session.connection.id
                sheetState.securityPGRoleSheetEditName = nil
                sheetState.showSecurityPGRoleSheet = true
            }
        default:
            break
        }

        return menu
    }

    func securityLoginMenu(
        login: ExplorerItem,
        loginType: String,
        session: ConnectionSession
    ) -> NSMenu {
        let menu = NSMenu()

        if session.connection.databaseType == .postgresql {
            menu.addActionItem("Reassign Owned Objects", systemImage: "arrow.triangle.swap") {
                Task { await reassignPGRole(name: login.name, session: session) }
            }
            menu.addDivider()
            menu.addSubmenu("Script as", systemImage: "scroll") { sub in
                let loginAttribute = loginType.contains("Login") || loginType.contains("Superuser") ? " LOGIN" : ""
                sub.addActionItem("CREATE", systemImage: "plus.rectangle.on.rectangle") {
                    openScriptTab(sql: "CREATE ROLE \"\(login.name)\"\(loginAttribute);", session: session)
                }
                sub.addDivider()
                sub.addActionItem("DROP", systemImage: "trash") {
                    openScriptTab(sql: "DROP ROLE \"\(login.name)\";", session: session)
                }
            }
            menu.addDivider()
            menu.addActionItem("Drop Role", systemImage: "trash") {
                sheetState.dropSecurityPrincipalTarget = .init(
                    sessionID: session.id,
                    connectionID: session.connection.id,
                    name: login.name,
                    kind: .pgRole,
                    databaseName: nil
                )
                sheetState.showDropSecurityPrincipalAlert = true
            }
            menu.addDivider()
            menu.addActionItem("Properties", systemImage: "info.circle") {
                sheetState.securityPGRoleSheetSessionID = session.connection.id
                sheetState.securityPGRoleSheetEditName = login.name
                sheetState.showSecurityPGRoleSheet = true
            }
            return menu
        }

        menu.addSubmenu("Script as", systemImage: "scroll") { sub in
            let createSQL = if loginType == "SQL" {
                "CREATE LOGIN [\(login.name)] WITH PASSWORD = N'<password>';"
            } else {
                "CREATE LOGIN [\(login.name)] FROM WINDOWS;"
            }
            sub.addActionItem("CREATE", systemImage: "plus.rectangle.on.rectangle") {
                openScriptTab(sql: createSQL, session: session)
            }
            sub.addDivider()
            sub.addActionItem("DROP", systemImage: "trash") {
                openScriptTab(sql: "DROP LOGIN [\(login.name)];", session: session)
            }
        }
        menu.addDivider()
        if login.isDisabled {
            menu.addActionItem("Enable Login", systemImage: "checkmark.circle") {
                Task { await enableMSSQLLogin(name: login.name, enabled: true, session: session) }
            }
        } else {
            menu.addActionItem("Disable Login", systemImage: "nosign") {
                Task { await enableMSSQLLogin(name: login.name, enabled: false, session: session) }
            }
        }
        menu.addDivider()
        menu.addActionItem("Drop Login", systemImage: "trash") {
            sheetState.dropSecurityPrincipalTarget = .init(
                sessionID: session.id,
                connectionID: session.connection.id,
                name: login.name,
                kind: .mssqlLogin,
                databaseName: nil
            )
            sheetState.showDropSecurityPrincipalAlert = true
        }
        menu.addDivider()
        menu.addActionItem("Properties", systemImage: "info.circle") {
            let value = environmentState.prepareLoginEditorWindow(
                connectionSessionID: session.connection.id,
                existingLogin: login.name
            )
            openWindow(id: LoginEditorWindow.sceneID, value: value)
        }
        return menu
    }

    func securityServerRoleMenu(
        role: ExplorerItem,
        isFixed: Bool,
        session: ConnectionSession
    ) -> NSMenu {
        let menu = NSMenu()
        menu.addActionItem("List Members", systemImage: "person.2") {
            openScriptTab(
                sql: """
                SELECT m.name AS member_name, m.type_desc
                FROM sys.server_role_members rm
                JOIN sys.server_principals r ON rm.role_principal_id = r.principal_id
                JOIN sys.server_principals m ON rm.member_principal_id = m.principal_id
                WHERE r.name = N'\(role.name)';
                """,
                session: session
            )
        }

        if !isFixed {
            menu.addDivider()
            menu.addSubmenu("Script as", systemImage: "scroll") { sub in
                sub.addActionItem("CREATE", systemImage: "plus.rectangle.on.rectangle") {
                    openScriptTab(sql: "CREATE SERVER ROLE [\(role.name)];", session: session)
                }
                sub.addDivider()
                sub.addActionItem("DROP", systemImage: "trash") {
                    openScriptTab(sql: "DROP SERVER ROLE [\(role.name)];", session: session)
                }
            }
            menu.addDivider()
            menu.addActionItem("Drop Server Role", systemImage: "trash") {
                sheetState.dropSecurityPrincipalTarget = .init(
                    sessionID: session.id,
                    connectionID: session.connection.id,
                    name: role.name,
                    kind: .mssqlServerRole,
                    databaseName: nil
                )
                sheetState.showDropSecurityPrincipalAlert = true
            }
        }

        return menu
    }

    func securityCredentialMenu(
        credential: ExplorerItem,
        identity: String,
        session: ConnectionSession
    ) -> NSMenu {
        let menu = NSMenu()
        menu.addSubmenu("Script as", systemImage: "scroll") { sub in
            sub.addActionItem("CREATE", systemImage: "plus.rectangle.on.rectangle") {
                openScriptTab(
                    sql: "CREATE CREDENTIAL [\(credential.name)] WITH IDENTITY = N'\(identity)', SECRET = N'<secret>';",
                    session: session
                )
            }
            sub.addDivider()
            sub.addActionItem("DROP", systemImage: "trash") {
                openScriptTab(sql: "DROP CREDENTIAL [\(credential.name)];", session: session)
            }
        }
        return menu
    }

    func snapshotMenu(snapshot: SQLServerDatabaseSnapshot, session: ConnectionSession) -> NSMenu {
        let menu = NSMenu()
        menu.addActionItem("Revert to Snapshot", systemImage: "arrow.uturn.backward") {
            revertSnapshot(snapshot, session: session)
        }
        menu.addDivider()
        menu.addActionItem("Delete Snapshot", systemImage: "trash") {
            deleteSnapshot(snapshot, session: session)
        }
        return menu
    }

    func linkedServerMenu(
        server: ExplorerItem,
        session: ConnectionSession
    ) -> NSMenu {
        let menu = NSMenu()
        menu.addActionItem("Test Connection", systemImage: "bolt.horizontal") {
            testLinkedServer(name: server.name, session: session)
        }
        menu.addDivider()
        let dropItem = menu.addActionItem("Drop", systemImage: "trash") {
            sheetState.dropLinkedServerTarget = .init(
                connectionID: session.connection.id,
                serverName: server.name
            )
            sheetState.showDropLinkedServerAlert = true
        }
        dropItem.isEnabled = session.permissions?.canManageLinkedServers ?? true
        return menu
    }

    func serverTriggerMenu(
        trigger: ExplorerItem,
        session: ConnectionSession
    ) -> NSMenu {
        let menu = NSMenu()
        if trigger.isDisabled {
            menu.addActionItem("Enable", systemImage: "checkmark.circle") {
                setServerTrigger(trigger.name, enabled: true, session: session)
            }
        } else {
            menu.addActionItem("Disable", systemImage: "pause.circle") {
                setServerTrigger(trigger.name, enabled: false, session: session)
            }
        }
        menu.addDivider()
        menu.addActionItem("Script as CREATE", systemImage: "doc.text") {
            scriptServerTrigger(name: trigger.name, session: session)
        }
        menu.addDivider()
        menu.addActionItem("Drop", systemImage: "trash") {
            dropServerTrigger(name: trigger.name, session: session)
        }
        return menu
    }

    func agentJobMenu(for session: ConnectionSession) -> NSMenu {
        let menu = NSMenu()
        menu.addActionItem("Open in Tab", systemImage: "list.bullet.rectangle") {
            environmentState.openJobQueueTab(for: session)
        }
        menu.addActionItem("Open in New Window", systemImage: "rectangle.portrait.and.arrow.right") {
            let sessionID = environmentState.prepareJobQueueWindow(for: session)
            openWindow(id: JobQueueWindow.sceneID, value: sessionID)
        }
        return menu
    }
}
