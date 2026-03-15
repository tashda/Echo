import SwiftUI
import PostgresKit
import SQLServerKit

// MARK: - Server-Level Security Folder

extension ObjectBrowserSidebarView {

    @ViewBuilder
    func securityFolderSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.securityFolderExpandedBySession[connID] ?? false

        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            folderHeaderRow(
                title: "Security",
                icon: "lock.shield",
                count: nil,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.securityFolderExpandedBySession[connID] = !isExpanded
                }
                if !isExpanded {
                    loadServerSecurityIfNeeded(session: session)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    serverSecurityContent(session: session)
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
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
                icon: "lock.shield",
                count: nil,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.securityFolderExpandedBySession[connID] = !isExpanded
                }
                if !isExpanded {
                    loadServerSecurityIfNeeded(session: session)
                }
            }
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
        let connID = session.connection.id
        let isLoading = viewModel.securityServerLoadingBySession[connID] ?? false
        let hasData = !(viewModel.securityLoginsBySession[connID] ?? []).isEmpty
            || !(viewModel.securityServerRolesBySession[connID] ?? []).isEmpty

        if isLoading && !hasData {
            sidebarListRow(leading: baseIndent) {
                securityLoadingRow("Loading security\u{2026}")
            }
        }

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
        let connID = session.connection.id
        let isLoading = viewModel.securityServerLoadingBySession[connID] ?? false
        let hasData = !(viewModel.securityLoginsBySession[connID] ?? []).isEmpty
            || !(viewModel.securityServerRolesBySession[connID] ?? []).isEmpty

        if isLoading && !hasData {
            securityLoadingRow("Loading security\u{2026}")
        }

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
