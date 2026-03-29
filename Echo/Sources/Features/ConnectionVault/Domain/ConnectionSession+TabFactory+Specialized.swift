import Foundation
import SwiftUI
import SQLServerKit

// MARK: - Specialized Tab Factory Methods (Monitor, MSSQL, Security)

extension ConnectionSession {

    @discardableResult
    func addActivityMonitorTab() throws -> WorkspaceTab {
        // Reuse existing activity monitor tab if present
        if let existing = queryTabs.first(where: { $0.activityMonitor != nil }) {
            activeQueryTabID = existing.id
            return existing
        }

        let monitor = try session.makeActivityMonitor()
        let interval = AppDirector.shared.projectStore.globalSettings.activityMonitorRefreshInterval
        let viewModel = ActivityMonitorViewModel(
            monitor: monitor,
            mysqlSession: session as? MySQLSession,
            connectionSessionID: self.id,
            connectionID: connection.id,
            databaseType: connection.databaseType,
            refreshInterval: interval
        )

        if let mssql = session as? MSSQLSession {
            viewModel.extendedEventsVM = ExtendedEventsViewModel(
                xeClient: mssql.extendedEvents,
                connectionSessionID: id
            )
            viewModel.profilerVM = ProfilerViewModel(
                profilerClient: mssql.profiler,
                session: session,
                connectionSessionID: id
            )
        }

        let connName = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Activity Monitor",
            content: .activityMonitor(viewModel),
            activeDatabaseName: connName.isEmpty ? connection.host : connName
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    func addQueryStoreTab(databaseName: String) -> WorkspaceTab? {
        guard let mssql = session as? MSSQLSession else { return nil }

        // Reuse existing query store tab for THIS specific database if present
        if let existing = queryTabs.first(where: { tab in
            guard let vm = tab.queryStoreVM else { return false }
            return vm.databaseName == databaseName
        }) {
            activeQueryTabID = existing.id
            return existing
        }

        let viewModel = QueryStoreViewModel(
            queryStoreClient: mssql.queryStore,
            databaseName: databaseName,
            connectionSessionID: id
        )
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Query Store (\(databaseName))",
            content: .queryStore(viewModel)
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    func addExtendedEventsTab() -> WorkspaceTab? {
        guard let mssql = session as? MSSQLSession else { return nil }

        // Reuse existing extended events tab if present
        if let existing = queryTabs.first(where: { $0.extendedEventsVM != nil }) {
            activeQueryTabID = existing.id
            return existing
        }

        let viewModel = ExtendedEventsViewModel(
            xeClient: mssql.extendedEvents,
            connectionSessionID: id
        )
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Extended Events",
            content: .extendedEvents(viewModel)
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    func addProfilerTab() -> WorkspaceTab {
        if let existing = queryTabs.first(where: { $0.profilerVM != nil }) {
            activeQueryTabID = existing.id
            return existing
        }

        let viewModel = ProfilerViewModel(
            profilerClient: session.profiler,
            session: session,
            connectionSessionID: id
        )
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "SQL Profiler",
            content: .profiler(viewModel)
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    func addResourceGovernorTab() -> WorkspaceTab {
        if let existing = queryTabs.first(where: { $0.resourceGovernorVM != nil }) {
            activeQueryTabID = existing.id
            return existing
        }

        let viewModel = ResourceGovernorViewModel(
            rgClient: session.resourceGovernor,
            connectionSessionID: id
        )
        viewModel.activityEngine = AppDirector.shared.activityEngine
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Resource Governor",
            content: .resourceGovernor(viewModel)
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

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
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Availability Groups",
            content: .availabilityGroups(viewModel)
        )
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

        let connName = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Error Log",
            content: .errorLog(viewModel),
            activeDatabaseName: connName.isEmpty ? connection.host : connName
        )
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

        let connName = connection.connectionName
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Advanced Objects",
            content: .postgresAdvancedObjects(viewModel),
            activeDatabaseName: connName.isEmpty ? connection.host : connName
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
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    // MARK: - Security Tabs

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

        let connName = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let serverLabel = connName.isEmpty ? connection.host : connName
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Server Security",
            content: .serverSecurity(viewModel),
            activeDatabaseName: serverLabel
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }
}
