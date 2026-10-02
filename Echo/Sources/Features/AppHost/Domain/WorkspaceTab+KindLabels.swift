import Foundation

/// What a tab kind is called and its symbol, in the tab strip and the tab overview (round 35.1).
extension WorkspaceTab.Kind {
    var displayName: String {
        switch self {
        case .query: return "Queries"
        case .structure: return "Structure"
        case .diagram: return "Diagrams"
        case .jobQueue: return "Jobs"
        case .psql: return "Terminal"
        case .extensionStructure: return "Extension Details"
        case .extensionsManager: return "Extensions"
        case .activityMonitor: return "Activity"
        case .maintenance, .mssqlMaintenance: return "Maintenance"
        case .extendedEvents: return "Extended Events"
        case .availabilityGroups: return "Availability Groups"
        case .databaseSecurity, .postgresSecurity, .mysqlSecurity: return "Database Security"
        case .postgresAdvancedObjects, .mssqlAdvancedObjects: return "Advanced Objects"
        case .serverSecurity: return "Server Security"
        case .errorLog: return "Error Log"
        case .profiler: return "SQL Profiler"
        case .resourceGovernor: return "Resource Governor"
        case .serverProperties: return "Server Properties"
        case .tuningAdvisor: return "Tuning Advisor"
        case .policyManagement: return "Policy Management"
        case .schemaDiff: return "Schema Diff"
        case .queryBuilder: return "Query Builder"
        }
    }

    /// One picture per kind of tab, none repeated (round 49, IC1). Advanced Objects on PostgreSQL
    /// is four tools that each have their own (`WorkspaceTab.iconName`).
    var icon: String {
        switch self {
        case .query: return "chevron.left.forwardslash.chevron.right"
        case .structure: return "tablecells.badge.ellipsis"
        case .diagram: return "point.3.connected.trianglepath.dotted"
        case .jobQueue: return "calendar.badge.clock"
        case .psql: return "terminal"
        case .extensionStructure: return "puzzlepiece"
        case .extensionsManager: return "puzzlepiece.extension"
        case .activityMonitor: return "gauge.with.dots.needle.67percent"
        case .maintenance, .mssqlMaintenance: return "wrench.and.screwdriver"
        case .extendedEvents: return "bolt.horizontal"
        case .availabilityGroups: return "server.rack"
        case .databaseSecurity, .postgresSecurity, .mysqlSecurity: return "lock.shield"
        case .serverSecurity: return "key"
        case .postgresAdvancedObjects: return "cube.transparent"
        case .mssqlAdvancedObjects: return "shippingbox"
        case .errorLog: return "exclamationmark.bubble"
        case .profiler: return "waveform"
        case .resourceGovernor: return "gauge.with.needle"
        case .serverProperties: return "slider.horizontal.3"
        case .tuningAdvisor: return "tuningfork"
        case .policyManagement: return "checkmark.seal"
        case .schemaDiff: return "arrow.left.arrow.right.square"
        case .queryBuilder: return "rectangle.connected.to.line.below"
        }
    }
}

extension WorkspaceTab {
    /// The symbol this tab shows: its kind's, or the tool's own where one kind is several tools.
    var iconName: String { postgresAdvancedObjectsVM?.group.icon ?? kind.icon }
}
