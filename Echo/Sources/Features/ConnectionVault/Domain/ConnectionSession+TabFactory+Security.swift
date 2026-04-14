import Foundation
import SwiftUI

// MARK: - Security Tab Factory Methods

extension ConnectionSession {

    @discardableResult
    func addDatabaseSecurityTab(databaseName: String? = nil) -> WorkspaceTab {
        if connection.databaseType == .postgresql {
            return addPostgresDatabaseSecurityTab()
        }
        if connection.databaseType == .mysql {
            return addMySQLDatabaseSecurityTab(databaseName: databaseName)
        }
        return addMSSQLDatabaseSecurityTab(databaseName: databaseName)
    }

    @discardableResult
    private func addMSSQLDatabaseSecurityTab(databaseName: String? = nil) -> WorkspaceTab {
        let effectiveDatabase = databaseName ?? sidebarFocusedDatabase ?? connection.database

        if let existing = queryTabs.first(where: { $0.databaseSecurity != nil }) {
            activeQueryTabID = existing.id
            if let vm = existing.databaseSecurity, vm.selectedDatabase != effectiveDatabase {
                existing.activeDatabaseName = effectiveDatabase.isEmpty ? nil : effectiveDatabase
                Task { await vm.selectDatabase(effectiveDatabase) }
            }
            return existing
        }

        let viewModel = DatabaseSecurityViewModel(
            session: session,
            connectionID: connection.id,
            connectionSessionID: id,
            initialDatabase: effectiveDatabase.isEmpty ? nil : effectiveDatabase
        )
        viewModel.activityEngine = AppDirector.shared.activityEngine

        let dbName = databaseName ?? sidebarFocusedDatabase
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Database Security",
            content: .databaseSecurity(viewModel),
            activeDatabaseName: (dbName?.isEmpty == false) ? dbName : nil
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    private func addPostgresDatabaseSecurityTab() -> WorkspaceTab {
        if let existing = queryTabs.first(where: { $0.postgresSecurity != nil }) {
            activeQueryTabID = existing.id
            return existing
        }

        let viewModel = PostgresDatabaseSecurityViewModel(
            session: session,
            connectionID: connection.id,
            connectionSessionID: id
        )
        viewModel.activityEngine = AppDirector.shared.activityEngine

        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Database Security",
            content: .postgresSecurity(viewModel)
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    private func addMySQLDatabaseSecurityTab(databaseName: String? = nil) -> WorkspaceTab {
        if let existing = queryTabs.first(where: { $0.mysqlSecurity != nil }) {
            activeQueryTabID = existing.id
            if let databaseName, !databaseName.isEmpty {
                existing.activeDatabaseName = databaseName
            }
            return existing
        }

        let viewModel = MySQLDatabaseSecurityViewModel(
            session: session,
            connectionID: connection.id,
            connectionSessionID: id
        )
        viewModel.activityEngine = AppDirector.shared.activityEngine

        let effectiveDatabase = databaseName ?? sidebarFocusedDatabase ?? connection.database
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Database Security",
            content: .mysqlSecurity(viewModel),
            activeDatabaseName: effectiveDatabase.isEmpty ? nil : effectiveDatabase
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    func addServerSecurityTab() -> WorkspaceTab {
        if let existing = queryTabs.first(where: { $0.serverSecurity != nil }) {
            activeQueryTabID = existing.id
            return existing
        }

        let viewModel = ServerSecurityViewModel(
            session: session,
            connectionID: connection.id,
            connectionSessionID: id
        )
        viewModel.activityEngine = AppDirector.shared.activityEngine

        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Server Security",
            content: .serverSecurity(viewModel),
            activeDatabaseName: nil
        )
        tab.tabSubtitle = serverLabel
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }
}
