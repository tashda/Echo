import Foundation

enum SearchSidebarCategory: String, CaseIterable, Identifiable, Hashable {
    case tables
    case views
    case materializedViews
    case functions
    case procedures
    case triggers
    case columns
    case indexes
    case foreignKeys
    case queryTabs

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tables: return "Tables"
        case .views: return "Views"
        case .materializedViews: return "Materialized Views"
        case .functions: return "Functions"
        case .procedures: return "Procedures"
        case .triggers: return "Triggers"
        case .columns: return "Columns"
        case .indexes: return "Indexes"
        case .foreignKeys: return "Foreign Keys"
        case .queryTabs: return "Query Tabs"
        }
    }

    var systemImage: String {
        switch self {
        case .tables: return "table"
        case .views: return "eye"
        case .materializedViews: return "eye.fill"
        case .functions: return "function"
        case .procedures: return "gearshape"
        case .triggers: return "bolt"
        case .columns: return "square.grid.2x2"
        case .indexes: return "list.bullet.rectangle"
        case .foreignKeys: return "link"
        case .queryTabs: return "doc.text.magnifyingglass"
        }
    }

    var defaultSelected: Bool { true }
}

struct SearchSidebarResult: Identifiable, Hashable {
    enum Payload: Hashable {
        case schemaObject(schema: String, name: String, type: SchemaObjectInfo.ObjectType)
        case column(schema: String, table: String, column: String)
        case index(schema: String, table: String, name: String)
        case foreignKey(schema: String, table: String, name: String)
        case function(schema: String, name: String)
        case procedure(schema: String, name: String)
        case trigger(schema: String, table: String, name: String)
        case queryTab(tabID: UUID, connectionSessionID: UUID)
    }

    let id = UUID()
    let category: SearchSidebarCategory
    let title: String
    let subtitle: String?
    let metadata: String?
    let snippet: String?
    let payload: Payload?
}

/// Cache for the global search sidebar state.
struct GlobalSearchSidebarCache: Equatable {
    var query: String = ""
    var selectedCategories: Set<SearchSidebarCategory> = Set(SearchSidebarCategory.allCases.filter { $0.defaultSelected })
    var scope: SearchScope = .allServers
    var results: [GlobalSearchResult] = []
    var errorMessage: String?
    var isSearching: Bool = false
}

struct SearchSidebarQueryTabSnapshot: Equatable {
    let tabID: UUID
    let connectionSessionID: UUID
    let title: String
    let subtitle: String?
    let metadata: String?
    let sql: String
}
