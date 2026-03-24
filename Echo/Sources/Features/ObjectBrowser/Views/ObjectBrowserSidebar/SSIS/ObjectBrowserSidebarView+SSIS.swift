import SwiftUI
import SQLServerKit

extension ObjectBrowserSidebarView {
    
    @ViewBuilder
    func ssisSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let folders = viewModel.ssisFoldersBySession[connID] ?? []
        let isLoading = viewModel.ssisLoadingBySession[connID] ?? false
        
        let isExpanded = Binding<Bool>(
            get: { viewModel.ssisExpandedBySession[connID] ?? false },
            set: { newValue in
                viewModel.ssisExpandedBySession[connID] = newValue
                if newValue && folders.isEmpty {
                    Task { await loadSSISFoldersAsync(session: session) }
                }
            }
        )
        
        folderHeaderRow(
            title: "Integration Services Catalogs",
            icon: "folder.badge.gearshape",
            count: folders.isEmpty ? nil : folders.count,
            isExpanded: isExpanded,
            isLoading: isLoading,
            depth: 0
        )
        .contextMenu {
            Button {
                Task { await loadSSISFoldersAsync(session: session) }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        
        if isExpanded.wrappedValue {
            if folders.isEmpty && !isLoading {
                SidebarRow(
                    depth: 1,
                    icon: .none,
                    label: "No catalogs found",
                    labelColor: ColorTokens.Text.tertiary,
                    labelFont: TypographyTokens.detail
                )
            } else {
                ForEach(folders) { folder in
                    ssisFolderSection(folder: folder, session: session)
                }
            }
        }
    }
    
    @ViewBuilder
    private func ssisFolderSection(folder: SQLServerSSISFolder, session: ConnectionSession) -> some View {
        SidebarRow(
            depth: 1,
            icon: .system("folder"),
            label: folder.name
        )
        .contextMenu {
            Button {
                // Placeholder for folder actions
            } label: {
                Label("Properties", systemImage: "info.circle")
            }
        }
    }
}
