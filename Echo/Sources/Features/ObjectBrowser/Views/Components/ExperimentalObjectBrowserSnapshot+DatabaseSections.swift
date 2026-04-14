import Foundation

extension ExperimentalObjectBrowserSnapshotBuilder {
    static func databaseSupplementaryChildren(
        for session: ConnectionSession,
        database: DatabaseInfo,
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> [ExperimentalObjectBrowserNode] {
        switch session.connection.databaseType {
        case .microsoftSQL:
            guard database.isOnline else { return [] }
            return [
                databaseSecurityFolderNode(for: session, database: database, viewModel: viewModel),
                databaseDDLTriggersFolderNode(for: session, database: database, viewModel: viewModel),
                serviceBrokerFolderNode(for: session, database: database, viewModel: viewModel),
                externalResourcesFolderNode(for: session, database: database, viewModel: viewModel)
            ]
        case .postgresql, .mysql, .sqlite:
            return []
        }
    }

    private static func databaseSecurityFolderNode(
        for session: ConnectionSession,
        database: DatabaseInfo,
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> ExperimentalObjectBrowserNode {
        let dbKey = viewModel.databaseStorageKey(connectionID: session.connection.id, databaseName: database.name)
        let nodeID = ExperimentalObjectBrowserSidebarViewModel.databaseFolderNodeID(
            connectionID: session.connection.id,
            databaseName: database.name,
            kind: .security
        )
        let isLoading = viewModel.dbSecurityLoadingByDB[dbKey] ?? false
        let users = viewModel.dbSecurityUsersByDB[dbKey] ?? []
        let roles = viewModel.dbSecurityRolesByDB[dbKey] ?? []
        let appRoles = viewModel.dbSecurityAppRolesByDB[dbKey] ?? []
        let schemas = viewModel.dbSecuritySchemasByDB[dbKey] ?? []

        let children: [ExperimentalObjectBrowserNode] = [
            databaseSubfolderNode(
                session: session,
                databaseName: database.name,
                parentID: nodeID,
                title: "Users",
                systemImage: "person",
                paletteTitle: "Users",
                items: users.map { ($0.name, "person", "Users", $0.defaultSchema) },
                emptyTitle: "No users found"
            ),
            databaseSubfolderNode(
                session: session,
                databaseName: database.name,
                parentID: nodeID,
                title: "Database Roles",
                systemImage: "shield",
                paletteTitle: "Database Roles",
                items: roles.map { ($0.name, "shield", "Database Roles", $0.isFixed ? "Fixed" : nil) },
                emptyTitle: "No database roles found"
            ),
            databaseSubfolderNode(
                session: session,
                databaseName: database.name,
                parentID: nodeID,
                title: "Application Roles",
                systemImage: "app.badge",
                paletteTitle: "Application Roles",
                items: appRoles.map { ($0.name, "app.badge", "Application Roles", $0.defaultSchema) },
                emptyTitle: "No application roles found"
            ),
            databaseSubfolderNode(
                session: session,
                databaseName: database.name,
                parentID: nodeID,
                title: "Schemas",
                systemImage: "folder",
                paletteTitle: "Schemas",
                items: schemas.map { ($0.name, "folder", "Schemas", $0.owner) },
                emptyTitle: "No schemas found"
            )
        ]

        return ExperimentalObjectBrowserNode(
            id: nodeID,
            row: .databaseFolder(session, database.name, .security, count: nil, isLoading: isLoading),
            children: children
        )
    }

    private static func databaseDDLTriggersFolderNode(
        for session: ConnectionSession,
        database: DatabaseInfo,
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> ExperimentalObjectBrowserNode {
        let dbKey = viewModel.databaseStorageKey(connectionID: session.connection.id, databaseName: database.name)
        let nodeID = ExperimentalObjectBrowserSidebarViewModel.databaseFolderNodeID(
            connectionID: session.connection.id,
            databaseName: database.name,
            kind: .databaseTriggers
        )
        let items = viewModel.dbDDLTriggersByDB[dbKey] ?? []
        let isLoading = viewModel.dbDDLTriggersLoadingByDB[dbKey] ?? false
        let children: [ExperimentalObjectBrowserNode]

        if isLoading && items.isEmpty {
            children = [ExperimentalObjectBrowserNode(id: "\(nodeID)#loading", row: .loading("Loading database triggers…", depth: 3))]
        } else if items.isEmpty {
            children = [ExperimentalObjectBrowserNode(id: "\(nodeID)#empty", row: .infoLeaf("No database triggers", systemImage: "bolt", paletteTitle: "Database Triggers", depth: 3))]
        } else {
            children = items.map {
                ExperimentalObjectBrowserNode(
                    id: ExperimentalObjectBrowserSidebarViewModel.databaseItemNodeID(parentID: nodeID, title: $0.name),
                    row: .databaseNamedItem(session, database.name, title: $0.name, systemImage: "bolt", paletteTitle: "Database Triggers", detail: $0.isDisabled ? "Disabled" : nil)
                )
            }
        }

        return ExperimentalObjectBrowserNode(
            id: nodeID,
            row: .databaseFolder(session, database.name, .databaseTriggers, count: items.isEmpty ? nil : items.count, isLoading: isLoading),
            children: children
        )
    }

    private static func serviceBrokerFolderNode(
        for session: ConnectionSession,
        database: DatabaseInfo,
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> ExperimentalObjectBrowserNode {
        let dbKey = viewModel.databaseStorageKey(connectionID: session.connection.id, databaseName: database.name)
        let nodeID = ExperimentalObjectBrowserSidebarViewModel.databaseFolderNodeID(
            connectionID: session.connection.id,
            databaseName: database.name,
            kind: .serviceBroker
        )
        let isLoading = viewModel.serviceBrokerLoadingByDB[dbKey] ?? false
        let children = [
            databaseSubfolderNode(session: session, databaseName: database.name, parentID: nodeID, title: "Message Types", systemImage: "tray", paletteTitle: "Service Broker", items: (viewModel.serviceBrokerMessageTypesByDB[dbKey] ?? []).map { ($0, "doc", "Service Broker", nil) }, emptyTitle: "None"),
            databaseSubfolderNode(session: session, databaseName: database.name, parentID: nodeID, title: "Contracts", systemImage: "tray", paletteTitle: "Service Broker", items: (viewModel.serviceBrokerContractsByDB[dbKey] ?? []).map { ($0, "doc", "Service Broker", nil) }, emptyTitle: "None"),
            databaseSubfolderNode(session: session, databaseName: database.name, parentID: nodeID, title: "Queues", systemImage: "tray", paletteTitle: "Service Broker", items: (viewModel.serviceBrokerQueuesByDB[dbKey] ?? []).map { ($0, "doc", "Service Broker", nil) }, emptyTitle: "None"),
            databaseSubfolderNode(session: session, databaseName: database.name, parentID: nodeID, title: "Services", systemImage: "tray", paletteTitle: "Service Broker", items: (viewModel.serviceBrokerServicesByDB[dbKey] ?? []).map { ($0, "doc", "Service Broker", nil) }, emptyTitle: "None"),
            databaseSubfolderNode(session: session, databaseName: database.name, parentID: nodeID, title: "Routes", systemImage: "tray", paletteTitle: "Service Broker", items: (viewModel.serviceBrokerRoutesByDB[dbKey] ?? []).map { ($0, "doc", "Service Broker", nil) }, emptyTitle: "None"),
            databaseSubfolderNode(session: session, databaseName: database.name, parentID: nodeID, title: "Remote Service Bindings", systemImage: "tray", paletteTitle: "Service Broker", items: (viewModel.serviceBrokerBindingsByDB[dbKey] ?? []).map { ($0, "doc", "Service Broker", nil) }, emptyTitle: "None")
        ]

        return ExperimentalObjectBrowserNode(
            id: nodeID,
            row: .databaseFolder(session, database.name, .serviceBroker, count: nil, isLoading: isLoading),
            children: children
        )
    }

    private static func externalResourcesFolderNode(
        for session: ConnectionSession,
        database: DatabaseInfo,
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> ExperimentalObjectBrowserNode {
        let dbKey = viewModel.databaseStorageKey(connectionID: session.connection.id, databaseName: database.name)
        let nodeID = ExperimentalObjectBrowserSidebarViewModel.databaseFolderNodeID(
            connectionID: session.connection.id,
            databaseName: database.name,
            kind: .externalResources
        )
        let isLoading = viewModel.externalResourcesLoadingByDB[dbKey] ?? false
        let children = [
            databaseSubfolderNode(session: session, databaseName: database.name, parentID: nodeID, title: "External Data Sources", systemImage: "externaldrive", paletteTitle: "External Resources", items: (viewModel.externalDataSourcesByDB[dbKey] ?? []).map { ($0, "doc", "External Resources", nil) }, emptyTitle: "None"),
            databaseSubfolderNode(session: session, databaseName: database.name, parentID: nodeID, title: "External Tables", systemImage: "externaldrive", paletteTitle: "External Resources", items: (viewModel.externalTablesByDB[dbKey] ?? []).map { ($0, "doc", "External Resources", nil) }, emptyTitle: "None"),
            databaseSubfolderNode(session: session, databaseName: database.name, parentID: nodeID, title: "External File Formats", systemImage: "externaldrive", paletteTitle: "External Resources", items: (viewModel.externalFileFormatsByDB[dbKey] ?? []).map { ($0, "doc", "External Resources", nil) }, emptyTitle: "None")
        ]

        return ExperimentalObjectBrowserNode(
            id: nodeID,
            row: .databaseFolder(session, database.name, .externalResources, count: nil, isLoading: isLoading),
            children: children
        )
    }

    private static func databaseSubfolderNode(
        session: ConnectionSession,
        databaseName: String,
        parentID: String,
        title: String,
        systemImage: String,
        paletteTitle: String,
        items: [(title: String, systemImage: String, paletteTitle: String, detail: String?)],
        emptyTitle: String
    ) -> ExperimentalObjectBrowserNode {
        let nodeID = ExperimentalObjectBrowserSidebarViewModel.databaseSubfolderNodeID(parentID: parentID, title: title)
        let children: [ExperimentalObjectBrowserNode]
        if items.isEmpty {
            children = [
                ExperimentalObjectBrowserNode(
                    id: ExperimentalObjectBrowserSidebarViewModel.databaseItemNodeID(parentID: nodeID, title: emptyTitle),
                    row: .infoLeaf(emptyTitle, systemImage: systemImage, paletteTitle: paletteTitle, depth: 4)
                )
            ]
        } else {
            children = items.map {
                ExperimentalObjectBrowserNode(
                    id: ExperimentalObjectBrowserSidebarViewModel.databaseItemNodeID(parentID: nodeID, title: $0.title),
                    row: .databaseNamedItem(
                        session,
                        databaseName,
                        title: $0.title,
                        systemImage: $0.systemImage,
                        paletteTitle: $0.paletteTitle,
                        detail: $0.detail
                    )
                )
            }
        }

        return ExperimentalObjectBrowserNode(
            id: nodeID,
            row: .databaseSubfolder(session, databaseName, title: title, systemImage: systemImage, paletteTitle: paletteTitle, count: items.isEmpty ? nil : items.count),
            children: children
        )
    }
}
