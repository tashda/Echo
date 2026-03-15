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

        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            folderHeaderRow(
                title: "Linked Servers",
                icon: "link",
                count: servers.isEmpty ? nil : servers.count,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.linkedServersExpandedBySession[connID] = !isExpanded
                }
                if !isExpanded && servers.isEmpty && !isLoading {
                    loadLinkedServers(session: session)
                }
            }

            if isExpanded {
                linkedServersContent(session: session, servers: servers, isLoading: isLoading)
                    .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    func linkedServersContent(
        session: ConnectionSession,
        servers: [ObjectBrowserSidebarViewModel.LinkedServerItem],
        isLoading: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                linkedServersLoadingIndicator()
            } else if !servers.isEmpty {
                ForEach(servers) { server in
                    linkedServerRow(server: server, session: session)
                }
            }

            newLinkedServerButton(session: session)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Row

    func linkedServerRow(
        server: ObjectBrowserSidebarViewModel.LinkedServerItem,
        session: ConnectionSession
    ) -> some View {
        Button {
            // No navigation action for linked servers — they are informational
        } label: {
            HStack(spacing: SpacingTokens.xs) {
                Spacer().frame(width: SidebarRowConstants.chevronWidth)

                Image(systemName: "link")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ExplorerSidebarPalette.linkedServers)
                    .frame(width: SidebarRowConstants.iconFrame)

                Text(server.name)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(server.isDataAccessEnabled ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 4)

                if !server.dataSource.isEmpty {
                    Text(server.dataSource)
                        .font(TypographyTokens.compact)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
            .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - New Linked Server Button

    func newLinkedServerButton(session: ConnectionSession) -> some View {
        Button {
            viewModel.newLinkedServerSessionID = session.connection.id
            viewModel.showNewLinkedServerSheet = true
        } label: {
            HStack(spacing: SpacingTokens.xs) {
                Spacer().frame(width: SidebarRowConstants.chevronWidth)

                Image(systemName: "plus.circle")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .frame(width: SidebarRowConstants.iconFrame)

                Text("New Linked Server\u{2026}")
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .lineLimit(1)

                Spacer(minLength: 4)
            }
            .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
            .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading Indicator

    func linkedServersLoadingIndicator() -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Spacer().frame(width: SidebarRowConstants.chevronWidth)
            ProgressView()
                .controlSize(.mini)
            Text("Loading linked servers\u{2026}")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}
