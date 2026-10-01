import Foundation

/// Tool tabs start with the shared ToolTabHeader (Design/05-components › Tool tabs, TT2): every
/// tab with a family (round 37.1). Activity Monitor and Agent Jobs draw their cards and header
/// themselves; the query editor and the psql console have no header.
extension WorkspaceTab.Kind {
    var isToolTab: Bool {
        guard toolFamily != nil else { return false }
        switch self {
        case .activityMonitor, .jobQueue: return false
        default: return true
        }
    }
}

extension WorkspaceTab.Kind {
    /// Tabs with the bottom panel under their content card: the query tab's results, and a
    /// tool's Messages (and Live Data) panel (TT1). They share maximising the panel.
    var hasBottomPanel: Bool {
        switch self {
        case .query, .maintenance, .mssqlMaintenance, .extendedEvents, .databaseSecurity, .postgresSecurity,
             .mysqlSecurity, .serverSecurity, .serverProperties, .schemaDiff:
            true
        case .structure, .diagram, .jobQueue, .psql, .extensionStructure, .extensionsManager, .activityMonitor,
             .availabilityGroups, .errorLog, .profiler, .resourceGovernor, .tuningAdvisor, .policyManagement,
             .postgresAdvancedObjects, .mssqlAdvancedObjects, .queryBuilder:
            false
        }
    }
}
