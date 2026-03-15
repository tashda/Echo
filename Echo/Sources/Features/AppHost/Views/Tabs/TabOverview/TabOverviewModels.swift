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
        case .queryStore: return "Query Store"
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
        case .queryStore: return "chart.bar.xaxis"
        }
    }
}
