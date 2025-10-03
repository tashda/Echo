import Foundation

enum SearchSidebarCategory: String, CaseIterable, Identifiable, Hashable {
    case tables
    case views
    case materializedViews
    case functions
    case triggers
    case columns
    case indexes
    case foreignKeys

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tables: return "Tables"
        case .views: return "Views"
        case .materializedViews: return "Materialized Views"
        case .functions: return "Functions"
        case .triggers: return "Triggers"
        case .columns: return "Columns"
        case .indexes: return "Indexes"
        case .foreignKeys: return "Foreign Keys"
        }
    }

    var systemImage: String {
        switch self {
        case .tables: return "table"
        case .views: return "eye"
        case .materializedViews: return "eye.fill"
        case .functions: return "function"
        case .triggers: return "bolt"
        case .columns: return "square.grid.2x2"
        case .indexes: return "list.bullet.rectangle"
        case .foreignKeys: return "link"
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
        case trigger(schema: String, table: String, name: String)
    }

    let id = UUID()
    let category: SearchSidebarCategory
    let title: String
    let subtitle: String?
    let metadata: String?
    let snippet: String?
    let payload: Payload?
}

struct SearchSidebarCache: Equatable {
    var query: String = ""
    var selectedCategories: Set<SearchSidebarCategory> = Set(SearchSidebarCategory.allCases.filter { $0.defaultSelected })
    var results: [SearchSidebarResult] = []
    var errorMessage: String?
    var isSearching: Bool = false
}
