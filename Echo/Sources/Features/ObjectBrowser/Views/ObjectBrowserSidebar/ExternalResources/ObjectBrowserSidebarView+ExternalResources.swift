import SwiftUI
import SQLServerKit

extension ObjectBrowserSidebarView {

    // MARK: - External Resources Folder (Database-Level, PolyBase)

    @ViewBuilder
    func externalResourcesSection(database: DatabaseInfo, session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let dbKey = viewModel.pinnedStorageKey(connectionID: connID, databaseName: database.name)
        let isExpanded = viewModel.externalResourcesExpandedByDB[dbKey] ?? false
        let isLoading = viewModel.externalResourcesLoadingByDB[dbKey] ?? false

        let expandedBinding = Binding<Bool>(
            get: { isExpanded },
            set: { newValue in
                viewModel.externalResourcesExpandedByDB[dbKey] = newValue
                if newValue && !isLoading && viewModel.externalDataSourcesByDB[dbKey] == nil {
                    loadExternalResources(database: database, session: session)
                }
            }
        )

        folderHeaderRow(
            title: "External Resources",
            icon: "externaldrive.connected.to.line.below",
            count: nil,
            isExpanded: expandedBinding,
            isLoading: isLoading,
            depth: 2
        )

        if isExpanded && !isLoading {
            Group {
                let subExpanded = viewModel.externalResourcesSubExpandedByDB[dbKey] ?? []

                externalSubFolder(title: "External Data Sources", items: viewModel.externalDataSourcesByDB[dbKey] ?? [], subExpanded: subExpanded, dbKey: dbKey) {
                    viewModel.newExternalDataSourceConnectionID = connID
                    viewModel.newExternalDataSourceDatabaseName = database.name
                    viewModel.showNewExternalDataSourceSheet = true
                }
                externalSubFolder(title: "External Tables", items: viewModel.externalTablesByDB[dbKey] ?? [], subExpanded: subExpanded, dbKey: dbKey) {
                    viewModel.newExternalTableConnectionID = connID
                    viewModel.newExternalTableDatabaseName = database.name
                    viewModel.showNewExternalTableSheet = true
                }
                externalSubFolder(title: "External File Formats", items: viewModel.externalFileFormatsByDB[dbKey] ?? [], subExpanded: subExpanded, dbKey: dbKey) {
                    viewModel.newExternalFileFormatConnectionID = connID
                    viewModel.newExternalFileFormatDatabaseName = database.name
                    viewModel.showNewExternalFileFormatSheet = true
                }
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private func externalSubFolder(title: String, items: [String], subExpanded: Set<String>, dbKey: String, onCreate: @escaping () -> Void) -> some View {
        let isSubExpanded = subExpanded.contains(title)
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful
        let iconColor = colored ? ExplorerSidebarPalette.externalResources : ExplorerSidebarPalette.monochrome

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                var expanded = viewModel.externalResourcesSubExpandedByDB[dbKey] ?? []
                if expanded.contains(title) { expanded.remove(title) } else { expanded.insert(title) }
                viewModel.externalResourcesSubExpandedByDB[dbKey] = expanded
            }
        } label: {
            SidebarRow(
                depth: 3,
                icon: .system("externaldrive"),
                label: title,
                isExpanded: .constant(isSubExpanded),
                iconColor: iconColor
            ) {
                if !items.isEmpty {
                    CountBadge(count: items.count)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onCreate()
            } label: {
                Label("New...", systemImage: "plus")
            }
        }

        if isSubExpanded {
            if items.isEmpty {
                SidebarRow(depth: 4, icon: .none, label: "None", labelColor: ColorTokens.Text.tertiary, labelFont: TypographyTokens.detail)
            } else {
                ForEach(items, id: \.self) { item in
                    SidebarRow(depth: 4, icon: .system("doc"), label: item, iconColor: iconColor)
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadExternalResources(database: DatabaseInfo, session: ConnectionSession) {
        let dbKey = viewModel.pinnedStorageKey(connectionID: session.connection.id, databaseName: database.name)
        guard let mssql = session.session as? MSSQLSession else { return }
        viewModel.externalResourcesLoadingByDB[dbKey] = true

        Task {
            do {
                let pb = mssql.polyBase
                let dbName = database.name
                let ds = try await pb.listExternalDataSources(database: dbName)
                let tb = try await pb.listExternalTables(database: dbName)
                let ff = try await pb.listExternalFileFormats(database: dbName)
                viewModel.externalDataSourcesByDB[dbKey] = ds.map(\.name)
                viewModel.externalTablesByDB[dbKey] = tb.map { "\($0.schema).\($0.name)" }
                viewModel.externalFileFormatsByDB[dbKey] = ff.map(\.name)
            } catch {
                // PolyBase may not be installed — sys.external_data_sources won't exist
                viewModel.externalDataSourcesByDB[dbKey] = []
                viewModel.externalTablesByDB[dbKey] = []
                viewModel.externalFileFormatsByDB[dbKey] = []
            }
            viewModel.externalResourcesLoadingByDB[dbKey] = false
        }
    }
}
