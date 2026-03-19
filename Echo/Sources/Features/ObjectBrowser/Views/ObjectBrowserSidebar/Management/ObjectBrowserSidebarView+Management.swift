import SwiftUI

// MARK: - Management Folder (MSSQL Server-Level)

extension ObjectBrowserSidebarView {

    @ViewBuilder
    func managementFolderSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.managementFolderExpandedBySession[connID] ?? false
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful

        VStack(alignment: .leading, spacing: 0) {
            folderHeaderRow(
                title: "Management",
                icon: "wrench.and.screwdriver",
                count: nil,
                isExpanded: isExpanded,
                action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.managementFolderExpandedBySession[connID] = !isExpanded
                    }
                },
                depth: 0
            )

            if isExpanded {
                Button {
                    environmentState.openExtendedEventsTab(connectionID: connID)
                } label: {
                    SidebarRow(depth: 1, icon: .system("waveform.path.ecg"), label: "Extended Events",
                               iconColor: ExplorerSidebarPalette.folderIconColor(title: "Extended Events", colored: colored))
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.databaseMailConnectionID = connID
                    viewModel.showDatabaseMailSheet = true
                } label: {
                    SidebarRow(depth: 1, icon: .system("envelope"), label: "Database Mail",
                               iconColor: ExplorerSidebarPalette.folderIconColor(title: "Database Mail", colored: colored))
                }
                .buttonStyle(.plain)

                Button {
                    environmentState.openActivityMonitorTab(connectionID: connID)
                } label: {
                    SidebarRow(depth: 1, icon: .system("gauge.with.dots.needle.33percent"), label: "Activity Monitor",
                               iconColor: ExplorerSidebarPalette.folderIconColor(title: "Activity Monitor", colored: colored))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
