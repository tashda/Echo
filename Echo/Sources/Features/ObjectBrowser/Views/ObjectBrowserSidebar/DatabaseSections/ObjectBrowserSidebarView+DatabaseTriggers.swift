import SwiftUI
import SQLServerKit

extension ObjectBrowserSidebarView {

    // MARK: - Database DDL Triggers Folder Section

    @ViewBuilder
    func databaseDDLTriggersSection(database: DatabaseInfo, session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let dbKey = viewModel.pinnedStorageKey(connectionID: connID, databaseName: database.name)
        let isExpanded = viewModel.dbDDLTriggersExpandedByDB[dbKey] ?? false
        let triggers = viewModel.dbDDLTriggersByDB[dbKey] ?? []
        let isLoading = viewModel.dbDDLTriggersLoadingByDB[dbKey] ?? false

        let expandedBinding = Binding<Bool>(
            get: { isExpanded },
            set: { newValue in
                viewModel.dbDDLTriggersExpandedByDB[dbKey] = newValue
                if newValue && triggers.isEmpty && !isLoading {
                    loadDatabaseDDLTriggers(database: database, session: session)
                }
            }
        )

        folderHeaderRow(
            title: "Database Triggers",
            icon: "bolt",
            count: triggers.isEmpty ? nil : triggers.count,
            isExpanded: expandedBinding,
            isLoading: isLoading,
            depth: 2
        )
        .contextMenu {
            Button {
                loadDatabaseDDLTriggers(database: database, session: session)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }

            Divider()

            Button {
                viewModel.newDBDDLTriggerConnectionID = connID
                viewModel.newDBDDLTriggerDatabaseName = database.name
                viewModel.showNewDBDDLTriggerSheet = true
            } label: {
                Label("New Database Trigger...", systemImage: "bolt.shield.fill")
            }
        }

        if isExpanded {
            dbDDLTriggersContent(database: database, session: session, triggers: triggers, isLoading: isLoading)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func dbDDLTriggersContent(
        database: DatabaseInfo,
        session: ConnectionSession,
        triggers: [ObjectBrowserSidebarViewModel.DatabaseDDLTriggerItem],
        isLoading: Bool
    ) -> some View {
        if triggers.isEmpty {
            SidebarRow(
                depth: 3,
                icon: .none,
                label: isLoading ? "Loading…" : "No database triggers",
                labelColor: ColorTokens.Text.tertiary,
                labelFont: TypographyTokens.detail
            )
        } else {
            ForEach(triggers) { trigger in
                dbDDLTriggerRow(trigger: trigger, database: database, session: session)
            }
        }
    }

    // MARK: - Row

    private func dbDDLTriggerRow(
        trigger: ObjectBrowserSidebarViewModel.DatabaseDDLTriggerItem,
        database: DatabaseInfo,
        session: ConnectionSession
    ) -> some View {
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful
        return Button {
            // Informational — no navigation
        } label: {
            SidebarRow(
                depth: 3,
                icon: .system("bolt"),
                label: trigger.name,
                iconColor: colored ? ExplorerSidebarPalette.triggers : ExplorerSidebarPalette.monochrome,
                labelColor: trigger.isDisabled ? ColorTokens.Text.tertiary : ColorTokens.Text.primary
            ) {
                if trigger.isDisabled {
                    Text("Disabled")
                        .font(SidebarRowConstants.trailingFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            dbDDLTriggerContextMenu(trigger: trigger, database: database, session: session)
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func dbDDLTriggerContextMenu(
        trigger: ObjectBrowserSidebarViewModel.DatabaseDDLTriggerItem,
        database: DatabaseInfo,
        session: ConnectionSession
    ) -> some View {
        if trigger.isDisabled {
            Button {
                enableDatabaseDDLTrigger(name: trigger.name, database: database, session: session)
            } label: {
                Label("Enable", systemImage: "checkmark.circle")
            }
        } else {
            Button {
                disableDatabaseDDLTrigger(name: trigger.name, database: database, session: session)
            } label: {
                Label("Disable", systemImage: "pause.circle")
            }
        }

        Divider()

        Button {
            scriptDatabaseDDLTrigger(name: trigger.name, database: database, session: session)
        } label: {
            Label("Script as CREATE", systemImage: "doc.text")
        }

        Divider()

        Button(role: .destructive) {
            dropDatabaseDDLTrigger(name: trigger.name, database: database, session: session)
        } label: {
            Label("Drop", systemImage: "trash")
        }
    }

    // MARK: - Actions

    private func loadDatabaseDDLTriggers(database: DatabaseInfo, session: ConnectionSession) {
        let connID = session.connection.id
        let dbKey = viewModel.pinnedStorageKey(connectionID: connID, databaseName: database.name)
        guard let mssql = session.session as? MSSQLSession else { return }
        viewModel.dbDDLTriggersLoadingByDB[dbKey] = true

        Task {
            do {
                let triggers = try await mssql.triggers.listDatabaseDDLTriggers(database: database.name)
                viewModel.dbDDLTriggersByDB[dbKey] = triggers.map { t in
                    ObjectBrowserSidebarViewModel.DatabaseDDLTriggerItem(
                        id: t.name,
                        name: t.name,
                        isDisabled: t.isDisabled,
                        events: t.events
                    )
                }
            } catch {
                // Silently fail — empty list displayed
            }
            viewModel.dbDDLTriggersLoadingByDB[dbKey] = false
        }
    }

    private func enableDatabaseDDLTrigger(name: String, database: DatabaseInfo, session: ConnectionSession) {
        guard let mssql = session.session as? MSSQLSession else { return }
        Task {
            do {
                try await mssql.triggers.enableDatabaseDDLTrigger(name: name, database: database.name)
                loadDatabaseDDLTriggers(database: database, session: session)
            } catch {
                environmentState.toastPresenter.show(icon: "xmark.circle", message: "Failed to enable trigger: \(error.localizedDescription)", style: .error)
            }
        }
    }

    private func disableDatabaseDDLTrigger(name: String, database: DatabaseInfo, session: ConnectionSession) {
        guard let mssql = session.session as? MSSQLSession else { return }
        Task {
            do {
                try await mssql.triggers.disableDatabaseDDLTrigger(name: name, database: database.name)
                loadDatabaseDDLTriggers(database: database, session: session)
            } catch {
                environmentState.toastPresenter.show(icon: "xmark.circle", message: "Failed to disable trigger: \(error.localizedDescription)", style: .error)
            }
        }
    }

    private func dropDatabaseDDLTrigger(name: String, database: DatabaseInfo, session: ConnectionSession) {
        guard let mssql = session.session as? MSSQLSession else { return }
        Task {
            do {
                try await mssql.triggers.dropDatabaseDDLTrigger(name: name, database: database.name)
                loadDatabaseDDLTriggers(database: database, session: session)
            } catch {
                environmentState.toastPresenter.show(icon: "xmark.circle", message: "Failed to drop trigger: \(error.localizedDescription)", style: .error)
            }
        }
    }

    private func scriptDatabaseDDLTrigger(name: String, database: DatabaseInfo, session: ConnectionSession) {
        guard let mssql = session.session as? MSSQLSession else { return }
        Task {
            do {
                if let definition = try await mssql.triggers.getDatabaseDDLTriggerDefinition(name: name, database: database.name) {
                    environmentState.openQueryTab(for: session, presetQuery: definition)
                }
            } catch {
                environmentState.toastPresenter.show(icon: "xmark.circle", message: "Failed to get trigger definition: \(error.localizedDescription)", style: .error)
            }
        }
    }
}
