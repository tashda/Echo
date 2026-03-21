import SwiftUI
import EchoSense

extension ObjectBrowserSidebarView {

    // MARK: - Object Group Context Menu

    @ViewBuilder
    func objectGroupContextMenu(type: SchemaObjectInfo.ObjectType, database: DatabaseInfo, session: ConnectionSession) -> some View {
        let connID = session.connection.id

        // Group 1: Refresh
        Button {
            viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: true)
            Task {
                let handle = AppDirector.shared.activityEngine.begin("Refreshing \(type.pluralDisplayName)", connectionSessionID: session.id)
                await environmentState.loadSchemaForDatabase(database.name, connectionSession: session)
                handle.succeed()
                viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: false)
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }

        // Group 2: New
        let creationTitle = objectGroupCreationTitle(for: type)
        if let title = creationTitle {
            let item = creationOptions(for: session.connection.databaseType).first { $0.title == title }
            if let item {
                Button {
                    handleCreationAction(item, session: session, database: database)
                } label: {
                    Label(title, systemImage: objectGroupCreationIcon(for: type))
                }
            } else {
                Button {} label: {
                    Label(title, systemImage: objectGroupCreationIcon(for: type))
                }
                .disabled(true)
            }
        }
    }

    func objectGroupCreationTitle(for type: SchemaObjectInfo.ObjectType) -> String? {
        switch type {
        case .table: "New Table"
        case .view: "New View"
        case .materializedView: "New Materialized View"
        case .function: "New Function"
        case .procedure: "New Procedure"
        case .trigger: "New Trigger"
        case .extension: "New Extension"
        case .sequence: "New Sequence"
        case .type: "New Type"
        case .synonym: "New Synonym"
        }
    }

    func objectGroupCreationIcon(for type: SchemaObjectInfo.ObjectType) -> String {
        switch type {
        case .table: "tablecells"
        case .view: "eye"
        case .materializedView: "eye"
        case .function: "function"
        case .procedure: "gearshape"
        case .trigger: "bolt"
        case .extension: "puzzlepiece.extension"
        case .sequence: "number"
        case .type: "t.square"
        case .synonym: "arrow.triangle.swap"
        }
    }

    // MARK: - Databases Folder Context Menu

    @ViewBuilder
    func databasesFolderContextMenu(session: ConnectionSession) -> some View {
        // Group 1: Refresh
        Button {
            Task {
                let handle = AppDirector.shared.activityEngine.begin("Refreshing databases", connectionSessionID: session.id)
                await environmentState.refreshDatabaseStructure(for: session.id, scope: .full)
                handle.succeed()
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }

        // Group 2: New
        Button {
            viewModel.newDatabaseConnectionID = session.connection.id
            viewModel.showNewDatabaseSheet = true
        } label: {
            Label("New Database", systemImage: "cylinder")
        }
    }

    // MARK: - Server Context Menu

    @ViewBuilder
    func serverContextMenu(session: ConnectionSession) -> some View {
        // Group 1: Refresh
        Button {
            Task {
                let handle = AppDirector.shared.activityEngine.begin("Refreshing all databases", connectionSessionID: session.id)
                await environmentState.refreshDatabaseStructure(for: session.id, scope: .full)
                handle.succeed()
            }
        } label: {
            Label("Refresh All", systemImage: "arrow.clockwise")
        }

        // Group 2: New
        Button {
            environmentState.openQueryTab(for: session)
        } label: {
            Label("New Query", systemImage: "doc.text")
        }

        Divider()

        // Group 3: Open / View
        Button {
            environmentState.openActivityMonitorTab(connectionID: session.connection.id)
        } label: {
            Label("Activity Monitor", systemImage: "gauge.with.dots.needle.33percent")
        }

        Divider()

        // Group 7: Maintenance
        Button {
            environmentState.openMaintenanceTab(connectionID: session.connection.id)
        } label: {
            Label("Maintenance", systemImage: "wrench.and.screwdriver")
        }

        if session.connection.databaseType == .microsoftSQL {
            Button {
                viewModel.databaseMailConnectionID = session.connection.id
                viewModel.showDatabaseMailSheet = true
            } label: {
                Label("Database Mail", systemImage: "envelope")
            }

            Button {
                viewModel.cmsConnectionID = session.connection.id
                viewModel.showCMSSheet = true
            } label: {
                Label("Central Management Servers", systemImage: "server.rack")
            }

            Button {
                environmentState.openExtendedEventsTab(connectionID: session.connection.id)
            } label: {
                Label("Extended Events", systemImage: "waveform.path.ecg")
            }

            Button {
                environmentState.openAvailabilityGroupsTab(connectionID: session.connection.id)
            } label: {
                Label("Availability Groups", systemImage: "server.rack")
            }
        }

        Divider()

        // Group 10: Destructive
        Button(role: .destructive) {
            Task {
                await environmentState.disconnectSession(withID: session.id)
            }
        } label: {
            Label("Disconnect", systemImage: "xmark.circle")
        }
    }

}
