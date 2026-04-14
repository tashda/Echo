import Foundation

extension ExperimentalObjectBrowserSnapshotBuilder {
    static func securityChildren(
        for session: ConnectionSession,
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> [ExperimentalObjectBrowserNode] {
        let connectionID = session.connection.id
        let parentID = ExperimentalObjectBrowserSidebarViewModel.serverFolderNodeID(
            connectionID: connectionID,
            kind: .security
        )
        let isLoading = viewModel.securityServerLoadingBySession[connectionID] ?? false

        switch session.connection.databaseType {
        case .microsoftSQL:
            return mssqlSecurityChildren(
                for: session,
                parentID: parentID,
                isLoading: isLoading,
                viewModel: viewModel
            )
        case .postgresql:
            return postgresSecurityChildren(
                for: session,
                parentID: parentID,
                isLoading: isLoading,
                viewModel: viewModel
            )
        case .mysql, .sqlite:
            return []
        }
    }

    private static func mssqlSecurityChildren(
        for session: ConnectionSession,
        parentID: String,
        isLoading: Bool,
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> [ExperimentalObjectBrowserNode] {
        let connectionID = session.connection.id
        let loginsSectionID = ExperimentalObjectBrowserSidebarViewModel.securitySectionNodeID(
            connectionID: connectionID,
            kind: .logins,
            parentID: parentID
        )
        let serverRolesSectionID = ExperimentalObjectBrowserSidebarViewModel.securitySectionNodeID(
            connectionID: connectionID,
            kind: .serverRoles,
            parentID: parentID
        )
        let credentialsSectionID = ExperimentalObjectBrowserSidebarViewModel.securitySectionNodeID(
            connectionID: connectionID,
            kind: .credentials,
            parentID: parentID
        )
        let allLogins = viewModel.securityLoginsBySession[connectionID] ?? []
        let standardLogins = allLogins.filter { !certificateLoginTypes.contains($0.loginType) }
        let certificateLogins = allLogins.filter { certificateLoginTypes.contains($0.loginType) }
        let serverRoles = viewModel.securityServerRolesBySession[connectionID] ?? []
        let credentials = viewModel.securityCredentialsBySession[connectionID] ?? []

        return [
            securitySectionNode(
                .logins,
                session: session,
                count: standardLogins.count,
                isLoading: isLoading,
                parentID: parentID,
                children: standardLoginChildren(
                    for: session,
                    parentID: loginsSectionID,
                    items: standardLogins,
                    certificateLogins: certificateLogins,
                    isLoading: isLoading
                )
            ),
            securitySectionNode(
                .serverRoles,
                session: session,
                count: serverRoles.count,
                isLoading: isLoading,
                parentID: parentID,
                children: serverRoleChildren(for: session, parentID: serverRolesSectionID, items: serverRoles, isLoading: isLoading)
            ),
            securitySectionNode(
                .credentials,
                session: session,
                count: credentials.count,
                isLoading: isLoading,
                parentID: parentID,
                children: credentialChildren(for: session, parentID: credentialsSectionID, items: credentials, isLoading: isLoading)
            )
        ]
    }

    private static func postgresSecurityChildren(
        for session: ConnectionSession,
        parentID: String,
        isLoading: Bool,
        viewModel: ExperimentalObjectBrowserSidebarViewModel
    ) -> [ExperimentalObjectBrowserNode] {
        let connectionID = session.connection.id
        let loginRolesSectionID = ExperimentalObjectBrowserSidebarViewModel.securitySectionNodeID(
            connectionID: connectionID,
            kind: .pgLoginRoles,
            parentID: parentID
        )
        let groupRolesSectionID = ExperimentalObjectBrowserSidebarViewModel.securitySectionNodeID(
            connectionID: connectionID,
            kind: .pgGroupRoles,
            parentID: parentID
        )
        let allRoles = viewModel.securityLoginsBySession[connectionID] ?? []
        let loginRoles = allRoles.filter { $0.loginType.contains("Login") || $0.loginType.contains("Superuser") }
        let groupRoles = allRoles.filter { $0.loginType == "Group Role" }

        return [
            securitySectionNode(
                .pgLoginRoles,
                session: session,
                count: loginRoles.count,
                isLoading: isLoading,
                parentID: parentID,
                children: securityLoginChildren(
                    for: session,
                    parentID: loginRolesSectionID,
                    sectionKind: .pgLoginRoles,
                    items: loginRoles,
                    emptyTitle: "No login roles found",
                    isLoading: isLoading
                )
            ),
            securitySectionNode(
                .pgGroupRoles,
                session: session,
                count: groupRoles.count,
                isLoading: isLoading,
                parentID: parentID,
                children: securityLoginChildren(
                    for: session,
                    parentID: groupRolesSectionID,
                    sectionKind: .pgGroupRoles,
                    items: groupRoles,
                    emptyTitle: "No group roles found",
                    isLoading: isLoading
                )
            )
        ]
    }

    private static func standardLoginChildren(
        for session: ConnectionSession,
        parentID: String,
        items: [ExperimentalObjectBrowserSidebarViewModel.SecurityLoginItem],
        certificateLogins: [ExperimentalObjectBrowserSidebarViewModel.SecurityLoginItem],
        isLoading: Bool
    ) -> [ExperimentalObjectBrowserNode] {
        let connectionID = session.connection.id
        let loginsParentID = ExperimentalObjectBrowserSidebarViewModel.securitySectionNodeID(
            connectionID: connectionID,
            kind: .logins,
            parentID: parentID
        )
        var children = securityLoginChildren(
            for: session,
            parentID: loginsParentID,
            sectionKind: .logins,
            items: items,
            emptyTitle: "No logins found",
            isLoading: isLoading
        )

        if !certificateLogins.isEmpty {
            children.append(
                securitySectionNode(
                    .certificateLogins,
                    session: session,
                    count: certificateLogins.count,
                    isLoading: false,
                    parentID: loginsParentID,
                    children: securityLoginChildren(
                        for: session,
                        parentID: loginsParentID,
                        sectionKind: .certificateLogins,
                        items: certificateLogins,
                        emptyTitle: "No certificate logins found",
                        isLoading: isLoading
                    )
                )
            )
        }

        return children
    }

    private static func securityLoginChildren(
        for session: ConnectionSession,
        parentID: String,
        sectionKind: ExperimentalObjectBrowserSecuritySectionKind,
        items: [ExperimentalObjectBrowserSidebarViewModel.SecurityLoginItem],
        emptyTitle: String,
        isLoading: Bool
    ) -> [ExperimentalObjectBrowserNode] {
        if isLoading && items.isEmpty {
            return [
                ExperimentalObjectBrowserNode(
                    id: "\(parentID)#loading",
                    row: .loading("Loading \(sectionKind.title.lowercased())…", depth: 2)
                )
            ]
        }
        if items.isEmpty {
            return [
                ExperimentalObjectBrowserNode(
                    id: ExperimentalObjectBrowserSidebarViewModel.infoNodeID(parentID: parentID, title: emptyTitle),
                    row: .infoLeaf(emptyTitle, systemImage: sectionKind.systemImage, paletteTitle: sectionKind.title, depth: 2)
                )
            ]
        }

        return items.map {
            ExperimentalObjectBrowserNode(
                id: ExperimentalObjectBrowserSidebarViewModel.securityLeafNodeID(
                    connectionID: session.connection.id,
                    parentID: parentID,
                    kind: sectionKind,
                    name: $0.name
                ),
                row: .securityLogin(session, $0)
            )
        }
    }

    private static func serverRoleChildren(
        for session: ConnectionSession,
        parentID: String,
        items: [ExperimentalObjectBrowserSidebarViewModel.SecurityServerRoleItem],
        isLoading: Bool
    ) -> [ExperimentalObjectBrowserNode] {
        if isLoading && items.isEmpty {
            return [
                ExperimentalObjectBrowserNode(
                    id: "\(parentID)#loading",
                    row: .loading("Loading server roles…", depth: 2)
                )
            ]
        }
        if items.isEmpty {
            return [
                ExperimentalObjectBrowserNode(
                    id: ExperimentalObjectBrowserSidebarViewModel.infoNodeID(parentID: parentID, title: "No server roles found"),
                    row: .infoLeaf("No server roles found", systemImage: "shield", paletteTitle: "Server Roles", depth: 2)
                )
            ]
        }

        return items.map {
            ExperimentalObjectBrowserNode(
                id: ExperimentalObjectBrowserSidebarViewModel.securityLeafNodeID(
                    connectionID: session.connection.id,
                    parentID: parentID,
                    kind: .serverRoles,
                    name: $0.name
                ),
                row: .securityServerRole(session, $0)
            )
        }
    }

    private static func credentialChildren(
        for session: ConnectionSession,
        parentID: String,
        items: [ExperimentalObjectBrowserSidebarViewModel.SecurityCredentialItem],
        isLoading: Bool
    ) -> [ExperimentalObjectBrowserNode] {
        if isLoading && items.isEmpty {
            return [
                ExperimentalObjectBrowserNode(
                    id: "\(parentID)#loading",
                    row: .loading("Loading credentials…", depth: 2)
                )
            ]
        }
        if items.isEmpty {
            return [
                ExperimentalObjectBrowserNode(
                    id: ExperimentalObjectBrowserSidebarViewModel.infoNodeID(parentID: parentID, title: "No credentials found"),
                    row: .infoLeaf("No credentials found", systemImage: "key", paletteTitle: "Credentials", depth: 2)
                )
            ]
        }

        return items.map {
            ExperimentalObjectBrowserNode(
                id: ExperimentalObjectBrowserSidebarViewModel.securityLeafNodeID(
                    connectionID: session.connection.id,
                    parentID: parentID,
                    kind: .credentials,
                    name: $0.name
                ),
                row: .securityCredential(session, $0)
            )
        }
    }

    private static func securitySectionNode(
        _ kind: ExperimentalObjectBrowserSecuritySectionKind,
        session: ConnectionSession,
        count: Int,
        isLoading: Bool,
        parentID: String,
        children: [ExperimentalObjectBrowserNode]
    ) -> ExperimentalObjectBrowserNode {
        let sectionID = ExperimentalObjectBrowserSidebarViewModel.securitySectionNodeID(
            connectionID: session.connection.id,
            kind: kind,
            parentID: parentID
        )
        return ExperimentalObjectBrowserNode(
            id: sectionID,
            row: .securitySection(session, kind, count: count, isLoading: isLoading),
            children: children
        )
    }

    private static let certificateLoginTypes: Set<String> = ["Certificate", "Asymmetric Key"]
}
