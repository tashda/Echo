import SwiftUI
import PostgresKit
import SQLServerKit

// MARK: - Server-Level Security Folder

extension ObjectBrowserSidebarView {

    @ViewBuilder
    func securityFolderSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.securityFolderExpandedBySession[connID] ?? false

        let expandedBinding = Binding<Bool>(
            get: { isExpanded },
            set: { newValue in
                viewModel.securityFolderExpandedBySession[connID] = newValue
                if newValue {
                    loadServerSecurityIfNeeded(session: session)
                }
            }
        )

        folderHeaderRow(
            title: "Security",
            icon: "shield",
            count: nil,
            isExpanded: expandedBinding,
            depth: 0
        )
        .contextMenu {
            securityFolderContextMenu(session: session)
        }

        if isExpanded {
            serverSecurityContent(session: session)
        }
    }

    // MARK: - Flat List Row Security (for per-item context menus)

    @ViewBuilder
    func securityFolderListRows(session: ConnectionSession, baseIndent: CGFloat) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.securityFolderExpandedBySession[connID] ?? false

        sidebarListRow(leading: baseIndent) {
            folderHeaderRow(
                title: "Security",
                icon: "shield",
                count: nil,
                isExpanded: Binding<Bool>(
                    get: { isExpanded },
                    set: { newValue in
                        viewModel.securityFolderExpandedBySession[connID] = newValue
                        if newValue {
                            loadServerSecurityIfNeeded(session: session)
                        }
                    }
                )
            )
            .contextMenu {
                securityFolderContextMenu(session: session)
            }
        }

        if isExpanded {
            serverSecurityListRows(session: session, baseIndent: baseIndent + SidebarRowConstants.indentStep)
        }
    }

    @ViewBuilder
    func serverSecurityListRows(session: ConnectionSession, baseIndent: CGFloat) -> some View {
        switch session.connection.databaseType {
        case .microsoftSQL:
            loginsListRows(session: session, baseIndent: baseIndent)
            serverRolesListRows(session: session, baseIndent: baseIndent)
            credentialsListRows(session: session, baseIndent: baseIndent)
        case .postgresql:
            pgLoginRolesListRows(session: session, baseIndent: baseIndent)
            pgGroupRolesListRows(session: session, baseIndent: baseIndent)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    func serverSecurityContent(session: ConnectionSession) -> some View {
        switch session.connection.databaseType {
        case .microsoftSQL:
            loginsSection(session: session)
            serverRolesSection(session: session)
            credentialsSection(session: session)
        case .postgresql:
            pgLoginRolesSection(session: session)
            pgGroupRolesSection(session: session)
        default:
            EmptyView()
        }
    }
}
