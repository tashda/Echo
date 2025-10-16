import Foundation

struct SQLEditorCompletionContext: Equatable {
    var databaseType: DatabaseType
    var selectedDatabase: String?
    var defaultSchema: String?
    var structure: DatabaseStructure?

    init(
        databaseType: DatabaseType,
        selectedDatabase: String? = nil,
        defaultSchema: String? = nil,
        structure: DatabaseStructure? = nil
    ) {
        self.databaseType = databaseType
        self.selectedDatabase = selectedDatabase
        self.defaultSchema = defaultSchema
        self.structure = structure
    }
}

enum SQLAutoCompletionKind: String, Equatable {
    case schema
    case table
    case view
    case materializedView
    case column
    case function
    case keyword
    case snippet
    case parameter
    case join

    var iconSystemName: String {
        switch self {
        case .schema: return "square.grid.2x2"
        case .table: return "tablecells"
        case .view: return "rectangle.stack"
        case .materializedView: return "rectangle.stack.fill"
        case .column: return "doc.text"
        case .function: return "function"
        case .keyword: return "textformat"
        case .snippet: return "text.badge.plus"
        case .parameter: return "number"
        case .join: return "link"
        }
    }
}

struct SQLAutoCompletionSuggestion: Identifiable, Equatable {
    struct Origin: Equatable {
        let database: String?
        let schema: String?
        let object: String?
        let column: String?

        init(database: String? = nil,
             schema: String? = nil,
             object: String? = nil,
             column: String? = nil) {
            self.database = database?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.schema = schema?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.object = object?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.column = column?.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var hasServerContext: Bool {
            if let database, !database.isEmpty { return true }
            if let schema, !schema.isEmpty { return true }
            if let object, !object.isEmpty { return true }
            return column?.isEmpty == false
        }
    }

    struct TableColumn: Equatable {
        let name: String
        let dataType: String
        let isNullable: Bool
        let isPrimaryKey: Bool
    }

    let id: String
    let title: String
    let subtitle: String?
    let detail: String?
    let insertText: String
    let kind: SQLAutoCompletionKind
    let origin: Origin?
    let dataType: String?
    let tableColumns: [TableColumn]?

    init(id: String = UUID().uuidString,
         title: String,
         subtitle: String? = nil,
         detail: String? = nil,
         insertText: String,
         kind: SQLAutoCompletionKind,
         origin: Origin? = nil,
         dataType: String? = nil,
         tableColumns: [TableColumn]? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.detail = detail ?? subtitle
        self.insertText = insertText
        self.kind = kind
        if let origin, origin.hasServerContext {
            self.origin = origin
        } else {
            self.origin = nil
        }
        self.dataType = dataType
        self.tableColumns = tableColumns?.isEmpty == true ? nil : tableColumns
    }
}

extension SQLAutoCompletionSuggestion {
    var displayKindTitle: String {
        switch kind {
        case .schema: return "Schema"
        case .table: return "Table"
        case .view: return "View"
        case .materializedView: return "Materialized View"
        case .column: return "Column"
        case .function: return "Function"
        case .keyword: return "Keyword"
        case .snippet: return "Snippet"
        case .parameter: return "Parameter"
        case .join: return "Join"
        }
    }

    var serverDisplayName: String? {
        guard let name = origin?.database, !name.isEmpty else { return nil }
        return name
    }

    var displayObjectPath: String? {
        guard let origin else { return title.isEmpty ? (detail ?? subtitle) : title }

        func joined(_ components: [String?], separator: String = ".") -> String? {
            let trimmed = components.compactMap { component -> String? in
                guard let value = component?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                    return nil
                }
                return value
            }
            guard !trimmed.isEmpty else { return nil }
            return trimmed.joined(separator: separator)
        }

        switch kind {
        case .schema:
            return joined([origin.schema])
        case .table, .view, .materializedView:
            return joined([origin.schema, origin.object])
        case .column:
            return joined([origin.object, origin.column])
        case .function:
            return joined([origin.schema, origin.object])
        case .keyword:
            return detail ?? subtitle
        case .snippet, .parameter, .join:
            return detail ?? subtitle
        }
    }
}

struct SQLAutoCompletionSection: Identifiable, Equatable {
    var id: String { title }
    let title: String
    let suggestions: [SQLAutoCompletionSuggestion]
}

struct SQLAutoCompletionTableFocus: Equatable {
    let schema: String?
    let name: String
    let alias: String?

    func matches(schema otherSchema: String?, name otherName: String) -> Bool {
        guard name.caseInsensitiveCompare(otherName) == .orderedSame else { return false }
        guard let schema else { return true }
        guard let otherSchema else { return false }
        return schema.caseInsensitiveCompare(otherSchema) == .orderedSame
    }

    func isEquivalent(to other: SQLAutoCompletionTableFocus) -> Bool {
        guard matches(schema: other.schema, name: other.name) else { return false }
        let lhsAlias = alias?.lowercased()
        let rhsAlias = other.alias?.lowercased()
        return lhsAlias == rhsAlias
    }
}

struct SQLAutoCompletionQuery: Equatable {
    let token: String
    let prefix: String
    let pathComponents: [String]
    let replacementRange: NSRange
    let precedingKeyword: String?
    let precedingCharacter: Character?
    let focusTable: SQLAutoCompletionTableFocus?
    let tablesInScope: [SQLAutoCompletionTableFocus]
    let clause: SQLClause

    var normalizedPrefix: String { prefix.trimmingCharacters(in: .whitespacesAndNewlines) }
    var hasNonEmptyPrefix: Bool { !normalizedPrefix.isEmpty }
    var dotCount: Int { token.filter { $0 == "." }.count }
}
