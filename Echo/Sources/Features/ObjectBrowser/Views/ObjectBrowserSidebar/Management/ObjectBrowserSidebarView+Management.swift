import SwiftUI

// MARK: - Management Folder (MSSQL Server-Level)

extension ObjectBrowserSidebarView {

    @ViewBuilder
    func managementFolderSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let expandedBinding = Binding<Bool>(
            get: { viewModel.managementFolderExpandedBySession[connID] ?? false },
            set: { viewModel.managementFolderExpandedBySession[connID] = $0 }
        )
        let colored = projectStore.globalSettings.sidebarColoredIcons

        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expandedBinding.wrappedValue.toggle() }
            } label: {
                SidebarRow(
                    depth: 0,
                    icon: .system("wrench.and.screwdriver"),
                    label: "Management",
                    isExpanded: expandedBinding,
                    iconColor: ExplorerSidebarPalette.folderIconColor(title: "Management", colored: colored)
                )
            }

            if expandedBinding.wrappedValue {
                Button {
                    environmentState.openExtendedEventsTab(connectionID: connID)
                } label: {
                    SidebarRow(depth: 1, icon: .system("waveform.path.ecg"), label: "Extended Events",
                               iconColor: ExplorerSidebarPalette.folderIconColor(title: "Extended Events", colored: colored))
                }

                Button {
                    viewModel.databaseMailConnectionID = connID
                    viewModel.showDatabaseMailSheet = true
                } label: {
                    SidebarRow(depth: 1, icon: .system("envelope"), label: "Database Mail",
                               iconColor: ExplorerSidebarPalette.folderIconColor(title: "Database Mail", colored: colored))
                }

                Button {
                    environmentState.openActivityMonitorTab(connectionID: connID)
                } label: {
                    SidebarRow(depth: 1, icon: .system("gauge.with.dots.needle.33percent"), label: "Activity Monitor",
                               iconColor: ExplorerSidebarPalette.folderIconColor(title: "Activity Monitor", colored: colored))
                }
            }
        }
    }
}
