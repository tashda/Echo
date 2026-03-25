import SwiftUI

extension ObjectBrowserSidebarView {

    @ViewBuilder
    func databaseContent(database: DatabaseInfo, session: ConnectionSession, hasSchemas: Bool, proxy: ScrollViewProxy) -> some View {
        let connID = session.connection.id
        let isLoading = viewModel.isDatabaseLoading(connectionID: connID, databaseName: database.name)
        let alreadyLoaded = viewModel.isDatabaseSchemaLoadedOnce(connectionID: connID, databaseName: database.name)
        let needsLoad = !hasSchemas && !isLoading && !alreadyLoaded

        Group {
            if hasSchemas {
                Color.clear.frame(height: 0)
                    .id("\(connID)-\(database.name)-objects-top")

                DatabaseObjectBrowserView(
                    database: database,
                    connection: session.connection,
                    expandedObjectGroups: viewModel.expandedObjectGroupsBinding(for: connID, database: database.name),
                    expandedObjectIDs: viewModel.expandedObjectIDsBinding(for: connID, database: database.name),
                    pinnedObjectIDs: viewModel.pinnedObjectsBinding(for: database, connectionID: connID),
                    isPinnedSectionExpanded: viewModel.pinnedSectionExpandedBinding(for: database, connectionID: connID),
                    scrollTo: { id, anchor in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(id, anchor: anchor)
                        }
                    },
                    onNewExtension: {
                        environmentState.openExtensionsManagerTab(connectionID: connID, databaseName: database.name)
                    }
                )
                .environment(environmentState)
                .environment(viewModel)

                // Database-level Security
                if session.connection.databaseType == .microsoftSQL || session.connection.databaseType == .postgresql {
                    databaseSecuritySection(database: database, session: session)
                        .environment(viewModel)
                }

                // Query Store (MSSQL only)
                if session.connection.databaseType == .microsoftSQL && database.isOnline {
                    queryStoreRow(database: database, session: session)
                    databaseDDLTriggersSection(database: database, session: session)
                    serviceBrokerSection(database: database, session: session)
                    externalResourcesSection(database: database, session: session)
                }
            } else if alreadyLoaded {
                // Schema was fetched but the database has no user objects — don't re-fetch
                SidebarRow(
                    depth: 2,
                    icon: .none,
                    label: "No objects",
                    labelColor: ColorTokens.Text.tertiary,
                    labelFont: TypographyTokens.detail
                )
            } else {
                // Invisible anchor — must be a real view so .onAppear fires and triggers schema loading.
                Color.clear.frame(height: 0)
            }
        }
        .onAppear {
            guard needsLoad else { return }
            // Use an unstructured Task so SwiftUI view re-renders (caused by
            // setDatabaseLoading) cannot cancel the in-flight connection.
            Task { @MainActor in
                viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: true)
                await environmentState.loadSchemaForDatabase(database.name, connectionSession: session)
                viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: false)
            }
        }
    }

    // MARK: - Query Store Row

    @ViewBuilder
    func queryStoreRow(database: DatabaseInfo, session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful

        Button {
            environmentState.openQueryStoreTab(connectionID: connID, databaseName: database.name)
        } label: {
            SidebarRow(
                depth: 2,
                icon: .system("chart.bar"),
                label: "Query Store",
                iconColor: ExplorerSidebarPalette.folderIconColor(title: "Query Store", colored: colored)
            )
        }
        .buttonStyle(.plain)
    }
}
