import SwiftUI
import EchoSense

extension WorkspaceToolbarItems {
    
    // MARK: - Project Menu

    internal var projectMenu: some View {
        Menu {
            if projectStore.projects.isEmpty {
                Text("No Projects Available").foregroundStyle(.secondary)
            } else {
                ForEach(projectStore.projects) { project in
                    Button {
                        projectStore.selectProject(project)
                        navigationStore.selectProject(project)
                    } label: {
                        menuRow(
                            icon: projectIcon,
                            title: project.name,
                            isSelected: project.id == projectStore.selectedProject?.id
                        )
                    }
                }
            }

            Divider()

            Button("Manage Projects…") {
                navigationStore.showManageProjectsSheet = true
            }
        } label: {
            toolbarButtonLabel(
                icon: projectIcon,
                title: projectStore.selectedProject?.name ?? "Project"
            )
        }
    }

    // MARK: - Connections Menu

    internal var connectionsMenu: some View {
#if os(macOS)
        EmptyView()
#else
        Menu {
            if connectionStore.connections.isEmpty {
                Text("No Connections Available").foregroundStyle(.secondary)
            } else {
                ConnectionToolbarMenuItems(
                    parentID: nil,
                    currentConnectionID: navigationStore.navigationState.selectedConnection?.id,
                    onConnect: { connection in
                        connectionStore.selectedConnectionID = connection.id
                        await workspaceSessionStore.connect(to: connection)
                    }
                )
            }

            Divider()

            Button("Manage Connections…") {
                #if os(macOS)
                ManageConnectionsWindowController.shared.present()
                #else
                navigationStore.isManageConnectionsPresented = true
                #endif
            }
        } label: {
            toolbarButtonLabel(
                icon: currentServerIcon,
                title: currentServerTitle
            )
        }
        .disabled(connectionStore.connections.isEmpty)
#endif
    }

    // MARK: - Database Menu

    internal var databaseMenu: some View {
#if os(macOS)
        EmptyView()
#else
        Menu {
            if let session = activeSession,
               let databases = availableDatabases(in: session),
               !databases.isEmpty {
                ForEach(databases, id: \.name) { database in
                    Button {
                        selectDatabase(database.name, in: session)
                    } label: {
                        menuRow(
                            icon: databaseMenuIcon,
                            title: database.name,
                            isSelected: session.selectedDatabaseName == database.name
                        )
                    }
                }
            } else {
                Text("No Databases Available").foregroundStyle(.secondary)
            }

            Divider()

            Button("Refresh Databases") {
                Task {
                    if let session = activeSession {
                        await workspaceSessionStore.refreshDatabaseStructure(for: session.id, scope: .full)
                    }
                }
            }
            .disabled(activeSession == nil)
        } label: {
            toolbarButtonLabel(
                icon: databaseToolbarIcon(isSelected: navigationStore.navigationState.selectedDatabase != nil),
                title: currentDatabaseTitle
            )
        }
        .disabled(activeSession == nil)
#endif
    }
}
