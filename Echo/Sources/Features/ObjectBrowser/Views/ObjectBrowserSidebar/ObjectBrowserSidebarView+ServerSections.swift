import SwiftUI

extension ObjectBrowserSidebarView {

    // MARK: - Server Section

    @ViewBuilder
    func serverSection(session: ConnectionSession, proxy: ScrollViewProxy) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.expandedServerIDs.contains(connID)
        let isSelected = connID == selectedConnectionID

        let isSearching = sidebarSearchQuery != nil
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            serverHeaderRow(session: session, isExpanded: isExpanded || isSearching, isSelected: isSelected)

            if isExpanded || isSearching {
                serverContent(session: session, proxy: proxy)
                    .padding(.leading, SidebarRowConstants.indentStep)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { viewModel.initializeSessionState(for: session, autoExpandSections: projectStore.globalSettings.sidebarExpandSections(for: session.connection.databaseType)) }
    }

    func serverHeaderRow(session: ConnectionSession, isExpanded: Bool, isSelected: Bool) -> some View {
        let accentColor = projectStore.globalSettings.accentColorSource == .connection ? session.connection.color : ColorTokens.accent

        return Button {
            withAnimation(.snappy(duration: 0.2, extraBounce: 0)) {
                if isExpanded {
                    viewModel.expandedServerIDs.remove(session.connection.id)
                } else {
                    viewModel.expandedServerIDs.insert(session.connection.id)
                }
            }
            selectedConnectionID = session.connection.id
            environmentState.sessionGroup.setActiveSession(session.id)
        } label: {
            ExplorerSidebarRowChrome(isSelected: false, accentColor: accentColor, style: .plain) {
                HStack(spacing: SidebarRowConstants.iconTextSpacing) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(SidebarRowConstants.chevronFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .frame(width: SidebarRowConstants.chevronWidth)

                    Image(session.connection.databaseType.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: SidebarRowConstants.iconFrame, height: SidebarRowConstants.iconFrame)

                    Text(serverDisplayName(session))
                        .font(isSelected ? TypographyTokens.standard.weight(.semibold) : TypographyTokens.standard)
                        .foregroundStyle(session.isConnected ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
                        .lineLimit(1)

                    if let version = serverVersionLabel(session) {
                        Text(version)
                            .font(TypographyTokens.compact)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                            .padding(.horizontal, SpacingTokens.xxs)
                            .padding(.vertical, SpacingTokens.xxs2)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(ColorTokens.Text.primary.opacity(0.06))
                            )
                            .lineLimit(1)
                    }

                    Spacer(minLength: SpacingTokens.xxxs)
                }
                .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
                .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
                .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            serverContextMenu(session: session)
        }
    }

    // MARK: - Server Content (Folder Groups)

    @ViewBuilder
    func serverContent(session: ConnectionSession, proxy: ScrollViewProxy) -> some View {
        switch session.structureLoadingState {
        case .ready, .loading:
            if let structure = session.databaseStructure, !structure.databases.isEmpty {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    databasesFolderSection(session: session, structure: structure, proxy: proxy)

                    // Security folder — MSSQL and PostgreSQL
                    if session.connection.databaseType == .microsoftSQL || session.connection.databaseType == .postgresql {
                        securityFolderSection(session: session)
                    }

                    if session.connection.databaseType == .microsoftSQL {
                        agentJobsSection(session: session)
                        linkedServersSection(session: session)
                    }
                }
            } else if session.databaseStructure != nil {
                loadingHint()
            } else {
                loadingHint()
            }
        case .idle:
            loadingHint()
        case .failed(let message):
            failureHint(message: message, session: session)
        }
    }
}
