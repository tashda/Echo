import SwiftUI
import SQLServerKit

extension ObjectBrowserSidebarView {

    // MARK: - Data Loading

    func loadLinkedServers(session: ConnectionSession) {
        let connID = session.connection.id
        guard let mssql = session.session as? MSSQLSession else { return }
        viewModel.linkedServersLoadingBySession[connID] = true

        Task {
            do {
                let servers = try await mssql.linkedServers.list()
                let items = servers.map { server in
                    ObjectBrowserSidebarViewModel.LinkedServerItem(
                        id: server.name,
                        name: server.name,
                        provider: server.provider,
                        dataSource: server.dataSource,
                        product: server.product,
                        isDataAccessEnabled: server.isDataAccessEnabled
                    )
                }
                viewModel.linkedServersBySession[connID] = items
                viewModel.linkedServersLoadingBySession[connID] = false
            } catch {
                viewModel.linkedServersLoadingBySession[connID] = false
            }
        }
    }

    // MARK: - Test Connection

    func testLinkedServer(name: String, session: ConnectionSession) {
        guard let mssql = session.session as? MSSQLSession else { return }

        Task {
            do {
                let success = try await mssql.linkedServers.test(name: name)
                environmentState.toastPresenter.show(
                    icon: success ? "checkmark.circle" : "xmark.circle",
                    message: success
                        ? "Connection to \"\(name)\" succeeded."
                        : "Connection to \"\(name)\" failed.",
                    style: success ? .success : .error
                )
            } catch {
                environmentState.toastPresenter.show(
                    icon: "xmark.circle",
                    message: "Connection test failed: \(error.localizedDescription)",
                    style: .error
                )
            }
        }
    }

    // MARK: - Drop Linked Server

    func executeDropLinkedServer(
        _ target: SidebarSheetState.DropLinkedServerTarget,
        session: ConnectionSession
    ) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            try await mssql.linkedServers.drop(name: target.serverName, dropLogins: true)
            loadLinkedServers(session: session)
        } catch {
            environmentState.toastPresenter.show(
                icon: "xmark.circle",
                message: "Failed to drop linked server: \(error.localizedDescription)",
                style: .error
            )
        }
    }
}
