#if DEBUG
import Foundation

/// Script steps the app performs itself rather than the Explorer: opening and switching tabs,
/// and showing or hiding the window's columns. Each calls the same code a menu item or click does.
///
///     { "action": "query", "server": "Test MSSQL", "target": "SELECT TOP 500 * FROM sys.objects" }
///     { "action": "tool", "server": "Test MSSQL", "target": "activity" }
///     { "action": "tab", "target": "next" }        // or "previous", "first", "last", or an index
///     { "action": "closeTab" }
///     { "action": "window", "target": "sidebar" }  // or "inspector", "overview"
///     { "action": "page", "target": "next" }       // a tool tab's next page, or a page's title
extension AppDirector {
    static let appAutomationActions: Set<String> = ["query", "tool", "tab", "closeTab", "window", "page", "connect",
                                                    "menu", "dumpMenu", "settings", "structure", "diagram", "manage", "structureEdit", "viewStats", "close"]

    /// Performs an app step; the server is looked up by its automation name.
    func performAppAutomationStep(_ step: AutomationScript.Step, connections: [String: SavedConnection]) {
        let connectionID = step.server.flatMap { connections[$0]?.id }
        switch step.action {
        case "connect":
            // A server connecting while the others are open, as when you connect one from the rail.
            guard let name = step.server, let connection = connections[name],
                  environmentState.sessionGroup.sessionForConnection(connection.id) == nil else { return }
            environmentState.connect(to: connection)
        case "query":
            guard let connectionID, let session = environmentState.sessionGroup.sessionForConnection(connectionID) else { return }
            environmentState.openQueryTab(for: session, presetQuery: step.target, autoExecute: step.target != nil)
        case "tool":
            guard let connectionID, let target = step.target else { return }
            openAutomationTool(target, connectionID: connectionID)
        case "tab":
            selectAutomationTab(step.target ?? "next")
        case "page":
            guard let tab = tabStore.activeTab, !tab.toolPages.isEmpty else { return }
            if step.target == "next" || step.target == nil {
                let pages = tab.toolPages
                let index = tab.currentToolPage.flatMap { pages.firstIndex(of: $0) } ?? -1
                tab.selectToolPage(pages[(index + 1) % pages.count])
            } else if let page = step.target {
                tab.selectToolPage(page)
            }
        case "closeTab":
            if let id = tabStore.activeTabId { tabStore.closeTab(id: id) }
        case "window":
            switch step.target {
            case "sidebar": appState.isWorkspaceTreeVisible.toggle()
            case "inspector": appState.showInfoSidebar.toggle()
            case "overview": appState.toggleTabOverview()
            default: break
            }
        default:
            performWindowAutomationStep(step, connections: connections)
        }
    }

    private func openAutomationTool(_ tool: String, connectionID: UUID) {
        switch tool {
        case "activity": environmentState.openActivityMonitorTab(connectionID: connectionID)
        case "maintenance": environmentState.openMaintenanceTab(connectionID: connectionID)
        case "serverSecurity": environmentState.openServerSecurityTab(connectionID: connectionID)
        case "serverProperties": environmentState.openServerPropertiesTab(connectionID: connectionID)
        case "errorLog": environmentState.openErrorLogTab(connectionID: connectionID)
        case "extendedEvents": environmentState.openExtendedEventsTab(connectionID: connectionID)
        case "profiler": environmentState.openProfilerTab(connectionID: connectionID)
        case "resourceGovernor": environmentState.openResourceGovernorTab(connectionID: connectionID)
        case "tuningAdvisor": environmentState.openTuningAdvisorTab(connectionID: connectionID)
        case "policyManagement": environmentState.openPolicyManagementTab(connectionID: connectionID)
        case "availabilityGroups": environmentState.openAvailabilityGroupsTab(connectionID: connectionID)
        case "advancedObjects": environmentState.openAdvancedObjectsTab(connectionID: connectionID)
        case "queryBuilder": environmentState.openQueryBuilderTab(connectionID: connectionID)
        case "psql":
            environmentState.openPSQLTab(for: environmentState.sessionGroup.sessionForConnection(connectionID))
        case "jobs":
            if let session = environmentState.sessionGroup.sessionForConnection(connectionID) {
                environmentState.openJobQueueTab(for: session)
            }
        default:
            break
        }
    }

    private func selectAutomationTab(_ target: String) {
        switch target {
        case "next": tabStore.activateNextTab()
        case "previous": tabStore.activatePreviousTab()
        case "first": if let tab = tabStore.tabs.first { tabStore.selectTab(tab) }
        case "last": if let tab = tabStore.tabs.last { tabStore.selectTab(tab) }
        default:
            if let index = Int(target), tabStore.tabs.indices.contains(index) { tabStore.selectTab(tabStore.tabs[index]) }
        }
    }
}
#endif
