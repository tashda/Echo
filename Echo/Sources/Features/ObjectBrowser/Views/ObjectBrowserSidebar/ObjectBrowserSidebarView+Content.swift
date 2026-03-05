import SwiftUI

extension ObjectBrowserSidebarView {
    @ViewBuilder
    func explorerContent(proxy: ScrollViewProxy) -> some View {
        Group {
            if let session = selectedSession {
                switch session.structureLoadingState {
                case .ready, .loading:
                    if let structure = session.databaseStructure,
                       let database = selectedDatabase(in: structure, for: session) {
                        VStack(spacing: 16) {
                            Color.clear.frame(height: 0)
                                .id(ExplorerSidebarConstants.objectsTopAnchor)

                            DatabaseObjectBrowserView(
                                database: database,
                                connection: session.connection,
                                searchText: $viewModel.debouncedSearchText,
                                selectedSchemaName: $viewModel.selectedSchemaName,
                                expandedObjectGroups: $viewModel.expandedObjectGroups,
                                expandedObjectIDs: $viewModel.expandedObjectIDs,
                                pinnedObjectIDs: viewModel.pinnedObjectsBinding(for: database, connectionID: session.connection.id),
                                isPinnedSectionExpanded: viewModel.pinnedSectionExpandedBinding(for: database, connectionID: session.connection.id),
                                scrollTo: { id, anchor in
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        proxy.scrollTo(id, anchor: anchor)
                                    }
                                }
                            )
                            .environmentObject(environmentState)
                            .padding(.horizontal, SpacingTokens.xxs)
                        }
                    } else if let structure = session.databaseStructure,
                              !structure.databases.isEmpty {
                        noDatabaseSelectedView
                            .padding(.horizontal, SpacingTokens.md)
                            .padding(.top, SpacingTokens.lg)
                    } else {
                        loadingPlaceholder("Preparing database structure…")
                            .padding(.horizontal, SpacingTokens.md)
                            .padding(.top, SpacingTokens.lg)
                    }
                case .idle:
                    loadingPlaceholder("Waiting to load database structure…")
                        .padding(.horizontal, SpacingTokens.md)
                        .padding(.top, SpacingTokens.lg)
                case .failed(let message):
                    failureView(message: message)
                        .padding(.horizontal, SpacingTokens.md)
                        .padding(.top, SpacingTokens.lg)
                }
            } else {
                emptyStateView
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.top, SpacingTokens.xl)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard let session = selectedSession, session.selectedDatabaseName != nil else { return }
            if viewModel.isHoveringConnectedServers {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.isHoveringConnectedServers = false
                }
            }
        }
    }

    func loadingPlaceholder(_ message: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(message)
                .font(TypographyTokens.standard.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, SpacingTokens.xl2)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    func failureView(message: String?) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.orange)
            Text(message ?? "Failed to load database structure")
                .font(TypographyTokens.standard.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Retry") {
                Task { await refreshSelectedSessionStructure() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, SpacingTokens.xl)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    var noDatabaseSelectedView: some View {
        VStack(spacing: 14) {
            Image(systemName: "cylinder.split.1x2")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Select a Database")
                .font(.system(size: 15, weight: .semibold))
            Text("Choose a database from the Currently Connected Servers list to browse schemas and objects.")
                .font(TypographyTokens.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 220)
        }
        .padding(.vertical, SpacingTokens.xl)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No Database Connected")
                .font(TypographyTokens.displayLarge.weight(.semibold))
            Text("Connect to a server to explore its schemas, tables, and functions.")
                .font(TypographyTokens.standard)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
        }
        .padding(.vertical, SpacingTokens.xxl)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    func selectedDatabase(in structure: DatabaseStructure, for session: ConnectionSession) -> DatabaseInfo? {
        if let selectedName = session.selectedDatabaseName,
           let match = structure.databases.first(where: { $0.name == selectedName }) {
            return match
        }

        if !session.connection.database.isEmpty,
           let match = structure.databases.first(where: { $0.name == session.connection.database }) {
            return match
        }
        return nil
    }
}
