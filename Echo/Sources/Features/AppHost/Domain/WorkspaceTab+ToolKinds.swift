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
