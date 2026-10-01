import Foundation

extension TabReloader {
    /// Reloads one tab's data with its own view model. Returns a failure message, or nil.
    static func performReload(of tab: WorkspaceTab, environmentState: EnvironmentState) async -> String? {
        switch tab.kind {
        case .maintenance:
            await tab.maintenance?.refresh()
        case .mssqlMaintenance:
            await tab.mssqlMaintenance?.refresh()
        case .activityMonitor:
            tab.activityMonitor?.refresh()
        case .errorLog:
            await tab.errorLogVM?.refresh()
        case .extendedEvents:
            await tab.extendedEventsVM?.loadSessions()
        case .structure:
            await tab.structureEditor?.reload()
        case .jobQueue:
            guard let jobs = tab.jobQueue else { return nil }
            await jobs.reloadJobs()
            return jobs.errorMessage
        case .diagram:
            if let diagram = tab.diagram {
                await environmentState.diagramBuilder.refreshDiagram(for: diagram)
            }
        case .profiler:
            tab.profilerVM?.refresh()
        case .resourceGovernor:
            tab.resourceGovernorVM?.refresh()
        case .tuningAdvisor:
            tab.tuningAdvisorVM?.refresh()
        case .policyManagement:
            tab.policyManagementVM?.refresh()
        default:
            break
        }
        return nil
    }
}
