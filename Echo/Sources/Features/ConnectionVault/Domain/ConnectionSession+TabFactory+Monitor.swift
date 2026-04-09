import Foundation
import SwiftUI
import SQLServerKit

// MARK: - Monitor Tab Factory Methods

extension ConnectionSession {

    /// Display label for the server in tab subtitles — prefers connection name, falls back to host.
    var serverLabel: String {
        let connName = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return connName.isEmpty ? connection.host : connName
    }

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
        viewModel.activityEngine = AppDirector.shared.activityEngine

        if let mssql = session as? MSSQLSession {
            let xeVM = ExtendedEventsViewModel(
                xeClient: mssql.extendedEvents,
                connectionSessionID: id
            )
            xeVM.activityEngine = AppDirector.shared.activityEngine
            viewModel.extendedEventsVM = xeVM
            viewModel.profilerVM = ProfilerViewModel(
                profilerClient: mssql.profiler,
                session: session,
                connectionSessionID: id
            )
        }

        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Activity Monitor",
            content: .activityMonitor(viewModel),
            activeDatabaseName: nil
        )
        tab.tabSubtitle = serverLabel
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
        viewModel.activityEngine = AppDirector.shared.activityEngine
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Extended Events",
            content: .extendedEvents(viewModel)
        )
        tab.tabSubtitle = serverLabel
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
        tab.tabSubtitle = serverLabel
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
        tab.tabSubtitle = serverLabel
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }
}
