import SwiftUI

extension ObjectBrowserSidebarView {

    @ViewBuilder
    func databaseContent(database: DatabaseInfo, session: ConnectionSession, hasSchemas: Bool, proxy: ScrollViewProxy) -> some View {
        let connID = session.connection.id
        let isLoading = session.isRefreshingMetadata(forDatabase: database.name)

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

                    // Replication (Postgres only)
                    if session.connection.databaseType == .postgresql {
                        postgresReplicationSection(database: database, session: session)
                            .environment(viewModel)
                    }

                    // Database-level Security
                    if session.connection.databaseType == .microsoftSQL || session.connection.databaseType == .postgresql {
                        databaseSecuritySection(database: database, session: session)
                            .environment(viewModel)
                    }

                    // Advanced Objects (Postgres only)
                    if session.connection.databaseType == .postgresql {
                        postgresAdvancedObjectsSection(database: database, session: session)
                            .environment(viewModel)
                    }

                    // DDL Triggers, Service Broker, External Resources (MSSQL only)
                    if session.connection.databaseType == .microsoftSQL && database.isOnline {
                        databaseDDLTriggersSection(database: database, session: session)
                        serviceBrokerSection(database: database, session: session)
                        externalResourcesSection(database: database, session: session)
                    }
            } else {
                // No schemas yet — show loading indicator. This covers:
                // - Load not started yet (needsLoad=true, .onAppear will trigger)
                // - Load in progress (isLoading=true)
                // - Load completed but ForEach hasn't re-iterated with updated data yet
                // - Initial structure load still running
                // If the database genuinely has no objects, this will show briefly
                // then the empty type sections (Tables 0, Views 0, etc.) will appear.
                SidebarRow(
                    depth: 2,
                    icon: .none,
                    label: "Loading…",
                    labelColor: ColorTokens.Text.tertiary,
                    labelFont: TypographyTokens.detail
                ) {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
        }
        .onAppear {
            loadSchemaIfNeeded(connID: connID, database: database, session: session)
        }
        .onChange(of: database.schemas.isEmpty) { _, _ in
            // Re-check after structure updates — schemas may have arrived
        }
        .onChange(of: isLoading) { _, _ in
            // Re-check after loading state changes
        }
    }

    private func loadSchemaIfNeeded(connID: UUID, database: DatabaseInfo, session: ConnectionSession) {
        let hasSchemas = !database.schemas.isEmpty && database.schemas.contains(where: { !$0.objects.isEmpty })
        let freshness = session.metadataFreshness(forDatabase: database.name)
        let isLoading = session.isRefreshingMetadata(forDatabase: database.name)
        let needsLoad = switch freshness {
        case .cached:
            !isLoading
        case .listOnly:
            !isLoading
        case .refreshing, .live, .failed:
            false
        }
        guard needsLoad else { return }

        Task { @MainActor in
            let loadStart = CFAbsoluteTimeGetCurrent()
            let structureState = session.structureLoadingState
            print("[PERF] \(database.name): load started (structureState=\(structureState), existingDBCount=\(session.databaseStructure?.databases.count ?? 0))")
            session.markMetadataRefreshStarted(forDatabase: database.name)
            guard session.beginSchemaLoad(forDatabase: database.name) else { return }
            await environmentState.loadSchemaForDatabase(database.name, connectionSession: session)
            session.finishSchemaLoad(forDatabase: database.name)
            let loadEnd = CFAbsoluteTimeGetCurrent()
            print("[PERF] \(database.name): load completed in \(String(format: "%.3f", loadEnd - loadStart))s, UI update pending")

            let updatedDB = session.databaseStructure?.databases.first(where: { $0.name == database.name })
            let gotSchemas = updatedDB?.schemas.contains(where: { !$0.objects.isEmpty }) ?? false
            if !gotSchemas && freshness == .cached && hasSchemas {
                session.markMetadataRefreshCompleted(forDatabase: database.name, hasSchemas: true)
            }

            if session.connection.databaseType == .postgresql {
                await loadPublicationsIfNeeded(session: session, database: database.name)
                await loadSubscriptionsIfNeeded(session: session, database: database.name)
            }
        }
    }

}
