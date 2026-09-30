import Foundation

/// Tool tabs start with the shared ToolTabHeader (Design/05-components › Tool tabs, TT2).
/// Object editors (structure, diagram, table data, psql) and query tabs don't.
extension WorkspaceTab.Kind {
    var isToolTab: Bool {
        switch self {
        case .extensionsManager, .maintenance, .mssqlMaintenance, .extendedEvents, .availabilityGroups,
             .databaseSecurity, .postgresSecurity, .mysqlSecurity, .serverSecurity, .errorLog, .profiler,
             .resourceGovernor, .serverProperties, .tuningAdvisor, .policyManagement,
             .postgresAdvancedObjects, .mssqlAdvancedObjects, .schemaDiff, .queryBuilder:
            true
        case .query, .structure, .diagram, .jobQueue, .psql, .extensionStructure, .activityMonitor:
            false
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
