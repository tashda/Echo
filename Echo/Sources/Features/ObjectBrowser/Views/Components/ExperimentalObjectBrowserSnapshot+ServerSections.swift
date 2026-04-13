import Foundation
import SQLServerKit

extension ExperimentalObjectBrowserSnapshotBuilder {
    static func serverSupplementaryChildren(
        for session: ConnectionSession,
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> [ExperimentalObjectBrowserNode] {
        switch session.connection.databaseType {
        case .microsoftSQL:
            return [
                serverFolderNode(.security, session: session, count: nil, children: securityChildren(for: session, viewModel: viewModel)),
                serverFolderNode(.databaseSnapshots, session: session, count: snapshotCount(for: session, viewModel: viewModel), children: snapshotChildren(for: session, viewModel: viewModel)),
                serverFolderNode(.agentJobs, session: session, count: agentJobCount(for: session, viewModel: viewModel), children: agentJobChildren(for: session, viewModel: viewModel)),
                serverFolderNode(.management, session: session, count: nil, children: managementChildren(for: session)),
                serverFolderNode(.ssis, session: session, count: ssisCount(for: session, viewModel: viewModel), children: ssisChildren(for: session, viewModel: viewModel)),
                serverFolderNode(.linkedServers, session: session, count: linkedServerCount(for: session, viewModel: viewModel), children: linkedServerChildren(for: session, viewModel: viewModel)),
                serverFolderNode(.serverTriggers, session: session, count: serverTriggerCount(for: session, viewModel: viewModel), children: serverTriggerChildren(for: session, viewModel: viewModel))
            ]
        case .postgresql:
            return [
                serverFolderNode(.security, session: session, count: nil, children: securityChildren(for: session, viewModel: viewModel))
            ]
        case .mysql:
            return [
                actionNode(.maintenance, session: session, depth: 0),
                actionNode(.serverProperties, session: session, depth: 0),
                actionNode(.activityMonitor, session: session, depth: 0)
            ]
        case .sqlite:
            return [
                actionNode(.maintenance, session: session, depth: 0)
            ]
        }
    }

    private static func serverFolderNode(
        _ kind: ExperimentalObjectBrowserServerFolderKind,
        session: ConnectionSession,
        count: Int?,
        children: [ExperimentalObjectBrowserNode]
    ) -> ExperimentalObjectBrowserNode {
        let nodeID = ExperimentalObjectBrowserSidebarViewModel.serverFolderNodeID(
            connectionID: session.connection.id,
            kind: kind
        )
        return ExperimentalObjectBrowserNode(
            id: nodeID,
            row: .serverFolder(session, kind, count: count),
            children: children
        )
    }

    private static func managementChildren(for session: ConnectionSession) -> [ExperimentalObjectBrowserNode] {
        let parentID = ExperimentalObjectBrowserSidebarViewModel.serverFolderNodeID(
            connectionID: session.connection.id,
            kind: .management
        )

        return [
            actionNode(.extendedEvents, session: session, depth: 1, parentID: parentID),
            actionNode(.databaseMail, session: session, depth: 1, parentID: parentID),
            actionNode(.sqlProfiler, session: session, depth: 1, parentID: parentID),
            actionNode(.resourceGovernor, session: session, depth: 1, parentID: parentID),
            actionNode(.tuningAdvisor, session: session, depth: 1, parentID: parentID),
            actionNode(.policyManagement, session: session, depth: 1, parentID: parentID),
            actionNode(.activityMonitor, session: session, depth: 1, parentID: parentID),
            actionNode(.sqlServerLogs, session: session, depth: 1, parentID: parentID)
        ]
    }

    private static func snapshotCount(
        for session: ConnectionSession,
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> Int? {
        let items = viewModel.databaseSnapshotsBySession[session.connection.id] ?? []
        return items.isEmpty ? nil : items.count
    }

    private static func snapshotChildren(
        for session: ConnectionSession,
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> [ExperimentalObjectBrowserNode] {
        let parentID = ExperimentalObjectBrowserSidebarViewModel.serverFolderNodeID(
            connectionID: session.connection.id,
            kind: .databaseSnapshots
        )
        let items = viewModel.databaseSnapshotsBySession[session.connection.id] ?? []
        let isLoading = viewModel.databaseSnapshotsLoadingBySession[session.connection.id] ?? false

        if isLoading {
            return [ExperimentalObjectBrowserNode(id: "\(parentID)#loading", row: .loading("Loading snapshots…", depth: 1))]
        }
        if items.isEmpty {
            return [infoNode(title: "No snapshots", systemImage: "camera", paletteTitle: "Database Snapshots", depth: 1, parentID: parentID)]
        }
        return items.map {
            ExperimentalObjectBrowserNode(
                id: "\(parentID)#snapshot#\($0.name)",
                row: .databaseSnapshot(session, $0)
            )
        }
    }

    private static func agentJobCount(
        for session: ConnectionSession,
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> Int? {
        let items = viewModel.agentJobsBySession[session.connection.id] ?? []
        return items.isEmpty ? nil : items.count
    }

    private static func agentJobChildren(
        for session: ConnectionSession,
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> [ExperimentalObjectBrowserNode] {
        let parentID = ExperimentalObjectBrowserSidebarViewModel.serverFolderNodeID(
            connectionID: session.connection.id,
            kind: .agentJobs
        )
        let items = viewModel.agentJobsBySession[session.connection.id] ?? []
        let isLoading = viewModel.agentJobsLoadingBySession[session.connection.id] ?? false
        var children: [ExperimentalObjectBrowserNode] = [
            actionNode(.openJobQueue, session: session, depth: 1, parentID: parentID)
        ]

        if isLoading {
            children.append(ExperimentalObjectBrowserNode(id: "\(parentID)#loading", row: .loading("Loading jobs…", depth: 1)))
            return children
        }
        if items.isEmpty {
            children.append(infoNode(title: "No jobs found", systemImage: "clock", paletteTitle: "Agent Jobs", depth: 1, parentID: parentID))
            return children
        }
        children.append(contentsOf: items.map {
            ExperimentalObjectBrowserNode(
                id: "\(parentID)#job#\($0.id)",
                row: .agentJob(session, $0)
            )
        })
        return children
    }

    private static func ssisCount(
        for session: ConnectionSession,
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> Int? {
        let items = viewModel.ssisFoldersBySession[session.connection.id] ?? []
        return items.isEmpty ? nil : items.count
    }

    private static func ssisChildren(
        for session: ConnectionSession,
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> [ExperimentalObjectBrowserNode] {
        let parentID = ExperimentalObjectBrowserSidebarViewModel.serverFolderNodeID(
            connectionID: session.connection.id,
            kind: .ssis
        )
        let items = viewModel.ssisFoldersBySession[session.connection.id] ?? []
        let isLoading = viewModel.ssisLoadingBySession[session.connection.id] ?? false

        if isLoading {
            return [ExperimentalObjectBrowserNode(id: "\(parentID)#loading", row: .loading("Loading catalogs…", depth: 1))]
        }
        if items.isEmpty {
            return [infoNode(title: "No catalogs found", systemImage: "shippingbox", paletteTitle: "Integration Services Catalogs", depth: 1, parentID: parentID)]
        }
        return items.map {
            ExperimentalObjectBrowserNode(
                id: "\(parentID)#ssis#\($0.name)",
                row: .ssisFolder(session, $0)
            )
        }
    }

    private static func linkedServerCount(
        for session: ConnectionSession,
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> Int? {
        let items = viewModel.linkedServersBySession[session.connection.id] ?? []
        return items.isEmpty ? nil : items.count
    }

    private static func linkedServerChildren(
        for session: ConnectionSession,
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> [ExperimentalObjectBrowserNode] {
        let parentID = ExperimentalObjectBrowserSidebarViewModel.serverFolderNodeID(
            connectionID: session.connection.id,
            kind: .linkedServers
        )
        let items = viewModel.linkedServersBySession[session.connection.id] ?? []
        let isLoading = viewModel.linkedServersLoadingBySession[session.connection.id] ?? false

        if isLoading {
            return [ExperimentalObjectBrowserNode(id: "\(parentID)#loading", row: .loading("Loading linked servers…", depth: 1))]
        }
        if items.isEmpty {
            return [infoNode(title: "No linked servers", systemImage: "link", paletteTitle: "Linked Servers", depth: 1, parentID: parentID)]
        }
        return items.map {
            ExperimentalObjectBrowserNode(
                id: "\(parentID)#linked#\($0.id)",
                row: .linkedServer(session, $0)
            )
        }
    }

    private static func serverTriggerCount(
        for session: ConnectionSession,
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> Int? {
        let items = viewModel.serverTriggersBySession[session.connection.id] ?? []
        return items.isEmpty ? nil : items.count
    }

    private static func serverTriggerChildren(
        for session: ConnectionSession,
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> [ExperimentalObjectBrowserNode] {
        let parentID = ExperimentalObjectBrowserSidebarViewModel.serverFolderNodeID(
            connectionID: session.connection.id,
            kind: .serverTriggers
        )
        let items = viewModel.serverTriggersBySession[session.connection.id] ?? []
        let isLoading = viewModel.serverTriggersLoadingBySession[session.connection.id] ?? false

        if isLoading {
            return [ExperimentalObjectBrowserNode(id: "\(parentID)#loading", row: .loading("Loading server triggers…", depth: 1))]
        }
        if items.isEmpty {
            return [infoNode(title: "No server triggers", systemImage: "bolt", paletteTitle: "Server Triggers", depth: 1, parentID: parentID)]
        }
        return items.map {
            ExperimentalObjectBrowserNode(
                id: "\(parentID)#trigger#\($0.id)",
                row: .serverTrigger(session, $0)
            )
        }
    }

    private static func actionNode(
        _ kind: ExperimentalObjectBrowserActionKind,
        session: ConnectionSession,
        depth: Int,
        parentID: String? = nil
    ) -> ExperimentalObjectBrowserNode {
        let nodeID = ExperimentalObjectBrowserSidebarViewModel.actionNodeID(
            connectionID: session.connection.id,
            parentID: parentID,
            kind: kind
        )
        return ExperimentalObjectBrowserNode(
            id: nodeID,
            row: .action(session, kind, depth: depth)
        )
    }

    private static func infoNode(
        title: String,
        systemImage: String,
        paletteTitle: String,
        depth: Int,
        parentID: String
    ) -> ExperimentalObjectBrowserNode {
        ExperimentalObjectBrowserNode(
            id: ExperimentalObjectBrowserSidebarViewModel.infoNodeID(parentID: parentID, title: title),
            row: .infoLeaf(title, systemImage: systemImage, paletteTitle: paletteTitle, depth: depth)
        )
    }
}
