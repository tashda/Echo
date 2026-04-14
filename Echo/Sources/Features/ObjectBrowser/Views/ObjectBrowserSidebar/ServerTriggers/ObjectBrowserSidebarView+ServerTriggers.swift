import SwiftUI
import SQLServerKit

extension ObjectBrowserSidebarView {

    // MARK: - Server Triggers Folder Section

    @ViewBuilder
    func serverTriggersSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.serverTriggersExpandedBySession[connID] ?? false
        let triggers = viewModel.serverTriggersBySession[connID] ?? []
        let isLoading = viewModel.serverTriggersLoadingBySession[connID] ?? false

        let expandedBinding = Binding<Bool>(
            get: { isExpanded },
            set: { newValue in
                viewModel.serverTriggersExpandedBySession[connID] = newValue
                if newValue && triggers.isEmpty && !isLoading {
                    loadServerTriggers(session: session)
                }
            }
        )

        folderHeaderRow(
            title: "Server Triggers",
            icon: "bolt",
            count: triggers.isEmpty ? nil : triggers.count,
            isExpanded: expandedBinding,
            isLoading: isLoading,
            depth: 0
        )
        .contextMenu {
            Button {
                loadServerTriggers(session: session)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }

            Button {
                sheetState.newServerTriggerConnectionID = connID
                sheetState.showNewServerTriggerSheet = true
            } label: {
                Label("New Server Trigger", systemImage: "bolt")
            }
        }

        if isExpanded {
            serverTriggersContent(session: session, triggers: triggers, isLoading: isLoading)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func serverTriggersContent(
        session: ConnectionSession,
        triggers: [ObjectBrowserSidebarViewModel.ServerTriggerItem],
        isLoading: Bool
    ) -> some View {
        if triggers.isEmpty {
            SidebarRow(
                depth: 1,
                icon: .none,
                label: isLoading ? "Loading…" : "No server triggers",
                labelColor: ColorTokens.Text.tertiary,
                labelFont: TypographyTokens.detail
            )
        } else {
            ForEach(triggers) { trigger in
                serverTriggerRow(trigger: trigger, session: session)
            }
        }
    }

    // MARK: - Row

    private func serverTriggerRow(
        trigger: ObjectBrowserSidebarViewModel.ServerTriggerItem,
        session: ConnectionSession
    ) -> some View {
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful
        return Button {
            // Informational — no navigation
        } label: {
            SidebarRow(
                depth: 1,
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
            serverTriggerContextMenu(trigger: trigger, session: session)
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func serverTriggerContextMenu(
        trigger: ObjectBrowserSidebarViewModel.ServerTriggerItem,
        session: ConnectionSession
    ) -> some View {
        if trigger.isDisabled {
            Button {
                enableServerTrigger(name: trigger.name, session: session)
            } label: {
                Label("Enable", systemImage: "checkmark.circle")
            }
        } else {
            Button {
                disableServerTrigger(name: trigger.name, session: session)
            } label: {
                Label("Disable", systemImage: "pause.circle")
            }
        }

        Divider()

        Button {
            scriptServerTrigger(name: trigger.name, session: session)
        } label: {
            Label("Script as CREATE", systemImage: "doc.text")
        }

        Divider()

        Button(role: .destructive) {
            dropServerTrigger(name: trigger.name, session: session)
        } label: {
            Label("Drop", systemImage: "trash")
        }
    }

    // MARK: - Actions

    func loadServerTriggers(session: ConnectionSession) {
        let connID = session.connection.id
        guard let mssql = session.session as? MSSQLSession else { return }
        viewModel.serverTriggersLoadingBySession[connID] = true

        Task {
            do {
                let triggers = try await mssql.triggers.listServerTriggers()
                viewModel.serverTriggersBySession[connID] = triggers.map { t in
                    ObjectBrowserSidebarViewModel.ServerTriggerItem(
                        id: t.name,
                        name: t.name,
                        isDisabled: t.isDisabled,
                        typeDescription: t.typeDescription,
                        events: t.events
                    )
                }
            } catch {
                // Silently fail — empty list displayed
            }
            viewModel.serverTriggersLoadingBySession[connID] = false
        }
    }

    private func enableServerTrigger(name: String, session: ConnectionSession) {
        guard let mssql = session.session as? MSSQLSession else { return }
        Task {
            do {
                try await mssql.triggers.enableServerTrigger(name: name)
                loadServerTriggers(session: session)
            } catch {
                environmentState.toastPresenter.show(icon: "xmark.circle", message: "Failed to enable trigger: \(error.localizedDescription)", style: .error)
            }
        }
    }

    private func disableServerTrigger(name: String, session: ConnectionSession) {
        guard let mssql = session.session as? MSSQLSession else { return }
        Task {
            do {
                try await mssql.triggers.disableServerTrigger(name: name)
                loadServerTriggers(session: session)
            } catch {
                environmentState.toastPresenter.show(icon: "xmark.circle", message: "Failed to disable trigger: \(error.localizedDescription)", style: .error)
            }
        }
    }

    private func dropServerTrigger(name: String, session: ConnectionSession) {
        guard let mssql = session.session as? MSSQLSession else { return }
        Task {
            do {
                try await mssql.triggers.dropServerTrigger(name: name)
                loadServerTriggers(session: session)
            } catch {
                environmentState.toastPresenter.show(icon: "xmark.circle", message: "Failed to drop trigger: \(error.localizedDescription)", style: .error)
            }
        }
    }

    private func scriptServerTrigger(name: String, session: ConnectionSession) {
        guard let mssql = session.session as? MSSQLSession else { return }
        Task {
            do {
                if let definition = try await mssql.triggers.getServerTriggerDefinition(name: name) {
                    environmentState.openQueryTab(for: session, presetQuery: definition)
                }
            } catch {
                environmentState.toastPresenter.show(icon: "xmark.circle", message: "Failed to get trigger definition: \(error.localizedDescription)", style: .error)
            }
        }
    }
}
