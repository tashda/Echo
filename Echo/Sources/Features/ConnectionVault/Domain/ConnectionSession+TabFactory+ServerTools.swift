import Foundation
import SwiftUI
import SQLServerKit

// MARK: - Server Tools Tab Factory Methods

extension ConnectionSession {

    @discardableResult
    func addServerPropertiesTab() -> WorkspaceTab {
        if let existing = queryTabs.first(where: { $0.serverPropertiesVM != nil }) {
            activeQueryTabID = existing.id
            return existing
        }

        let viewModel = ServerPropertiesViewModel(
            session: session,
            connectionID: connection.id,
            connectionSessionID: id,
            connectionHost: connection.host
        )
        viewModel.activityEngine = AppDirector.shared.activityEngine
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Server Properties",
            content: .serverProperties(viewModel)
        )
        tab.tabSubtitle = serverLabel
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    func addTuningAdvisorTab() -> WorkspaceTab {
        if let existing = queryTabs.first(where: { $0.tuningAdvisorVM != nil }) {
            activeQueryTabID = existing.id
            return existing
        }

        let viewModel = TuningAdvisorViewModel(
            tuningClient: session.tuning,
            session: session,
            connectionSessionID: id
        )
        viewModel.activityEngine = AppDirector.shared.activityEngine
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Tuning Advisor",
            content: .tuningAdvisor(viewModel)
        )
        tab.tabSubtitle = serverLabel
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    func addPolicyManagementTab() -> WorkspaceTab {
        if let existing = queryTabs.first(where: { $0.policyManagementVM != nil }) {
            activeQueryTabID = existing.id
            return existing
        }

        let viewModel = PolicyManagementViewModel(
            policyClient: session.policy,
            connectionSessionID: id
        )
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Policy Management",
            content: .policyManagement(viewModel)
        )
        tab.tabSubtitle = serverLabel
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    func addAvailabilityGroupsTab() -> WorkspaceTab? {
        guard let mssql = session as? MSSQLSession else { return nil }

        // Reuse existing availability groups tab if present
        if let existing = queryTabs.first(where: { $0.availabilityGroupsVM != nil }) {
            activeQueryTabID = existing.id
            return existing
        }

        let viewModel = AvailabilityGroupsViewModel(
            agClient: mssql.availabilityGroups,
            connectionSessionID: id
        )
        viewModel.activityEngine = AppDirector.shared.activityEngine
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Availability Groups",
            content: .availabilityGroups(viewModel)
        )
        tab.tabSubtitle = serverLabel
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    // MARK: - Error Log Tab

    @discardableResult
    func addErrorLogTab() -> WorkspaceTab {
        if let existing = queryTabs.first(where: { $0.errorLogVM != nil }) {
            activeQueryTabID = existing.id
            return existing
        }

        let viewModel = ErrorLogViewModel(session: session, connectionSessionID: id)
        viewModel.activityEngine = AppDirector.shared.activityEngine
        viewModel.notificationEngine = AppDirector.shared.notificationEngine

        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Error Log",
            content: .errorLog(viewModel),
            activeDatabaseName: nil
        )
        tab.tabSubtitle = serverLabel
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    // MARK: - Advanced Objects Tab (PostgreSQL)

    @discardableResult
    func addPostgresAdvancedObjectsTab() -> WorkspaceTab {
        if let existing = queryTabs.first(where: { $0.postgresAdvancedObjectsVM != nil }) {
            activeQueryTabID = existing.id
            return existing
        }

        let viewModel = PostgresAdvancedObjectsViewModel(
            session: session,
            connectionID: connection.id,
            connectionSessionID: id
        )
        viewModel.activityEngine = AppDirector.shared.activityEngine

        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Advanced Objects",
            content: .postgresAdvancedObjects(viewModel),
            activeDatabaseName: nil
        )
        tab.tabSubtitle = serverLabel
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    // MARK: - Advanced Objects Tab (MSSQL)

    @discardableResult
    func addMSSQLAdvancedObjectsTab(databaseName: String) -> WorkspaceTab {
        if let existing = queryTabs.first(where: { $0.mssqlAdvancedObjectsVM != nil }) {
            if let vm = existing.mssqlAdvancedObjectsVM, vm.databaseName != databaseName {
                vm.databaseName = databaseName
                vm.isInitialized = false
                Task { await vm.initialize() }
            }
            activeQueryTabID = existing.id
            return existing
        }

        let viewModel = MSSQLAdvancedObjectsViewModel(
            session: session,
            connectionID: connection.id,
            connectionSessionID: id,
            databaseName: databaseName
        )
        viewModel.activityEngine = AppDirector.shared.activityEngine

        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Advanced Objects",
            content: .mssqlAdvancedObjects(viewModel),
            activeDatabaseName: databaseName
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    // MARK: - Schema Diff Tab (PostgreSQL)

    @discardableResult
    func addSchemaDiffTab() -> WorkspaceTab {
        if let existing = queryTabs.first(where: { $0.schemaDiffVM != nil }) {
            activeQueryTabID = existing.id
            return existing
        }

        let viewModel = SchemaDiffViewModel(
            session: session,
            connectionID: connection.id,
            connectionSessionID: id
        )
        viewModel.activityEngine = AppDirector.shared.activityEngine

        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Schema Diff",
            content: .schemaDiff(viewModel)
        )
        tab.tabSubtitle = serverLabel
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    // MARK: - Visual Query Builder

    @discardableResult
    func addQueryBuilderTab() -> WorkspaceTab {
        let viewModel = VisualQueryBuilderViewModel(
            databaseType: connection.databaseType,
            session: session
        )
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Query Builder",
            content: .queryBuilder(viewModel)
        )
        tab.tabSubtitle = serverLabel
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }
}
