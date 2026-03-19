import SwiftUI
import EchoSense

extension ObjectBrowserSidebarView {

    // MARK: - Object Group Context Menu

    @ViewBuilder
    func objectGroupContextMenu(type: SchemaObjectInfo.ObjectType, database: DatabaseInfo, session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let creationTitle = objectGroupCreationTitle(for: type)
        if let title = creationTitle {
            let item = creationOptions(for: session.connection.databaseType).first { $0.title == title }
            if let item {
                Button {
                    handleCreationAction(item, session: session, database: database)
                } label: {
                    Label(title, systemImage: "plus")
                }
            } else {
                Button {} label: {
                    Label(title, systemImage: "plus")
                }
                .disabled(true)
            }
            Divider()
        }

        Button {
            viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: true)
            Task {
                await environmentState.loadSchemaForDatabase(database.name, connectionSession: session)
                viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: false)
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
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
        }
    }

    // MARK: - Databases Folder Context Menu

    @ViewBuilder
    func databasesFolderContextMenu(session: ConnectionSession) -> some View {
        Button {
            viewModel.newDatabaseConnectionID = session.connection.id
            viewModel.showNewDatabaseSheet = true
        } label: {
            Label("New Database", systemImage: "plus")
        }

        Divider()

        Button {
            Task {
                await environmentState.refreshDatabaseStructure(for: session.id, scope: .full)
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
    }

    // MARK: - Server Context Menu

    @ViewBuilder
    func serverContextMenu(session: ConnectionSession) -> some View {
        Button {
            environmentState.openActivityMonitorTab(connectionID: session.connection.id)
        } label: {
            Label("Activity Monitor", systemImage: "gauge.with.dots.needle.33percent")
        }

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

        Button {
            environmentState.openQueryTab(for: session)
        } label: {
            Label("New Query", systemImage: "doc.badge.plus")
        }

        Divider()

        Button {
            Task {
                await environmentState.refreshDatabaseStructure(for: session.id, scope: .full)
            }
        } label: {
            Label("Refresh All", systemImage: "arrow.clockwise")
        }

        Button {
            Task {
                await environmentState.disconnectSession(withID: session.id)
            }
        } label: {
            Label("Disconnect", systemImage: "xmark.circle")
        }
    }

}
