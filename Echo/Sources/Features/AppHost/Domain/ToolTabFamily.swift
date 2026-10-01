import Foundation

/// The five families of tool tabs, by the shape of their work (round 37.1). Every tab but the
/// query editor and the psql console (which follows the editor, round 28) belongs to one, and
/// each family has its one layout idea (round 37.4).
enum ToolTabFamily: String, CaseIterable, Sendable {
    /// Live data that changes while you watch: tiles first, then a live table.
    case monitor
    /// A list of things you create, change and remove, with the selected one's details beside it.
    case manage
    /// Findings about the server or database, worst first, each with the fix you can run.
    case health
    /// One object's settings, applied together from a bar at the bottom.
    case properties
    /// A drawing you move around in, with its view controls in a floating glass bar.
    case canvas
}

extension WorkspaceTab.Kind {
    /// The tab's family, or nil for the query editor and the psql console.
    var toolFamily: ToolTabFamily? {
        switch self {
        case .activityMonitor, .profiler, .extendedEvents:
            .monitor
        case .jobQueue, .serverSecurity, .databaseSecurity, .postgresSecurity, .mysqlSecurity, .policyManagement,
             .availabilityGroups, .resourceGovernor, .extensionsManager, .postgresAdvancedObjects, .mssqlAdvancedObjects:
            .manage
        case .maintenance, .mssqlMaintenance, .tuningAdvisor, .errorLog:
            .health
        case .serverProperties, .structure, .extensionStructure:
            .properties
        case .diagram, .queryBuilder, .schemaDiff:
            .canvas
        case .query, .psql:
            nil
        }
    }
}
