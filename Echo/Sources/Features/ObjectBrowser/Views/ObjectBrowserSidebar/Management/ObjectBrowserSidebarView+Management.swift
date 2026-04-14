import SwiftUI

// MARK: - Management Folder (MSSQL Server-Level)

extension ObjectBrowserSidebarView {

    @ViewBuilder
    func managementFolderSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.managementFolderExpandedBySession[connID] ?? false
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful

        let expandedBinding = Binding<Bool>(
            get: { isExpanded },
            set: { newValue in
                viewModel.managementFolderExpandedBySession[connID] = newValue
            }
        )

        folderHeaderRow(
            title: "Management",
            icon: "gearshape",
            count: nil,
            isExpanded: expandedBinding,
            depth: 0
        )

        if isExpanded {
            Group {
                Button {
                    environmentState.openActivityMonitorTab(connectionID: connID, section: "XEvents")
                } label: {
                    SidebarRow(depth: 1, icon: .system("list.bullet.rectangle"), label: "Extended Events",
                               iconColor: ExplorerSidebarPalette.folderIconColor(title: "Extended Events", colored: colored))
                }
                .buttonStyle(.plain)

                Button {
                    let value = environmentState.prepareDatabaseMailEditorWindow(
                        connectionSessionID: connID
                    )
                    openWindow(id: DatabaseMailEditorWindow.sceneID, value: value)
                } label: {
                    SidebarRow(depth: 1, icon: .system("envelope"), label: "Database Mail",
                               iconColor: ExplorerSidebarPalette.folderIconColor(title: "Database Mail", colored: colored))
                }
                .buttonStyle(.plain)

                Button {
                    environmentState.openActivityMonitorTab(connectionID: connID, section: "Profiler")
                } label: {
                    SidebarRow(depth: 1, icon: .system("chart.line.uptrend.xyaxis"), label: "SQL Profiler",
                               iconColor: ExplorerSidebarPalette.folderIconColor(title: "SQL Profiler", colored: colored))
                }
                .buttonStyle(.plain)

                Button {
                    environmentState.openResourceGovernorTab(connectionID: connID)
                } label: {
                    SidebarRow(depth: 1, icon: .system("slider.horizontal.3"), label: "Resource Governor",
                               iconColor: ExplorerSidebarPalette.folderIconColor(title: "Resource Governor", colored: colored))
                }
                .buttonStyle(.plain)

                Button {
                    environmentState.openTuningAdvisorTab(connectionID: connID)
                } label: {
                    SidebarRow(depth: 1, icon: .system("wand.and.stars"), label: "Tuning Advisor",
                               iconColor: ExplorerSidebarPalette.folderIconColor(title: "Tuning Advisor", colored: colored))
                }
                .buttonStyle(.plain)

                Button {
                    environmentState.openPolicyManagementTab(connectionID: connID)
                } label: {
                    SidebarRow(depth: 1, icon: .system("checkmark.shield"), label: "Policy Management",
                               iconColor: ExplorerSidebarPalette.folderIconColor(title: "Policy Management", colored: colored))
                }
                .buttonStyle(.plain)

                Button {
                    environmentState.openActivityMonitorTab(connectionID: connID)
                } label: {
                    SidebarRow(depth: 1, icon: .system("gauge.high"), label: "Activity Monitor",
                               iconColor: ExplorerSidebarPalette.folderIconColor(title: "Activity Monitor", colored: colored))
                }
                .buttonStyle(.plain)

                Button {
                    environmentState.openErrorLogTab(connectionID: connID)
                } label: {
                    SidebarRow(depth: 1, icon: .system("doc.text"), label: "SQL Server Logs",
                               iconColor: ExplorerSidebarPalette.folderIconColor(title: "SQL Server Logs", colored: colored))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
