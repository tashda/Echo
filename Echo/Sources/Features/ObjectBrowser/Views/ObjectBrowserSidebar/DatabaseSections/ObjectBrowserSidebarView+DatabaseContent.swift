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
                VStack(spacing: SpacingTokens.xxxs) {
                    Color.clear.frame(height: 0)
                        .id("\(connID)-\(database.name)-objects-top")

                    DatabaseObjectBrowserView(
                        database: database,
                        connection: session.connection,
                        searchText: $viewModel.debouncedSearchText,
                        selectedSchemaName: viewModel.selectedSchemaNameBinding(for: connID, database: database.name),
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
                    .padding(.horizontal, SpacingTokens.xxs)

                    // Database-level Security
                    if session.connection.databaseType == .microsoftSQL || session.connection.databaseType == .postgresql {
                        databaseSecuritySection(database: database, session: session)
                            .environment(viewModel)
                            .padding(.horizontal, SpacingTokens.xxs)
                    }
                }
            } else if alreadyLoaded {
                // Schema was fetched but the database has no user objects — don't re-fetch
                Text("No objects")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .padding(.horizontal, SpacingTokens.sm)
                    .padding(.vertical, SpacingTokens.xxs)
            } else {
                HStack(spacing: SpacingTokens.xxs2) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading\u{2026}")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .padding(.horizontal, SpacingTokens.sm)
                .padding(.vertical, SpacingTokens.xxs)
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
}
