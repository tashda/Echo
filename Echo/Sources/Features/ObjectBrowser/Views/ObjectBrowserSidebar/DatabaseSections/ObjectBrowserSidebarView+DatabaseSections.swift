import SwiftUI
import EchoSense

extension ObjectBrowserSidebarView {

    // MARK: - Databases Folder

    @ViewBuilder
    func databasesFolderSection(session: ConnectionSession, structure: DatabaseStructure, proxy: ScrollViewProxy) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.databasesFolderExpandedBySession[connID] ?? true
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful
        let expandedBinding = Binding<Bool>(
            get: { isExpanded },
            set: { _ in
                withAnimation(.snappy(duration: 0.2, extraBounce: 0)) {
                    viewModel.databasesFolderExpandedBySession[connID] = !isExpanded
                }
            }
        )

        let hideInaccessible = projectStore.globalSettings.hideInaccessibleDatabases
        let hideOffline = viewModel.hideOfflineDatabasesBySession[connID] ?? false
        let displayCount = structure.databases
            .filter { !hideInaccessible || $0.isAccessible }
            .filter { !hideOffline || $0.isOnline }
            .count

        Button {
            expandedBinding.wrappedValue.toggle()
        } label: {
            SidebarRow(
                depth: 0,
                icon: .system("cylinder"),
                label: "Databases",
                isExpanded: expandedBinding,
                iconColor: ExplorerSidebarPalette.folderIconColor(title: "Databases", colored: colored)
            ) {
                Text("\(displayCount)")
                    .font(SidebarRowConstants.trailingFont)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
        .contextMenu {
            databasesFolderContextMenu(session: session)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if isExpanded {
            let visibleDatabases = structure.databases
                .filter { !hideInaccessible || $0.isAccessible }
                .filter { !hideOffline || $0.isOnline }
            let identifiedDatabases = visibleDatabases.map { database in
                (
                    id: ExplorerSidebarIdentity.database(connectionID: connID, databaseName: database.name),
                    database: database
                )
            }
            ForEach(identifiedDatabases, id: \.id) { item in
                databaseSection(database: item.database, session: session, proxy: proxy)
            }
        }
    }

    // MARK: - Folder Header Row (used by Security, Agent Jobs, Linked Servers)

    func folderHeaderRow(
        title: String,
        icon: String,
        count: Int?,
        isExpanded: Binding<Bool>,
        isLoading: Bool = false,
        depth: Int = 0
    ) -> some View {
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful
        let animatedBinding = Binding<Bool>(
            get: { isExpanded.wrappedValue },
            set: { newValue in
                withAnimation(.snappy(duration: 0.2, extraBounce: 0)) {
                    isExpanded.wrappedValue = newValue
                }
            }
        )

        return Button {
            animatedBinding.wrappedValue.toggle()
        } label: {
            SidebarRow(
                depth: depth,
                icon: .system(icon),
                label: title,
                isExpanded: animatedBinding,
                iconColor: ExplorerSidebarPalette.folderIconColor(title: title, colored: colored)
            ) {
                if let count {
                    Text("\(count)")
                        .font(SidebarRowConstants.trailingFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
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
        let isSelected = database.name == session.sidebarFocusedDatabase
        let accentColor = projectStore.globalSettings.accentColorSource == .connection ? session.connection.color : ColorTokens.accent

        databaseHeaderRow(
            database: database,
            session: session,
            isExpanded: isExpanded,
            isSelected: isSelected,
            accentColor: accentColor
        )

        if isExpanded {
            DatabaseContentView(databaseName: database.name, session: session) { liveDatabase, hasSchemas in
                databaseContent(database: liveDatabase, session: session, hasSchemas: hasSchemas, proxy: proxy)
            }
        }
    }

    func databaseHeaderRow(database: DatabaseInfo, session: ConnectionSession, isExpanded: Bool, isSelected: Bool, accentColor: Color) -> some View {
        let connID = session.connection.id
        let isLoading = session.isRefreshingMetadata(forDatabase: database.name)
        let isAvailable = database.isOnline && database.isAccessible
        let expandedBinding = Binding<Bool>(
            get: { isExpanded },
            set: { _ in
                guard database.isAccessible else { return }
                withAnimation(.snappy(duration: 0.2, extraBounce: 0)) {
                    viewModel.toggleDatabaseExpanded(connectionID: connID, databaseName: database.name)
                }
                if viewModel.isDatabaseExpanded(connectionID: connID, databaseName: database.name) {
                    session.sidebarFocusedDatabase = database.name
                }
            }
        )

        return Button {
            guard database.isAccessible else { return }
            expandedBinding.wrappedValue.toggle()
        } label: {
            SidebarRow(
                depth: 1,
                icon: .system("internaldrive"),
                label: database.name,
                isExpanded: expandedBinding,
                isSelected: isSelected,
                iconColor: isAvailable ? (isSelected ? accentColor : (projectStore.globalSettings.sidebarIconColorMode == .colorful ? ExplorerSidebarPalette.databaseInstance : ExplorerSidebarPalette.monochrome)) : ColorTokens.Text.quaternary,
                labelColor: isAvailable ? ColorTokens.Text.primary : ColorTokens.Text.secondary,
                accentColor: accentColor
            ) {
                if !database.isOnline, let state = database.stateDescription {
                    Text(state.uppercased())
                        .font(TypographyTokens.compact)
                        .foregroundStyle(ColorTokens.Text.quaternary)
                        .lineLimit(1)
                } else if !database.isAccessible {
                    Text("NO ACCESS")
                        .font(TypographyTokens.compact)
                        .foregroundStyle(ColorTokens.Text.quaternary)
                        .lineLimit(1)
                }
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            .opacity(isAvailable ? 1 : 0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.plain)
        .lazyContextMenu { [viewModel, sheetState, environmentState, projectStore, openWindow] in
            buildDatabaseNSMenu(
                database: database, session: session,
                viewModel: viewModel, sheetState: sheetState,
                environmentState: environmentState, projectStore: projectStore,
                openWindow: openWindow,
                runMSSQLTask: { session, db, taskName in
                    let task: MSSQLDatabaseTask = switch taskName {
                    case "shrink": .shrink
                    case "takeOffline": .takeOffline
                    case "bringOnline": .bringOnline
                    default: .shrink
                    }
                    Task { await self.runMSSQLTask(session: session, database: db, task: task) }
                }
            )
        }
    }
}
