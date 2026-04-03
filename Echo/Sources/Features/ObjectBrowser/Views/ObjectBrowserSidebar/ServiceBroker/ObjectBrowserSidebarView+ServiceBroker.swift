import SwiftUI
import SQLServerKit

extension ObjectBrowserSidebarView {

    // MARK: - Service Broker Folder (Database-Level)

    @ViewBuilder
    func serviceBrokerSection(database: DatabaseInfo, session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let dbKey = viewModel.pinnedStorageKey(connectionID: connID, databaseName: database.name)
        let isExpanded = viewModel.serviceBrokerExpandedByDB[dbKey] ?? false
        let isLoading = viewModel.serviceBrokerLoadingByDB[dbKey] ?? false

        let expandedBinding = Binding<Bool>(
            get: { isExpanded },
            set: { newValue in
                viewModel.serviceBrokerExpandedByDB[dbKey] = newValue
                if newValue && !isLoading && viewModel.serviceBrokerQueuesByDB[dbKey] == nil {
                    loadServiceBrokerData(database: database, session: session)
                }
            }
        )

        folderHeaderRow(
            title: "Service Broker",
            icon: "tray.2",
            count: nil,
            isExpanded: expandedBinding,
            isLoading: isLoading,
            depth: 2
        )

        if isExpanded && !isLoading {
            Group {
                let subExpanded = viewModel.serviceBrokerSubExpandedByDB[dbKey] ?? []

                brokerSubFolder(title: "Message Types", items: viewModel.serviceBrokerMessageTypesByDB[dbKey] ?? [], subExpanded: subExpanded, dbKey: dbKey) {
                    sheetState.newMessageTypeConnectionID = connID
                    sheetState.newMessageTypeDatabaseName = database.name
                    sheetState.showNewMessageTypeSheet = true
                }
                brokerSubFolder(title: "Contracts", items: viewModel.serviceBrokerContractsByDB[dbKey] ?? [], subExpanded: subExpanded, dbKey: dbKey) {
                    sheetState.newContractConnectionID = connID
                    sheetState.newContractDatabaseName = database.name
                    sheetState.showNewContractSheet = true
                }
                brokerSubFolder(title: "Queues", items: viewModel.serviceBrokerQueuesByDB[dbKey] ?? [], subExpanded: subExpanded, dbKey: dbKey) {
                    sheetState.newQueueConnectionID = connID
                    sheetState.newQueueDatabaseName = database.name
                    sheetState.showNewQueueSheet = true
                }
                brokerSubFolder(title: "Services", items: viewModel.serviceBrokerServicesByDB[dbKey] ?? [], subExpanded: subExpanded, dbKey: dbKey) {
                    sheetState.newServiceConnectionID = connID
                    sheetState.newServiceDatabaseName = database.name
                    sheetState.showNewServiceSheet = true
                }
                brokerSubFolder(title: "Routes", items: viewModel.serviceBrokerRoutesByDB[dbKey] ?? [], subExpanded: subExpanded, dbKey: dbKey) {
                    sheetState.newRouteConnectionID = connID
                    sheetState.newRouteDatabaseName = database.name
                    sheetState.showNewRouteSheet = true
                }
                brokerSubFolder(title: "Remote Service Bindings", items: viewModel.serviceBrokerBindingsByDB[dbKey] ?? [], subExpanded: subExpanded, dbKey: dbKey, onCreate: nil)
            }
        }
    }

    @ViewBuilder
    private func brokerSubFolder(title: String, items: [String], subExpanded: Set<String>, dbKey: String, onCreate: (() -> Void)?) -> some View {
        let isSubExpanded = subExpanded.contains(title)
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful
        let iconColor = colored ? ExplorerSidebarPalette.serviceBroker : ExplorerSidebarPalette.monochrome

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                var expanded = viewModel.serviceBrokerSubExpandedByDB[dbKey] ?? []
                if expanded.contains(title) { expanded.remove(title) } else { expanded.insert(title) }
                viewModel.serviceBrokerSubExpandedByDB[dbKey] = expanded
            }
        } label: {
            SidebarRow(
                depth: 3,
                icon: .system("tray"),
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
            if let onCreate {
                Button {
                    onCreate()
                } label: {
                    Label("New \(title.hasSuffix("s") ? String(title.dropLast()) : title)", systemImage: "plus")
                }
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

    private func loadServiceBrokerData(database: DatabaseInfo, session: ConnectionSession) {
        let dbKey = viewModel.pinnedStorageKey(connectionID: session.connection.id, databaseName: database.name)
        guard let mssql = session.session as? MSSQLSession else { return }
        viewModel.serviceBrokerLoadingByDB[dbKey] = true

        Task {
            do {
                let broker = mssql.serviceBroker
                let dbName = database.name
                let mt = try await broker.listMessageTypes(database: dbName)
                let ct = try await broker.listContracts(database: dbName)
                let qu = try await broker.listQueues(database: dbName)
                let sv = try await broker.listServices(database: dbName)
                let rt = try await broker.listRoutes(database: dbName)
                let bn = try await broker.listRemoteServiceBindings(database: dbName)
                viewModel.serviceBrokerMessageTypesByDB[dbKey] = mt.filter { !$0.isSystemObject }.map(\.name)
                viewModel.serviceBrokerContractsByDB[dbKey] = ct.filter { !$0.isSystemObject }.map(\.name)
                viewModel.serviceBrokerQueuesByDB[dbKey] = qu.map { "\($0.schema).\($0.name)" }
                viewModel.serviceBrokerServicesByDB[dbKey] = sv.filter { !$0.isSystemObject }.map(\.name)
                viewModel.serviceBrokerRoutesByDB[dbKey] = rt.map(\.name)
                viewModel.serviceBrokerBindingsByDB[dbKey] = bn.map(\.name)
            } catch {
                // Silently handle — empty state shown
            }
            viewModel.serviceBrokerLoadingByDB[dbKey] = false
        }
    }
}
