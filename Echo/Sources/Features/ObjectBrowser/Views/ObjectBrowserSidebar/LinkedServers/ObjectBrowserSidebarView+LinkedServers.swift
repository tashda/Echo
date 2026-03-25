import SwiftUI
import SQLServerKit

extension ObjectBrowserSidebarView {

    // MARK: - Linked Servers Folder Section

    @ViewBuilder
    func linkedServersSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.linkedServersExpandedBySession[connID] ?? false
        let servers = viewModel.linkedServersBySession[connID] ?? []
        let isLoading = viewModel.linkedServersLoadingBySession[connID] ?? false

        let expandedBinding = Binding<Bool>(
            get: { isExpanded },
            set: { newValue in
                viewModel.linkedServersExpandedBySession[connID] = newValue
                if newValue && servers.isEmpty && !isLoading {
                    loadLinkedServers(session: session)
                }
            }
        )

        folderHeaderRow(
            title: "Linked Servers",
            icon: "link",
            count: servers.isEmpty ? nil : servers.count,
            isExpanded: expandedBinding,
            isLoading: isLoading,
            depth: 0
        )

        if isExpanded {
            linkedServersContent(session: session, servers: servers, isLoading: isLoading)
        }
    }

    // MARK: - Content

    @ViewBuilder
    func linkedServersContent(
        session: ConnectionSession,
        servers: [ObjectBrowserSidebarViewModel.LinkedServerItem],
        isLoading: Bool
    ) -> some View {
        if servers.isEmpty {
            SidebarRow(
                depth: 1,
                icon: .none,
                label: isLoading ? "Loading…" : "No linked servers",
                labelColor: ColorTokens.Text.tertiary,
                labelFont: TypographyTokens.detail
            )
        } else {
            ForEach(servers) { server in
                linkedServerRow(server: server, session: session)
            }
        }
    }

    // MARK: - Row

    func linkedServerRow(
        server: ObjectBrowserSidebarViewModel.LinkedServerItem,
        session: ConnectionSession
    ) -> some View {
        Button {
            // No navigation action for linked servers — they are informational
        } label: {
            SidebarRow(
                depth: 1,
                icon: .system("link"),
                label: server.name,
                iconColor: (projectStore.globalSettings.sidebarIconColorMode == .colorful) ? ExplorerSidebarPalette.linkedServers : ExplorerSidebarPalette.monochrome,
                labelColor: server.isDataAccessEnabled ? ColorTokens.Text.primary : ColorTokens.Text.secondary
            ) {
                if !server.dataSource.isEmpty {
                    Text(server.dataSource)
                        .font(SidebarRowConstants.trailingFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            linkedServerContextMenu(server: server, session: session)
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    func linkedServerContextMenu(
        server: ObjectBrowserSidebarViewModel.LinkedServerItem,
        session: ConnectionSession
    ) -> some View {
        Button {
            testLinkedServer(name: server.name, session: session)
        } label: {
            Label("Test Connection", systemImage: "bolt.horizontal")
        }

        Divider()

        Button(role: .destructive) {
            viewModel.dropLinkedServerTarget = .init(
                connectionID: session.connection.id,
                serverName: server.name
            )
            viewModel.showDropLinkedServerAlert = true
        } label: {
            Label("Drop", systemImage: "trash")
        }
        .disabled(!(session.permissions?.canManageLinkedServers ?? true))
        .help(session.permissions?.canManageLinkedServers ?? true ? "" : "Requires sysadmin or setupadmin role")
    }

}
