import SwiftUI

struct ServerGroup: Identifiable {
    let connection: SavedConnection
    let databaseGroups: [String: DatabaseGroup]
    let totalTabCount: Int
    var id: UUID { connection.id }
}

struct DatabaseGroup: Identifiable {
    let databaseName: String
    let sections: [SectionGroup]
    var id: String { databaseName }
}

struct SectionGroup: Identifiable {
    let kind: WorkspaceTab.Kind
    let tabs: [WorkspaceTab]
    var id: String { kind.displayName }
}

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
        case .tableData: return "Table Data"
        case .schemaDiff: return "Schema Diff"
        case .queryBuilder: return "Query Builder"
        }
    }

    var icon: String {
        switch self {
        case .query: return "tablecells"
        case .structure: return "wrench.and.screwdriver"
        case .diagram: return "chart.xyaxis.line"
        case .jobQueue: return "gearshape"
        case .psql: return "terminal"
        case .extensionStructure: return "puzzlepiece.fill"
        case .extensionsManager: return "puzzlepiece"
        case .activityMonitor: return "chart.bar.doc.horizontal"
        case .maintenance, .mssqlMaintenance: return "wrench.and.screwdriver"
        case .extendedEvents: return "bolt.horizontal"
        case .availabilityGroups: return "server.rack"
        case .databaseSecurity, .postgresSecurity, .mysqlSecurity, .serverSecurity, .postgresAdvancedObjects: return "lock.shield"
        case .mssqlAdvancedObjects: return "puzzlepiece.extension"
        case .errorLog: return "doc.text"
        case .profiler: return "trace"
        case .resourceGovernor: return "r.square.on.square"
        case .serverProperties: return "gearshape.2"
        case .tuningAdvisor: return "wand.and.stars"
        case .policyManagement: return "checkmark.seal"
        case .tableData: return "tablecells.badge.ellipsis"
        case .schemaDiff: return "doc.on.doc"
        case .queryBuilder: return "hammer"
        }
    }
}
