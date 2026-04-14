import SwiftUI
import SQLServerKit

extension ObjectBrowserSidebarView {
    func loadSSISFoldersAsync(session: ConnectionSession) async {
        let connID = session.connection.id
        guard let mssql = session.session as? MSSQLSession else { return }
        
        viewModel.ssisLoadingBySession[connID] = true
        defer { viewModel.ssisLoadingBySession[connID] = false }
        
        do {
            if try await mssql.ssis.isSSISCatalogAvailable() {
                let folders = try await mssql.ssis.listFolders()
                await MainActor.run {
                    viewModel.ssisFoldersBySession[connID] = folders
                }
            } else {
                await MainActor.run {
                    viewModel.ssisFoldersBySession[connID] = []
                }
            }
        } catch {
            print("Failed to load SSIS folders: \(error)")
        }
    }
}
