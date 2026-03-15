import SwiftUI
import EchoSense

extension ObjectBrowserSidebarView {

    // MARK: - Databases Folder

    @ViewBuilder
    func databasesFolderSection(session: ConnectionSession, structure: DatabaseStructure, proxy: ScrollViewProxy) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.databasesFolderExpandedBySession[connID] ?? true
        let isSearching = sidebarSearchQuery != nil

        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            folderHeaderRow(
                title: "Databases",
                icon: "cylinder",
                count: structure.databases.count,
                isExpanded: isExpanded || isSearching
            ) {
                withAnimation(.snappy(duration: 0.2, extraBounce: 0)) {
                    viewModel.databasesFolderExpandedBySession[connID] = !isExpanded
                }
            }

            if isExpanded || isSearching {
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    ForEach(structure.databases, id: \.name) { database in
                        if databaseMatchesSearch(database, session: session) {
                            databaseSection(database: database, session: session, proxy: proxy)
                        }
                    }
                }
                .padding(.leading, SidebarRowConstants.indentStep)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Folder Header Row

    func folderHeaderRow(title: String, icon: String, count: Int?, isExpanded: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ExplorerSidebarRowChrome(isSelected: false, accentColor: ColorTokens.accent, style: .plain) {
                HStack(spacing: SidebarRowConstants.iconTextSpacing) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(SidebarRowConstants.chevronFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .frame(width: SidebarRowConstants.chevronWidth)

                    Image(systemName: icon)
                        .font(SidebarRowConstants.iconFont)
                        .foregroundStyle(ExplorerSidebarPalette.folderIconColor(title: title, colored: projectStore.globalSettings.sidebarColoredIcons))
                        .frame(width: SidebarRowConstants.iconFrame)

                    Text(title)
                        .font(TypographyTokens.standard)
                        .foregroundStyle(ColorTokens.Text.primary)
                        .lineLimit(1)

                    Spacer(minLength: SpacingTokens.xxxs)

                    if let count {
                        Text("\(count)")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
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
    }

    // MARK: - Per-Database Section

    @ViewBuilder
    func databaseSection(database: DatabaseInfo, session: ConnectionSession, proxy: ScrollViewProxy) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.isDatabaseExpanded(connectionID: connID, databaseName: database.name)
        let isSelected = database.name == session.selectedDatabaseName

        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            databaseHeaderRow(
                database: database,
                session: session,
                isExpanded: isExpanded,
                isSelected: isSelected
            )

            if isExpanded {
                let hasSchemas = !database.schemas.isEmpty && database.schemas.contains(where: { !$0.objects.isEmpty })
                databaseContent(database: database, session: session, hasSchemas: hasSchemas, proxy: proxy)
                    .padding(.leading, SidebarRowConstants.indentStep)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func databaseHeaderRow(database: DatabaseInfo, session: ConnectionSession, isExpanded: Bool, isSelected: Bool) -> some View {
        let connID = session.connection.id
        let isLoading = viewModel.isDatabaseLoading(connectionID: connID, databaseName: database.name)
        let accentColor = projectStore.globalSettings.accentColorSource == .connection ? session.connection.color : ColorTokens.accent

        return Button {
            withAnimation(.snappy(duration: 0.2, extraBounce: 0)) {
                viewModel.toggleDatabaseExpanded(connectionID: connID, databaseName: database.name)
            }
            // Update the session's selected database when expanding
            if viewModel.isDatabaseExpanded(connectionID: connID, databaseName: database.name) {
                session.selectedDatabaseName = database.name
            }
        } label: {
            ExplorerSidebarRowChrome(isSelected: isSelected, accentColor: accentColor, style: .plain) {
                HStack(spacing: SidebarRowConstants.iconTextSpacing) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(SidebarRowConstants.chevronFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .frame(width: SidebarRowConstants.chevronWidth)

                    Image(systemName: isSelected ? "internaldrive.fill" : "internaldrive")
                        .font(SidebarRowConstants.iconFont)
                        .foregroundStyle(database.isOnline ? (isSelected ? accentColor : ExplorerSidebarPalette.database) : ColorTokens.Text.quaternary)
                        .frame(width: SidebarRowConstants.iconFrame)

                    Text(database.name)
                        .font(TypographyTokens.standard)
                        .foregroundStyle(database.isOnline ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                        .lineLimit(1)

                    Spacer(minLength: SpacingTokens.xxxs)

                    if !database.isOnline, let state = database.stateDescription {
                        Text(state.uppercased())
                            .font(TypographyTokens.compact)
                            .foregroundStyle(ColorTokens.Text.quaternary)
                            .lineLimit(1)
                    }

                    if isLoading {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                .opacity(database.isOnline ? 1 : 0.5)
                .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
                .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
                .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.plain)
        .contextMenu {
            databaseContextMenu(database: database, session: session)
        }
    }

}
