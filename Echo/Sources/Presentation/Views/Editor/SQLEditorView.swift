import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import SQLAutocompleteKit

enum SQLEditorRegex {
    static let doubleQuotedStringPattern = #""(?:""|[^"])*""#
    static let doubleQuotedStringRegex = try! NSRegularExpression(
        pattern: doubleQuotedStringPattern,
        options: []
    )
}

struct SQLEditorSelection: Equatable {
    let selectedText: String
    let range: NSRange
    let lineRange: ClosedRange<Int>?

    var hasSelection: Bool { !selectedText.isEmpty }
}

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

    var iconSystemName: String {
        switch self {
        case .schema: return "square.grid.2x2"
        case .table: return "tablecells"
        case .view: return "rectangle.stack"
        case .materializedView: return "rectangle.stack.fill"
        case .column: return "text.alignleft"
        case .function: return "function"
        case .keyword: return "textformat"
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

    let id: String
    let title: String
    let subtitle: String?
    let detail: String?
    let insertText: String
    let kind: SQLAutoCompletionKind
    let origin: Origin?
    let dataType: String?

    init(id: String = UUID().uuidString,
         title: String,
         subtitle: String? = nil,
         detail: String? = nil,
         insertText: String,
         kind: SQLAutoCompletionKind,
         origin: Origin? = nil,
         dataType: String? = nil) {
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

    var normalizedPrefix: String { prefix.trimmingCharacters(in: .whitespacesAndNewlines) }
    var hasNonEmptyPrefix: Bool { !normalizedPrefix.isEmpty }
    var dotCount: Int { token.filter { $0 == "." }.count }
}

final class SQLAutoCompletionEngine {
    private struct SchemaEntry {
        let database: String
        let schema: String
    }

    private struct ObjectEntry {
        let database: String
        let schema: String
        let object: SchemaObjectInfo
    }

    private struct ColumnEntry {
        let database: String
        let schema: String
        let objectName: String
        let column: ColumnInfo
    }

    private struct Catalog {
        let schemas: [SchemaEntry]
        let tables: [ObjectEntry]
        let views: [ObjectEntry]
        let materializedViews: [ObjectEntry]
        let functions: [ObjectEntry]
        let columns: [ColumnEntry]

        init(context: SQLEditorCompletionContext) {
            guard let structure = context.structure else {
                self.schemas = []
                self.tables = []
                self.views = []
                self.materializedViews = []
                self.functions = []
                self.columns = []
                return
            }

            var schemaEntries: [SchemaEntry] = []
            var tableEntries: [ObjectEntry] = []
            var viewEntries: [ObjectEntry] = []
            var materializedEntries: [ObjectEntry] = []
            var functionEntries: [ObjectEntry] = []
            var columnEntries: [ColumnEntry] = []

            for database in structure.databases {
                let databaseName = database.name
                for schema in database.schemas {
                    let schemaName = schema.name
                    schemaEntries.append(SchemaEntry(database: databaseName, schema: schemaName))
                    for object in schema.objects {
                        let entry = ObjectEntry(database: databaseName, schema: schemaName, object: object)
                        switch object.type {
                        case .table:
                            tableEntries.append(entry)
                        case .view:
                            viewEntries.append(entry)
                        case .materializedView:
                            materializedEntries.append(entry)
                        case .function:
                            functionEntries.append(entry)
                        case .trigger:
                            break
                        }

                        if !object.columns.isEmpty {
                            for column in object.columns {
                                columnEntries.append(ColumnEntry(
                                    database: databaseName,
                                    schema: schemaName,
                                    objectName: object.name,
                                    column: column
                                ))
                            }
                        }
                    }
                }
            }

            self.schemas = schemaEntries
            self.tables = tableEntries
            self.views = viewEntries
            self.materializedViews = materializedEntries
            self.functions = functionEntries
            self.columns = columnEntries
        }
    }

    private let maxSectionItems = 40
    private let maxColumnItems = 60
    private let maxFunctionItems = 40

    private var context: SQLEditorCompletionContext?
    private var catalog: Catalog?
    private var builtInFunctions: [String] = []
    private var useTableAliasShortcuts = false

    private static let reservedLeadingKeywords: Set<String> = [
        "select", "from", "where", "join", "inner", "left", "right", "full",
        "outer", "cross", "on", "group", "by", "having", "order", "limit",
        "offset", "insert", "into", "values", "update", "set", "delete",
        "create", "drop", "alter", "vacuum", "analyze", "with", "as",
        "when", "then", "else", "case", "using"
    ]

    private static let objectContextKeywords: Set<String> = [
        "from", "join", "inner", "left", "right", "full", "outer", "cross",
        "update", "into", "delete"
    ]

    private static let columnContextKeywords: Set<String> = [
        "select", "where", "on", "and", "or", "having", "group", "order",
        "by", "set", "values", "case", "when", "then", "else", "returning",
        "using"
    ]

    func updateContext(_ newContext: SQLEditorCompletionContext?) {
        context = newContext
        if let newContext {
            catalog = Catalog(context: newContext)
            builtInFunctions = SQLAutoCompletionEngine.builtInFunctions(for: newContext.databaseType)
        } else {
            catalog = nil
            builtInFunctions = []
        }
    }

    func updateAliasPreference(useTableAliases: Bool) {
        useTableAliasShortcuts = useTableAliases
    }

    func suggestions(for query: SQLAutoCompletionQuery) -> [SQLAutoCompletionSection] {
        guard let catalog, let context else { return [] }
        guard shouldProvideCompletions(for: query) else { return [] }

        var sections: [SQLAutoCompletionSection] = []

        if query.pathComponents.count <= 1, isObjectContext(query: query) {
            let tables = makeObjectSuggestions(kind: .table, entries: catalog.tables, query: query, context: context)
            if !tables.isEmpty {
                sections.append(SQLAutoCompletionSection(title: "Tables", suggestions: tables))
            }

            let views = makeObjectSuggestions(kind: .view, entries: catalog.views, query: query, context: context)
            if !views.isEmpty {
                sections.append(SQLAutoCompletionSection(title: "Views", suggestions: views))
            }

            if !catalog.materializedViews.isEmpty {
                let materialized = makeObjectSuggestions(kind: .materializedView, entries: catalog.materializedViews, query: query, context: context)
                if !materialized.isEmpty {
                    sections.append(SQLAutoCompletionSection(title: "Materialized Views", suggestions: materialized))
                }
            }
        }

        let columns = makeColumnSuggestions(query: query, catalog: catalog, context: context)
        if !columns.isEmpty {
            sections.append(SQLAutoCompletionSection(title: "Columns", suggestions: columns))
        }

        if query.pathComponents.isEmpty && !isColumnContext(query: query) {
            let schemas = makeSchemaSuggestions(query: query, catalog: catalog)
            if !schemas.isEmpty {
                sections.append(SQLAutoCompletionSection(title: "Schemas", suggestions: schemas))
            }
        }

        return sections
    }

    private func shouldProvideCompletions(for query: SQLAutoCompletionQuery) -> Bool {
        let trimmedToken = query.token.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedToken.isEmpty && query.pathComponents.isEmpty {
            if query.precedingCharacter == "*" {
                return false
            }
            if isColumnContext(query: query) || query.precedingCharacter == "," {
                let scopeTables = tablesForColumnSuggestions(query: query)
                if !scopeTables.isEmpty {
                    return true
                }
            }
            return false
        }
        if trimmedToken == "*" && query.pathComponents.isEmpty {
            return false
        }
        let tokenLower = trimmedToken.lowercased()
        if SQLAutoCompletionEngine.reservedLeadingKeywords.contains(tokenLower) && query.pathComponents.isEmpty {
            return false
        }
        return true
    }

    private func makeSchemaSuggestions(query: SQLAutoCompletionQuery, catalog: Catalog) -> [SQLAutoCompletionSuggestion] {
        guard !catalog.schemas.isEmpty else { return [] }
        let prefixLower = query.normalizedPrefix.lowercased()
        var filtered = catalog.schemas.filter { entry in
            prefixLower.isEmpty || entry.schema.lowercased().hasPrefix(prefixLower)
        }
        filtered.sort { $0.schema.localizedCaseInsensitiveCompare($1.schema) == .orderedAscending }
        if filtered.count > maxSectionItems {
            filtered = Array(filtered.prefix(maxSectionItems))
        }
        return filtered.map { entry in
            let subtitle = entry.database.isEmpty ? nil : entry.database
            return SQLAutoCompletionSuggestion(
                id: "schema:\(entry.database).\(entry.schema)".lowercased(),
                title: entry.schema,
                subtitle: subtitle,
                detail: nil,
                insertText: "\(entry.schema).",
                kind: .schema,
                origin: .init(database: entry.database, schema: entry.schema)
            )
        }
    }

    private func makeObjectSuggestions(kind: SQLAutoCompletionKind,
                                       entries: [ObjectEntry],
                                       query: SQLAutoCompletionQuery,
                                       context: SQLEditorCompletionContext) -> [SQLAutoCompletionSuggestion] {
        guard !entries.isEmpty else { return [] }
        let prefixLower = query.normalizedPrefix.lowercased()
        let (databaseFilter, schemaFilter) = objectFilters(for: query, context: context)

        if query.pathComponents.isEmpty && !isObjectContext(query: query) {
            return []
        }

        var filtered = entries.filter { entry in
            if let databaseFilter, entry.database.lowercased() != databaseFilter { return false }
            if let schemaFilter, entry.schema.lowercased() != schemaFilter { return false }
            if !prefixLower.isEmpty && !entry.object.name.lowercased().hasPrefix(prefixLower) { return false }
            return true
        }

        if filtered.isEmpty && !prefixLower.isEmpty {
            filtered = entries.filter { entry in
                if let databaseFilter, entry.database.lowercased() != databaseFilter { return false }
                if let schemaFilter, entry.schema.lowercased() != schemaFilter { return false }
                return entry.object.name.lowercased().contains(prefixLower)
            }
        }

        filtered.sort { lhs, rhs in
            let nameComparison = lhs.object.name.localizedCaseInsensitiveCompare(rhs.object.name)
            if nameComparison != .orderedSame { return nameComparison == .orderedAscending }
            let schemaComparison = lhs.schema.localizedCaseInsensitiveCompare(rhs.schema)
            if schemaComparison != .orderedSame { return schemaComparison == .orderedAscending }
            return lhs.database.localizedCaseInsensitiveCompare(rhs.database) == .orderedAscending
        }

        if filtered.count > maxSectionItems {
            filtered = Array(filtered.prefix(maxSectionItems))
        }

        return filtered.map { entry in
            let subtitle = makeObjectSubtitle(entry: entry, context: context)
            let aliasShortcut = useTableAliasShortcuts && (kind == .table || kind == .view || kind == .materializedView)
                ? tableAliasShortcut(for: entry.object.name)
                : nil
            var insertText = makeObjectInsertText(entry: entry, query: query, context: context)
            if let aliasShortcut {
                insertText += " \(aliasShortcut)"
            }
            let detail = makeDetail(kind: kind,
                                    database: entry.database,
                                    schema: entry.schema,
                                    object: entry.object.name)
            let enrichedDetail: String?
            if let detail {
                enrichedDetail = aliasShortcut != nil ? "\(detail) • alias \(aliasShortcut!)" : detail
            } else if let aliasShortcut {
                enrichedDetail = "alias \(aliasShortcut)"
            } else {
                enrichedDetail = nil
            }
            return SQLAutoCompletionSuggestion(
                id: "object:\(kind.rawValue):\(entry.database).\(entry.schema).\(entry.object.name)".lowercased(),
                title: entry.object.name,
                subtitle: subtitle,
                detail: enrichedDetail,
                insertText: insertText,
                kind: kind,
                origin: .init(database: entry.database, schema: entry.schema, object: entry.object.name)
            )
        }
    }

    private func makeColumnSuggestions(query: SQLAutoCompletionQuery,
                                       catalog: Catalog,
                                       context: SQLEditorCompletionContext) -> [SQLAutoCompletionSuggestion] {
        guard !catalog.columns.isEmpty else { return [] }

        if !isColumnContext(query: query) {
            return []
        }

        let scopeTables = tablesForColumnSuggestions(query: query)
        guard !scopeTables.isEmpty else { return [] }

        let prefixLower = query.normalizedPrefix.lowercased()

        let filters = columnFilters(for: query, context: context)
        var results: [SQLAutoCompletionSuggestion] = []
        var seen: Set<String> = []

        func append(_ entry: ColumnEntry) {
            guard results.count < maxColumnItems else { return }
            let subtitlePieces = [entry.objectName, entry.schema]
            let subtitle = subtitlePieces.filter { !$0.isEmpty }.joined(separator: " • ")
            let detail = makeDetail(kind: .column,
                                    database: entry.database,
                                    schema: entry.schema,
                                    object: entry.objectName,
                                    column: entry.column.name)

            let identifierBase = "column:\(entry.database).\(entry.schema).\(entry.objectName).\(entry.column.name)".lowercased()
            let matchingScopes = scopeTables.filter { $0.matches(schema: entry.schema, name: entry.objectName) }

            var emittedAlias = false
            for focus in matchingScopes {
                guard let alias = focus.alias, !alias.isEmpty else { continue }
                let aliasKey = identifierBase + "|alias=" + alias.lowercased()
                guard seen.insert(aliasKey).inserted else { continue }
                emittedAlias = true
                let display = "\(alias).\(entry.column.name)"
                results.append(
                    SQLAutoCompletionSuggestion(
                        id: aliasKey,
                        title: display,
                        subtitle: subtitle.isEmpty ? nil : subtitle,
                        detail: detail,
                        insertText: display,
                        kind: .column,
                        origin: .init(database: entry.database,
                                      schema: entry.schema,
                                      object: entry.objectName,
                                      column: entry.column.name),
                        dataType: entry.column.dataType
                    )
                )
                if results.count >= maxColumnItems { return }
            }

            guard !emittedAlias else { return }
            guard seen.insert(identifierBase).inserted else { return }
            results.append(
                SQLAutoCompletionSuggestion(
                    id: identifierBase,
                    title: entry.column.name,
                    subtitle: subtitle.isEmpty ? nil : subtitle,
                    detail: detail,
                    insertText: entry.column.name,
                    kind: .column,
                    origin: .init(database: entry.database,
                                  schema: entry.schema,
                                  object: entry.objectName,
                                  column: entry.column.name),
                    dataType: entry.column.dataType
                )
            )
        }

        let primaryMatches = catalog.columns.filter { entry in
            guard matches(entry, scope: scopeTables) else { return false }
            if let schemaFilter = filters.schema, entry.schema.lowercased() != schemaFilter { return false }
            if let databaseFilter = filters.database, entry.database.lowercased() != databaseFilter { return false }
            if let tableFilter = filters.table, entry.objectName.lowercased() != tableFilter { return false }
            if !prefixLower.isEmpty && !entry.column.name.lowercased().hasPrefix(prefixLower) { return false }
            return true
        }

        for entry in primaryMatches {
            append(entry)
        }

        return results
    }

    private func makeFunctionSuggestions(query: SQLAutoCompletionQuery,
                                         catalog: Catalog,
                                         context: SQLEditorCompletionContext) -> [SQLAutoCompletionSuggestion] {
        let prefixLower = query.normalizedPrefix.lowercased()
        if prefixLower.isEmpty && builtInFunctions.isEmpty && catalog.functions.isEmpty { return [] }

        if !isColumnContext(query: query) && query.pathComponents.isEmpty {
            return []
        }

        let (_, schemaFilter) = objectFilters(for: query, context: context)
        var results: [SQLAutoCompletionSuggestion] = []
        var seen: Set<String> = []

        func append(title: String,
                   subtitle: String?,
                   originKey: String,
                   detail: String?,
                   originContext: SQLAutoCompletionSuggestion.Origin? = nil) {
            let identifier = "function:\(originKey):\(title)".lowercased()
            guard !seen.contains(identifier) else { return }
            seen.insert(identifier)
            results.append(
                SQLAutoCompletionSuggestion(
                    id: identifier,
                    title: title,
                    subtitle: subtitle,
                    detail: detail,
                    insertText: makeFunctionInsertText(title),
                    kind: .function,
                    origin: originContext
                )
            )
        }

        for entry in catalog.functions {
            if let schemaFilter, entry.schema.lowercased() != schemaFilter { continue }
            let nameLower = entry.object.name.lowercased()
            if !prefixLower.isEmpty && !nameLower.hasPrefix(prefixLower) { continue }
            let subtitlePieces = [entry.schema, entry.database == context.selectedDatabase ? nil : entry.database].compactMap { $0 }
            let subtitle = subtitlePieces.isEmpty ? nil : subtitlePieces.joined(separator: " • ")
            let detail = makeDetail(kind: .function,
                                    database: entry.database,
                                    schema: entry.schema,
                                    object: entry.object.name)
            let originContext = SQLAutoCompletionSuggestion.Origin(
                database: entry.database,
                schema: entry.schema,
                object: entry.object.name
            )
            append(title: entry.object.name,
                   subtitle: subtitle,
                   originKey: "catalog",
                   detail: detail,
                   originContext: originContext)
            if results.count >= maxFunctionItems { break }
        }

        if results.count < maxFunctionItems {
            for function in builtInFunctions {
                if !prefixLower.isEmpty && !function.lowercased().hasPrefix(prefixLower) { continue }
                let detail = makeDetail(kind: .function,
                                        database: nil,
                                        schema: nil,
                                        object: function)
                append(title: function,
                       subtitle: "Built-in",
                       originKey: "builtin",
                       detail: detail,
                       originContext: nil)
                if results.count >= maxFunctionItems { break }
            }
        }

        return results
    }

    private func objectFilters(for query: SQLAutoCompletionQuery,
                               context: SQLEditorCompletionContext) -> (database: String?, schema: String?) {
        let components = query.pathComponents
        if components.isEmpty {
            return (context.selectedDatabase?.lowercased(), nil)
        }
        if components.count == 1 {
            return (context.selectedDatabase?.lowercased(), components.last?.lowercased())
        }
        let schema = components.last?.lowercased()
        let database = components.dropLast().last?.lowercased() ?? context.selectedDatabase?.lowercased()
        return (database, schema)
    }

    private func columnFilters(for query: SQLAutoCompletionQuery,
                               context: SQLEditorCompletionContext) -> (database: String?, schema: String?, table: String?) {
        let components = query.pathComponents
        if components.isEmpty {
            return (context.selectedDatabase?.lowercased(), nil, nil)
        }
        if components.count == 1 {
            let candidate = components.last?.lowercased()
            let matchesScope = query.tablesInScope.contains { table in
                let nameMatch = table.name.lowercased() == candidate
                let schemaMatch = table.schema?.lowercased() == candidate
                let aliasMatch = table.alias?.lowercased() == candidate
                return nameMatch || schemaMatch || aliasMatch
            }
            return (context.selectedDatabase?.lowercased(), nil, matchesScope ? candidate : nil)
        }
        let table = components.last?.lowercased()
        let schema = components.dropLast().last?.lowercased()
        let database = components.dropLast(2).last?.lowercased() ?? context.selectedDatabase?.lowercased()
        return (database, schema, table)
    }

    private func makeObjectInsertText(entry: ObjectEntry,
                                      query: SQLAutoCompletionQuery,
                                      context: SQLEditorCompletionContext) -> String {
        if !query.pathComponents.isEmpty {
            return entry.object.name
        }
        if let defaultSchema = context.defaultSchema?.lowercased(), entry.schema.lowercased() == defaultSchema {
            return entry.object.name
        }
        return "\(entry.schema).\(entry.object.name)"
    }

    private func tableAliasShortcut(for name: String) -> String? {
        let components = name.split { !$0.isLetter && !$0.isNumber }
        var letters: [Character] = []

        for segment in components where !segment.isEmpty {
            if let first = segment.first {
                letters.append(Character(first.lowercased()))
            }
            for scalar in segment.unicodeScalars.dropFirst() {
                if CharacterSet.uppercaseLetters.contains(scalar) {
                    letters.append(Character(String(scalar).lowercased()))
                }
            }
        }

        if !letters.isEmpty {
            return String(letters)
        }

        let trimmed = name.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard !trimmed.isEmpty else { return nil }
        let fallback = trimmed.prefix(3).map { Character(String($0).lowercased()) }
        return fallback.isEmpty ? nil : String(fallback)
    }

    private func makeObjectSubtitle(entry: ObjectEntry,
                                    context: SQLEditorCompletionContext) -> String? {
        var parts: [String] = [entry.schema]
        if let selectedDatabase = context.selectedDatabase, !selectedDatabase.isEmpty {
            if entry.database.caseInsensitiveCompare(selectedDatabase) != .orderedSame {
                parts.append(entry.database)
            }
        } else if !entry.database.isEmpty {
            parts.append(entry.database)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func detailTitle(for kind: SQLAutoCompletionKind) -> String {
        switch kind {
        case .schema: return "Schema"
        case .table: return "Table"
        case .view: return "View"
        case .materializedView: return "Materialized View"
        case .column: return "Column"
        case .function: return "Function"
        case .keyword: return "Keyword"
        }
    }

    private func makeDetail(kind: SQLAutoCompletionKind,
                            database: String?,
                            schema: String?,
                            object: String?,
                            column: String? = nil) -> String? {
        var components: [String] = []
        if let database, !database.isEmpty { components.append(database) }
        if let schema, !schema.isEmpty { components.append(schema) }
        if let object, !object.isEmpty { components.append(object) }
        if let column, !column.isEmpty { components.append(column) }
        guard !components.isEmpty else { return nil }
        return "\(detailTitle(for: kind)) \(components.joined(separator: "."))"
    }

    private func makeFunctionInsertText(_ name: String) -> String {
        "\(name)("
    }

    private static func builtInFunctions(for databaseType: DatabaseType) -> [String] {
        switch databaseType {
        case .microsoftSQL:
            return [
                "COUNT",
                "SUM",
                "AVG",
                "MIN",
                "MAX",
                "LEN",
                "LOWER",
                "UPPER",
                "GETDATE",
                "DATEADD",
                "DATEDIFF",
                "ISNULL",
                "COALESCE",
                "ROUND",
                "ABS",
                "CEILING",
                "FLOOR",
                "NEWID",
                "CONVERT",
                "CAST",
                "FORMAT",
                "LEFT",
                "RIGHT",
                "SUBSTRING"
            ]
        case .postgresql:
            return [
                "COUNT",
                "SUM",
                "AVG",
                "MIN",
                "MAX",
                "LOWER",
                "UPPER",
                "CURRENT_DATE",
                "CURRENT_TIMESTAMP",
                "NOW",
                "COALESCE",
                "TO_CHAR",
                "TO_DATE",
                "TO_TIMESTAMP",
                "ROUND",
                "TRIM"
            ]
        case .mysql:
            return [
                "COUNT",
                "SUM",
                "AVG",
                "MIN",
                "MAX",
                "LOWER",
                "UPPER",
                "NOW",
                "CURDATE",
                "CURTIME",
                "DATE_ADD",
                "DATE_SUB",
                "COALESCE",
                "IFNULL",
                "ROUND",
                "TRIM"
            ]
        case .sqlite:
            return [
                "COUNT",
                "SUM",
                "AVG",
                "MIN",
                "MAX",
                "LOWER",
                "UPPER",
                "DATE",
                "DATETIME",
                "COALESCE",
                "IFNULL",
                "ROUND",
                "ABS",
                "LENGTH"
            ]
        }
    }

    private func isObjectContext(query: SQLAutoCompletionQuery) -> Bool {
        if !query.pathComponents.isEmpty { return true }
        guard let keyword = query.precedingKeyword else { return false }
        return SQLTextView.objectContextKeywords.contains(keyword)
    }

    private func isColumnContext(query: SQLAutoCompletionQuery) -> Bool {
        if query.precedingCharacter == "," { return true }
        if !query.pathComponents.isEmpty { return true }
        guard let keyword = query.precedingKeyword else { return false }
        if SQLTextView.objectContextKeywords.contains(keyword) {
            return false
        }
        return SQLTextView.columnContextKeywords.contains(keyword)
    }

    private func tablesForColumnSuggestions(query: SQLAutoCompletionQuery) -> [SQLAutoCompletionTableFocus] {
        var tables: [SQLAutoCompletionTableFocus] = []
        if !query.tablesInScope.isEmpty {
            tables = query.tablesInScope
        } else if let focus = query.focusTable {
            tables = [focus]
        }

        guard !tables.isEmpty else { return [] }

        var unique: [SQLAutoCompletionTableFocus] = []
        for table in tables {
            if !unique.contains(where: { $0.isEquivalent(to: table) }) {
                unique.append(table)
            }
        }
        return unique
    }

    private func matches(_ entry: ColumnEntry, scope: [SQLAutoCompletionTableFocus]) -> Bool {
        guard !scope.isEmpty else { return true }
        for table in scope {
            if table.matches(schema: entry.schema, name: entry.objectName) {
                return true
            }
            if table.schema == nil && entry.objectName.lowercased() == table.name.lowercased() {
                return true
            }
        }
        return false
    }
}

struct SQLEditorView: View {
    @Binding var text: String
    var theme: SQLEditorTheme
    var display: SQLEditorDisplayOptions
    var backgroundColor: Color?
    var completionContext: SQLEditorCompletionContext?
    var onTextChange: (String) -> Void
    var onSelectionChange: (SQLEditorSelection) -> Void
    var onSelectionPreviewChange: (SQLEditorSelection) -> Void
    var clipboardMetadata: ClipboardHistoryStore.Entry.Metadata
    var onAddBookmark: (String) -> Void

    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore

    init(
        text: Binding<String>,
        theme: SQLEditorTheme,
        display: SQLEditorDisplayOptions,
        backgroundColor: Color? = nil,
        completionContext: SQLEditorCompletionContext? = nil,
        onTextChange: @escaping (String) -> Void,
        onSelectionChange: @escaping (SQLEditorSelection) -> Void,
        onSelectionPreviewChange: @escaping (SQLEditorSelection) -> Void,
        clipboardMetadata: ClipboardHistoryStore.Entry.Metadata = .empty,
        onAddBookmark: @escaping (String) -> Void = { _ in }
    ) {
        _text = text
        self.theme = theme
        self.display = display
        self.backgroundColor = backgroundColor
        self.completionContext = completionContext
        self.onTextChange = onTextChange
        self.onSelectionChange = onSelectionChange
        self.onSelectionPreviewChange = onSelectionPreviewChange
        self.clipboardMetadata = clipboardMetadata
        self.onAddBookmark = onAddBookmark
    }

    var body: some View {
#if os(macOS)
        MacSQLEditorRepresentable(
            text: $text,
            theme: theme,
            display: display,
            backgroundColor: backgroundColor,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange,
            onSelectionPreviewChange: onSelectionPreviewChange,
            clipboardHistory: clipboardHistory,
            clipboardMetadata: clipboardMetadata,
            onAddBookmark: onAddBookmark,
            completionContext: completionContext
        )
#else
        IOSSQLEditorRepresentable(
            text: $text,
            theme: theme,
            display: display,
            backgroundColor: backgroundColor,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange,
            onSelectionPreviewChange: onSelectionPreviewChange,
            clipboardHistory: clipboardHistory,
            clipboardMetadata: clipboardMetadata,
            onAddBookmark: onAddBookmark,
            completionContext: completionContext
        )
#endif
    }
}

#if os(macOS)
private struct MacSQLEditorRepresentable: NSViewRepresentable {
    @Binding var text: String
    var theme: SQLEditorTheme
    var display: SQLEditorDisplayOptions
    var backgroundColor: Color?
    var onTextChange: (String) -> Void
    var onSelectionChange: (SQLEditorSelection) -> Void
    var onSelectionPreviewChange: (SQLEditorSelection) -> Void
    var clipboardHistory: ClipboardHistoryStore
    var clipboardMetadata: ClipboardHistoryStore.Entry.Metadata
    var onAddBookmark: (String) -> Void
    var completionContext: SQLEditorCompletionContext?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> SQLScrollView {
        let scrollView = SQLScrollView(
            theme: theme,
            display: display,
            backgroundOverride: backgroundColor.map(NSColor.init),
            completionContext: completionContext
        )
        let textView = scrollView.sqlTextView
        textView.sqlDelegate = context.coordinator
        textView.clipboardHistory = clipboardHistory
        textView.clipboardMetadata = clipboardMetadata
        textView.string = text
        textView.reapplyHighlighting()
        textView.completionContext = completionContext
        context.coordinator.textView = textView

        // Make first responder once after attachment
        DispatchQueue.main.async { [weak textView, weak scrollView] in
            guard let tv = textView else { return }
            scrollView?.window?.makeFirstResponder(tv)
        }
        return scrollView
    }

    func updateNSView(_ nsView: SQLScrollView, context: Context) {
        nsView.updateTheme(theme)
        nsView.updateDisplay(display)
        nsView.updateBackgroundOverride(backgroundColor.map(NSColor.init))
        nsView.completionContext = completionContext
        let textView = nsView.sqlTextView
        context.coordinator.theme = theme
        context.coordinator.parent = self
        textView.clipboardHistory = clipboardHistory
        textView.clipboardMetadata = clipboardMetadata

        // Update binding -> editor content without stealing focus or resetting selection unnecessarily
        if textView.string != text {
            context.coordinator.isUpdatingFromBinding = true
            let currentSelection = textView.selectedRange()
            textView.string = text
            textView.reapplyHighlighting()
            // Try to restore selection if still valid
            let maxLen = (text as NSString).length
            let restored = NSRange(
                location: min(currentSelection.location, max(0, maxLen)),
                length: min(currentSelection.length, max(0, maxLen - min(currentSelection.location, maxLen)))
            )
            textView.setSelectedRange(restored)
            context.coordinator.isUpdatingFromBinding = false
        }

        // Update text container width only if the available width changed
        DispatchQueue.main.async {
            let scrollViewWidth = nsView.bounds.width
            let rulerWidth = nsView.verticalRulerView?.ruleThickness ?? 0
            let availableWidth = max(scrollViewWidth - rulerWidth, 320)

            if let textContainer = textView.textContainer {
                if nsView.currentDisplayOptions.wrapLines {
                    if textContainer.size.width != availableWidth {
                        textContainer.size = NSSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude)
                    }
                } else {
                    textContainer.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                }
            }
        }
    }

    final class Coordinator: NSObject, SQLTextViewDelegate {
        var parent: MacSQLEditorRepresentable
        weak var textView: SQLTextView?
        var theme: SQLEditorTheme
        var isUpdatingFromBinding = false

        init(parent: MacSQLEditorRepresentable) {
            self.parent = parent
            self.theme = parent.theme
        }

        func sqlTextView(_ view: SQLTextView, didUpdateText text: String) {
            guard !isUpdatingFromBinding else { return }
            parent.text = text
            parent.onTextChange(text)
        }

        func sqlTextView(_ view: SQLTextView, didChangeSelection selection: SQLEditorSelection) {
            parent.onSelectionChange(selection)
        }

        func sqlTextView(_ view: SQLTextView, didPreviewSelection selection: SQLEditorSelection) {
            parent.onSelectionPreviewChange(selection)
        }

        func sqlTextView(_ view: SQLTextView, didRequestBookmarkWithContent content: String) {
            parent.onAddBookmark(content)
        }
    }
}

private protocol SQLTextViewDelegate: AnyObject {
    func sqlTextView(_ view: SQLTextView, didUpdateText text: String)
    func sqlTextView(_ view: SQLTextView, didChangeSelection selection: SQLEditorSelection)
    func sqlTextView(_ view: SQLTextView, didPreviewSelection selection: SQLEditorSelection)
    func sqlTextView(_ view: SQLTextView, didRequestBookmarkWithContent content: String)
}

extension SQLTextViewDelegate {
    func sqlTextView(_ view: SQLTextView, didPreviewSelection selection: SQLEditorSelection) {}
    func sqlTextView(_ view: SQLTextView, didRequestBookmarkWithContent content: String) {}
}

private final class SQLScrollView: NSScrollView {
    let sqlTextView: SQLTextView
    private var theme: SQLEditorTheme
    private var displayOptions: SQLEditorDisplayOptions
    private let lineNumberRuler: LineNumberRulerView
    private var backgroundOverride: NSColor?
    var completionContext: SQLEditorCompletionContext? {
        didSet { sqlTextView.completionContext = completionContext }
    }

    var currentDisplayOptions: SQLEditorDisplayOptions { displayOptions }

    init(theme: SQLEditorTheme,
         display: SQLEditorDisplayOptions,
         backgroundOverride: NSColor?,
         completionContext: SQLEditorCompletionContext? = nil) {
        self.displayOptions = display
        self.backgroundOverride = backgroundOverride
        self.completionContext = completionContext
        self.sqlTextView = SQLTextView(
            theme: theme,
            displayOptions: display,
            backgroundOverride: backgroundOverride,
            completionContext: completionContext
        )
        self.lineNumberRuler = LineNumberRulerView(textView: sqlTextView, theme: theme)
        self.theme = theme
        super.init(frame: .zero)
        drawsBackground = false
        wantsLayer = true
        layer?.cornerRadius = 0
        layer?.masksToBounds = false
        borderType = .noBorder
        drawsBackground = false
        backgroundColor = .clear
        contentView.drawsBackground = false
        contentView.backgroundColor = .clear
        hasVerticalScroller = true
        hasHorizontalScroller = false
        autohidesScrollers = true
        autoresizesSubviews = true
        documentView = sqlTextView
        scrollerStyle = .overlay
        verticalScrollElasticity = .automatic

        sqlTextView.minSize = NSSize(width: 0, height: 320)
        sqlTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        sqlTextView.isVerticallyResizable = true
        sqlTextView.isHorizontallyResizable = false
        sqlTextView.autoresizingMask = [.width]
        sqlTextView.setAccessibilityIdentifier("QueryEditorTextView")

        hasVerticalRuler = true
        rulersVisible = true
        verticalRulerView = lineNumberRuler

        if let textContainer = sqlTextView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.containerSize = NSSize(width: 800, height: CGFloat.greatestFiniteMagnitude)
            textContainer.lineFragmentPadding = 10
        }

        sqlTextView.setFrameSize(NSSize(width: 800, height: 360))
        lineNumberRuler.needsDisplay = true
        applyTheme()
        applyDisplay()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        sqlTextView.cancelPendingCompletions()
    }

    func updateTheme(_ theme: SQLEditorTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        applyTheme()
    }

    func updateBackgroundOverride(_ color: NSColor?) {
        guard backgroundOverride != color else { return }
        backgroundOverride = color
        contentView.backgroundColor = color ?? .clear
        sqlTextView.backgroundOverride = color
    }

    func updateDisplay(_ options: SQLEditorDisplayOptions) {
        guard displayOptions != options else { return }
        displayOptions = options
        sqlTextView.displayOptions = options
        applyDisplay()
    }

    private func applyTheme() {
        backgroundColor = .clear
        contentView.backgroundColor = backgroundOverride ?? .clear
        sqlTextView.theme = theme
        sqlTextView.backgroundOverride = backgroundOverride
        lineNumberRuler.theme = theme
    }

    private func applyDisplay() {
        sqlTextView.displayOptions = displayOptions

        if displayOptions.wrapLines {
            hasHorizontalScroller = false
            autohidesScrollers = true
            sqlTextView.isHorizontallyResizable = false
            sqlTextView.textContainer?.widthTracksTextView = true
        } else {
            hasHorizontalScroller = true
            autohidesScrollers = false
            sqlTextView.isHorizontallyResizable = true
            sqlTextView.textContainer?.widthTracksTextView = false
            sqlTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }

        if displayOptions.showLineNumbers {
            hasVerticalRuler = true
            rulersVisible = true
            verticalRulerView = lineNumberRuler
            lineNumberRuler.ruleThickness = 40
            lineNumberRuler.setFrameSize(NSSize(width: 40, height: lineNumberRuler.frame.size.height))
            lineNumberRuler.setBoundsSize(NSSize(width: 40, height: lineNumberRuler.bounds.size.height))
            lineNumberRuler.clientView = sqlTextView
            lineNumberRuler.theme = theme
            lineNumberRuler.sqlTextView = sqlTextView
            lineNumberRuler.needsDisplay = true
        } else {
            hasVerticalRuler = false
            rulersVisible = false
            verticalRulerView = nil
        }
    }
}

private func sqlRangeIsValid(_ range: NSRange, upperBound: Int) -> Bool {
    guard range.location >= 0, range.length >= 0 else { return false }
    guard upperBound >= 0 else { return false }
    if range.length == 0 {
        return range.location <= upperBound
    }
    guard upperBound > 0 else { return false }
    guard range.location < upperBound else { return false }
    return NSMaxRange(range) <= upperBound
}

private final class SQLTextView: NSTextView, NSTextViewDelegate {
    weak var sqlDelegate: SQLTextViewDelegate?
    weak var clipboardHistory: ClipboardHistoryStore?
    var clipboardMetadata: ClipboardHistoryStore.Entry.Metadata = .empty
    var theme: SQLEditorTheme { didSet { applyTheme() } }
    var displayOptions: SQLEditorDisplayOptions { didSet { applyDisplayOptions() } }
    var backgroundOverride: NSColor? { didSet { applyTheme() } }
    var completionContext: SQLEditorCompletionContext? {
        didSet {
            completionEngine.updateContext(completionContext)
            refreshCompletions(immediate: true)
        }
    }

    private let sqruffProvider = SqruffCompletionProvider.shared
    private weak var lineNumberRuler: LineNumberRulerView?
    private var paragraphStyle = NSMutableParagraphStyle()
    private var highlightWorkItem: DispatchWorkItem?
    private var symbolHighlightWorkItem: DispatchWorkItem?
    private var selectionMatchRanges: [NSRange] = []
    private var caretMatchRanges: [NSRange] = []
    private var completionWorkItem: DispatchWorkItem?
    private var completionTask: Task<Void, Never>?
    private var completionGeneration = 0
    private let completionEngine = SQLAutoCompletionEngine()
    private var completionController: SQLAutoCompletionController?
    private var isApplyingCompletion = false
    private var suppressNextCompletionRefresh = false

    private enum CompletionTriggerKind {
        case none
        case standard
        case immediate
        case evaluateSpace
    }

    private var isCompletionVisible: Bool {
        completionController?.isPresenting ?? false
    }

    private static let keywords: [String] = [
        "SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "ALTER", "DROP",
        "TRUNCATE", "REPLACE", "MERGE", "GRANT", "REVOKE", "ANALYZE",
        "EXPLAIN", "VACUUM", "FROM", "WHERE", "JOIN", "INNER", "LEFT",
        "RIGHT", "FULL", "OUTER", "CROSS", "ON", "GROUP", "BY", "HAVING",
        "ORDER", "LIMIT", "OFFSET", "FETCH", "UNION", "ALL", "DISTINCT",
        "INTO", "VALUES", "SET", "RETURNING", "WITH", "AS", "AND", "OR",
        "NOT", "NULL", "IS", "IN", "BETWEEN", "EXISTS", "LIKE", "ILIKE",
        "SIMILAR", "CASE", "WHEN", "THEN", "ELSE", "END", "USING", "OVER",
        "PARTITION", "FILTER", "WINDOW", "DESC", "ASC", "TOP", "PRIMARY",
        "FOREIGN", "KEY", "CONSTRAINT", "DEFAULT", "CHECK"
    ]

    static let objectContextKeywords = SQLAutocompleteHeuristics.objectContextKeywords
    static let columnContextKeywords = SQLAutocompleteHeuristics.columnContextKeywords

    private static let singleLineCommentRegex = try! NSRegularExpression(
        pattern: "--[^\\n]*",
        options: []
    )

    private static let blockCommentRegex = try! NSRegularExpression(
        pattern: "/\\*[\\s\\S]*?\\*/",
        options: [.dotMatchesLineSeparators]
    )

    private static let singleQuotedStringRegex = try! NSRegularExpression(
        pattern: "'([^']|'')*'",
        options: []
    )
    private static let numberRegex = try! NSRegularExpression(
        pattern: "\\b\\d+(?:\\.\\d+)?\\b",
        options: []
    )

    private static let aliasTerminatingKeywords: Set<String> = [
        "WHERE", "INNER", "LEFT", "RIGHT", "ON", "JOIN", "SET", "ORDER", "GROUP", "HAVING", "LIMIT"
    ]

    private static let operatorRegex = try! NSRegularExpression(
        pattern: "(?<![A-Za-z0-9_])(?:<>|!=|>=|<=|::|\\*\\*|[-+*/=%<>!]+)",
        options: []
    )

    private static let functionRegex = try! NSRegularExpression(
        pattern: "\\b([A-Z_][A-Z0-9_]*)\\s*(?=\\()",
        options: [.caseInsensitive]
    )

    private static let keywordRegex: NSRegularExpression = {
        let pattern = "\\b(?:" + keywords.joined(separator: "|") + ")\\b"
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    private static let allKeywords: Set<String> = {
        Set(keywords.map { $0.lowercased() })
    }()

    private static let wordCharacterSet: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "_$")
        return set
    }()

    private static let completionTokenCharacterSet: CharacterSet = {
        var set = wordCharacterSet
        set.insert(charactersIn: ".")
        return set
    }()

#if os(macOS)
    private static func keywordFont(from font: NSFont) -> NSFont {
        NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
    }
#else
    private static func keywordFont(from font: UIFont) -> UIFont {
        let traits = font.fontDescriptor.symbolicTraits.union(.traitBold)
        if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: descriptor, size: font.pointSize)
        }
        return font
    }
#endif

    init(theme: SQLEditorTheme,
         displayOptions: SQLEditorDisplayOptions,
         backgroundOverride: NSColor?,
         completionContext: SQLEditorCompletionContext? = nil) {
        self.theme = theme
        self.displayOptions = displayOptions
        self.backgroundOverride = backgroundOverride
        self.completionContext = completionContext

        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 800, height: CGFloat.greatestFiniteMagnitude))

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 360), textContainer: textContainer)

        completionEngine.updateContext(completionContext)
        completionController = SQLAutoCompletionController(textView: self)

        isEditable = true
        isSelectable = true
        isRichText = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isGrammarCheckingEnabled = false
        usesAdaptiveColorMappingForDarkAppearance = true
        textContainerInset = NSSize(width: 12, height: 24)
        allowsUndo = true
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        minSize = NSSize(width: 0, height: 320)
        isHorizontallyResizable = false
        isVerticallyResizable = true
        autoresizingMask = [.width]

        textContainer.widthTracksTextView = false
        textContainer.lineFragmentPadding = 14

        configureDelegates()
        applyTheme()
        applyDisplayOptions()
        scheduleHighlighting(after: 0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(ruler: LineNumberRulerView) { lineNumberRuler = ruler }

    private func configureDelegates() {
        delegate = self
    }

    private func applyTheme() {
        font = theme.nsFont
        textColor = theme.tokenColors.plain.nsColor
        insertionPointColor = theme.tokenColors.operatorSymbol.nsColor
        drawsBackground = true
        backgroundColor = backgroundOverride ?? theme.palette.background.nsColor
        updateParagraphStyle()
        lineNumberRuler?.theme = theme
        lineNumberRuler?.highlightedLines = selectedLineRange()
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
        scheduleHighlighting(after: 0)
        if displayOptions.highlightSelectedSymbol {
            scheduleSymbolHighlights(for: currentSelectionDescriptor(), immediate: true)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let ruler = enclosingScrollView?.verticalRulerView as? LineNumberRulerView {
            configure(ruler: ruler)
            ruler.sqlTextView = self
        }
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        if completionController?.handleKeyDown(event) == true {
            return
        }
        super.keyDown(with: event)
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        let trigger = determineCompletionTrigger(for: string)
        super.insertText(string, replacementRange: replacementRange)
        let inserted = (string as? String) ?? (string as? NSAttributedString)?.string ?? ""
        handleCompletionTrigger(trigger, insertedText: inserted)
    }

    override func resignFirstResponder() -> Bool {
        hideCompletions()
        return super.resignFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
        notifySelectionPreview()
    }

    private func determineCompletionTrigger(for string: Any) -> CompletionTriggerKind {
        guard let inserted = (string as? String) ?? (string as? NSAttributedString)?.string, inserted.count == 1 else {
            return .none
        }
        guard let scalar = inserted.unicodeScalars.first else { return .none }
        if CharacterSet.letters.contains(scalar) { return .standard }
        if inserted == "_" { return .standard }
        if inserted == "." { return .immediate }
        if inserted == " " { return .evaluateSpace }
        return .none
    }

    private func handleCompletionTrigger(_ trigger: CompletionTriggerKind, insertedText: String) {
        switch trigger {
        case .immediate:
            triggerCompletion(immediate: true)
        case .standard:
            triggerCompletion(immediate: false)
        case .evaluateSpace:
            if shouldTriggerAfterKeywordSpace() {
                triggerCompletion(immediate: true)
            }
        case .none:
            if insertedText == "\n" {
                hideCompletions()
            } else if isCompletionVisible && isIdentifierContinuation(insertedText) {
                triggerCompletion(immediate: false)
            }
        }
    }

    private func triggerCompletion(immediate: Bool) {
        guard displayOptions.autoCompletionEnabled else { return }
        suppressNextCompletionRefresh = true
        refreshCompletions(immediate: immediate)
    }

    private func shouldTriggerAfterKeywordSpace() -> Bool {
        let linePrefix = currentLinePrefix()
        guard !linePrefix.isEmpty else { return false }
        let pattern = #"(?i)(from|join|update|call|exec|execute|into)\s*$"#
        return linePrefix.range(of: pattern, options: .regularExpression) != nil
    }

    private func currentLinePrefix() -> String {
        let caretLocation = selectedRange().location
        guard caretLocation != NSNotFound else { return "" }
        let nsString = string as NSString
        let lineRange = nsString.lineRange(for: NSRange(location: caretLocation, length: 0))
        let prefixLength = max(0, caretLocation - lineRange.location)
        guard prefixLength > 0 else { return "" }
        return nsString.substring(with: NSRange(location: lineRange.location, length: prefixLength))
    }

    private func isIdentifierContinuation(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "$_"))
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    func reapplyHighlighting() {
        scheduleHighlighting(after: 0)
    }

    override func didChangeText() {
        super.didChangeText()
        sqlDelegate?.sqlTextView(self, didUpdateText: string)
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
        notifySelectionChanged()
        scheduleHighlighting()
        if !isApplyingCompletion {
            if suppressNextCompletionRefresh {
                suppressNextCompletionRefresh = false
            } else if isCompletionVisible {
                refreshCompletions()
            } else {
                hideCompletions()
            }
        }
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        notifySelectionChanged()
        lineNumberRuler?.highlightedLines = selectedLineRange()
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        notifySelectionPreview()
    }

    override func copy(_ sender: Any?) {
        let selection = selectedRange()
        super.copy(sender)

        guard selection.length > 0,
              let clipboardHistory,
              let copied = PlatformClipboard.paste()
        else { return }

        clipboardHistory.record(.queryEditor, content: copied, metadata: clipboardMetadata)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let baseMenu = super.menu(for: event) ?? NSMenu(title: "Context")
        let item = NSMenuItem(title: "Add to Bookmarks", action: #selector(addSelectionToBookmarks(_:)), keyEquivalent: "")
        item.target = self
        item.isEnabled = hasBookmarkableSelection

        if let existingIndex = baseMenu.items.firstIndex(where: { $0.action == #selector(addSelectionToBookmarks(_:)) }) {
            baseMenu.removeItem(at: existingIndex)
        }

        if let firstItem = baseMenu.items.first, firstItem.isSeparatorItem == false {
            baseMenu.insertItem(NSMenuItem.separator(), at: 0)
        }
        baseMenu.insertItem(item, at: 0)
        return baseMenu
    }

    private var hasBookmarkableSelection: Bool {
        let range = selectedRange()
        guard range.length > 0 else { return false }
        let selection = (string as NSString).substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
        return !selection.isEmpty
    }

    @objc private func addSelectionToBookmarks(_ sender: Any?) {
        guard hasBookmarkableSelection else { return }
        let range = selectedRange()
        let content = (string as NSString).substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        sqlDelegate?.sqlTextView(self, didRequestBookmarkWithContent: content)
    }

    private func notifySelectionChanged() {
        let selection = currentSelectionDescriptor()
        scheduleSymbolHighlights(for: selection)
        lineNumberRuler?.highlightedLines = selectedLineRange()
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
        sqlDelegate?.sqlTextView(self, didChangeSelection: selection)
        refreshCompletions(immediate: true)
    }

    private func notifySelectionPreview() {
        let selection = currentSelectionDescriptor()
        sqlDelegate?.sqlTextView(self, didPreviewSelection: selection)
    }

    private func currentSelectionDescriptor() -> SQLEditorSelection {
        let range = selectedRange()
        let nsString = string as NSString
        let selected = (range.length > 0 && range.location != NSNotFound) ? nsString.substring(with: range) : ""
        let lines = selectedLines(for: range)
        return SQLEditorSelection(selectedText: selected, range: range, lineRange: lines)
    }

    private func scheduleSymbolHighlights(for selection: SQLEditorSelection, immediate: Bool = false) {
        symbolHighlightWorkItem?.cancel()

        guard displayOptions.highlightSelectedSymbol else {
            clearSymbolHighlights()
            return
        }

        guard selection.range.location != NSNotFound else {
            clearSymbolHighlights()
            return
        }

        let delay = immediate ? 0 : max(displayOptions.highlightDelay, 0)
        let workItem = DispatchWorkItem { [weak self] in
            self?.applySymbolHighlights(for: selection)
        }
        symbolHighlightWorkItem = workItem
        let deadline: DispatchTime = delay <= 0 ? .now() : .now() + delay
        DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem)
    }

    private func applySymbolHighlights(for selection: SQLEditorSelection) {
        guard displayOptions.highlightSelectedSymbol else {
            clearSymbolHighlights()
            return
        }
        guard let layoutManager = layoutManager else { return }

        clearSymbolHighlights()

        let nsString = string as NSString
        guard nsString.length > 0 else { return }

        if selection.range.length > 0, !selection.selectedText.isEmpty {
            selectionMatchRanges = highlightSelectionMatches(selection: selection,
                                                             in: nsString,
                                                             layoutManager: layoutManager)
        } else {
            caretMatchRanges = highlightCaretWordMatches(location: selection.range.location,
                                                         in: nsString,
                                                         layoutManager: layoutManager)
        }

        setNeedsDisplay(bounds)
        symbolHighlightWorkItem = nil
    }

    private func highlightSelectionMatches(selection: SQLEditorSelection,
                                           in string: NSString,
                                           layoutManager: NSLayoutManager) -> [NSRange] {
        var matches: [NSRange] = []
        let selectedRange = selection.range
        let target = selection.selectedText
        var searchLocation = 0
        let highlightColor = symbolHighlightColor(.bright)

        while searchLocation < string.length {
            let remainingLength = string.length - searchLocation
            let searchRange = NSRange(location: searchLocation, length: remainingLength)
            let found = string.range(of: target, options: [.literal], range: searchRange)
            if found.location == NSNotFound { break }

            if !(found.location == selectedRange.location && found.length == selectedRange.length) {
                layoutManager.addTemporaryAttribute(.backgroundColor, value: highlightColor, forCharacterRange: found)
                layoutManager.invalidateDisplay(forCharacterRange: found)
                matches.append(found)
            }

            searchLocation = found.location + 1
        }

        return matches
    }

    private func highlightCaretWordMatches(location: Int,
                                           in string: NSString,
                                           layoutManager: NSLayoutManager) -> [NSRange] {
        guard let wordRange = wordRange(at: location, in: string), wordRange.length > 0 else { return [] }
        let target = string.substring(with: wordRange)
        guard !target.isEmpty else { return [] }

        guard location >= wordRange.location && location < NSMaxRange(wordRange) else { return [] }

        var matches: [NSRange] = []
        let highlightColor = symbolHighlightColor(.strong)
        let caretLocation = location

        layoutManager.addTemporaryAttribute(.backgroundColor, value: highlightColor, forCharacterRange: wordRange)
        layoutManager.invalidateDisplay(forCharacterRange: wordRange)
        matches.append(wordRange)

        var searchLocation = 0

        while searchLocation < string.length {
            let remainingLength = string.length - searchLocation
            let searchRange = NSRange(location: searchLocation, length: remainingLength)
            let found = string.range(of: target, options: [.literal], range: searchRange)
            if found.location == NSNotFound { break }

            let containsCaret = caretLocation >= found.location && caretLocation <= NSMaxRange(found)
            if isWholeWord(range: found, in: string) && !containsCaret {
                layoutManager.addTemporaryAttribute(.backgroundColor, value: highlightColor, forCharacterRange: found)
                layoutManager.invalidateDisplay(forCharacterRange: found)
                matches.append(found)
            }

            searchLocation = found.location + max(found.length, 1)
        }

        return matches
    }

    private func clearSymbolHighlights() {
        guard let layoutManager = layoutManager else {
            selectionMatchRanges.removeAll()
            caretMatchRanges.removeAll()
            return
        }

        (selectionMatchRanges + caretMatchRanges).forEach { range in
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: range)
            layoutManager.invalidateDisplay(forCharacterRange: range)
        }
        selectionMatchRanges.removeAll()
        caretMatchRanges.removeAll()
        setNeedsDisplay(bounds)
    }

    // MARK: - Autocompletion

    private func refreshCompletions(immediate: Bool = false) {
        guard !isApplyingCompletion else { return }
        guard displayOptions.autoCompletionEnabled else {
            completionTask?.cancel()
            hideCompletions()
            return
        }

        guard completionContext != nil else {
            completionTask?.cancel()
            hideCompletions()
            return
        }

        completionWorkItem?.cancel()
        completionTask?.cancel()

        let generation: Int = {
            completionGeneration += 1
            return completionGeneration
        }()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            defer { self.completionWorkItem = nil }
            guard !self.isApplyingCompletion else { return }
            guard let controller = self.ensureCompletionController() else { return }
            guard let query = self.makeCompletionQuery() else {
                self.hideCompletions()
                return
            }

            var baseSuggestions = self.filteredSuggestions(from: self.completionEngine.suggestions(for: query), for: query)
            baseSuggestions = self.filterSuggestionsForContext(baseSuggestions, query: query)
            baseSuggestions = self.limitSuggestions(baseSuggestions)

            if baseSuggestions.isEmpty {
                self.hideCompletions()
            } else {
                controller.present(suggestions: baseSuggestions, query: query)
            }

            let currentContext = self.completionContext
            let fullText = self.string
            let caretLocation = self.currentSelectionDescriptor().range.location

            self.completionTask = Task { [weak self] in
                guard let self else { return }
                if Task.isCancelled { return }
                guard generation == self.completionGeneration else { return }
                defer {
                    if generation == self.completionGeneration {
                        self.completionTask = nil
                    }
                }
                guard let context = currentContext else { return }

                let external = await self.fetchSqruffSuggestions(for: query,
                                                                  text: fullText,
                                                                  caretLocation: caretLocation,
                                                                  context: context)
                guard !external.isEmpty, !Task.isCancelled else { return }

                var combined = self.mergeSuggestions(primary: baseSuggestions, secondary: external, query: query)
                combined = self.filterSuggestionsForContext(combined, query: query)
                combined = self.limitSuggestions(combined)

                guard !combined.isEmpty, !Task.isCancelled, generation == self.completionGeneration else { return }

                await MainActor.run {
                    guard !Task.isCancelled, generation == self.completionGeneration else { return }
                    controller.present(suggestions: combined, query: query)
                }
            }
        }

        completionWorkItem = workItem
        let deadline: DispatchTime = immediate ? .now() : .now() + 0.015
        DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem)
    }

    private func hideCompletions() {
        completionGeneration += 1
        completionWorkItem?.cancel()
        completionWorkItem = nil
        completionTask?.cancel()
        completionTask = nil
        completionController?.hide()
    }

    fileprivate func cancelPendingCompletions() {
        hideCompletions()
    }

    @discardableResult
    private func ensureCompletionController() -> SQLAutoCompletionController? {
        if completionController == nil {
            completionController = SQLAutoCompletionController(textView: self)
        }
        return completionController
    }

    fileprivate func currentCompletionQuery() -> SQLAutoCompletionQuery? {
        makeCompletionQuery()
    }

    private func makeCompletionQuery() -> SQLAutoCompletionQuery? {
        guard let textStorage else { return nil }
        let selection = selectedRange()
        guard selection.location != NSNotFound, selection.length == 0 else { return nil }

        let nsString = string as NSString
        let tokenRange = tokenRange(at: selection.location, in: nsString)
        let token: String
        if tokenRange.length > 0 {
            token = nsString.substring(with: tokenRange)
        } else {
            token = ""
        }

        let rawComponents = token.split(separator: ".", omittingEmptySubsequences: false).map { String($0) }
        let prefix = rawComponents.last ?? ""
        let pathComponents = rawComponents.dropLast().filter { !$0.isEmpty }

        let replacementRange = replacementRange(for: prefix, tokenRange: tokenRange, caretLocation: selection.location)
        let precedingKeyword = previousKeyword(before: tokenRange.location, in: nsString)
        let precedingCharacter = previousNonWhitespaceCharacter(before: tokenRange.location, in: nsString)
        let focusTable = inferFocusTable(before: selection.location, in: nsString)
        var scopeTables = self.tablesInScope(before: selection.location, in: nsString)
        if let focus = focusTable, !scopeTables.contains(where: { $0.matches(schema: focus.schema, name: focus.name) }) {
            scopeTables.append(focus)
        }

        let trailingTables = self.tablesInScope(after: selection.location, in: nsString)
        for table in trailingTables where !scopeTables.contains(where: { $0.isEquivalent(to: table) }) {
            scopeTables.append(table)
        }

        return SQLAutoCompletionQuery(
            token: token,
            prefix: prefix,
            pathComponents: Array(pathComponents),
            replacementRange: replacementRange,
            precedingKeyword: precedingKeyword,
            precedingCharacter: precedingCharacter,
            focusTable: focusTable,
            tablesInScope: scopeTables
        )
    }

    private func replacementRange(for prefix: String, tokenRange: NSRange, caretLocation: Int) -> NSRange {
        let prefixLength = (prefix as NSString).length
        let start = max(tokenRange.location, tokenRange.location + tokenRange.length - prefixLength)
        let length = max(0, caretLocation - start)
        return NSRange(location: start, length: length)
    }

    private func tokenRange(at caretLocation: Int, in string: NSString) -> NSRange {
        var start = caretLocation
        while start > 0 {
            let character = string.character(at: start - 1)
            if isCompletionCharacter(character) {
                start -= 1
            } else {
                break
            }
        }
        return NSRange(location: start, length: caretLocation - start)
    }

    private func isCompletionCharacter(_ char: unichar) -> Bool {
        guard let scalar = UnicodeScalar(char) else { return false }
        return SQLTextView.completionTokenCharacterSet.contains(scalar)
    }

    private func previousKeyword(before location: Int, in string: NSString) -> String? {
        guard location > 0 else { return nil }
        let prefixRange = NSRange(location: 0, length: location)
        let substring = string.substring(with: prefixRange)
        let trimmed = substring.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let components = trimmed.components(separatedBy: CharacterSet.alphanumerics.inverted)
        guard let keyword = components.last(where: { !$0.isEmpty }) else { return nil }
        return keyword.lowercased()
    }

    private func previousNonWhitespaceCharacter(before location: Int, in string: NSString) -> Character? {
        var index = location - 1
        while index >= 0 {
            let scalarValue = string.character(at: index)
            guard let scalar = UnicodeScalar(scalarValue) else { break }
            if !CharacterSet.whitespacesAndNewlines.contains(scalar) {
                return Character(scalar)
            }
            index -= 1
        }
        return nil
    }

    private func inferFocusTable(before location: Int, in string: NSString) -> SQLAutoCompletionTableFocus? {
        guard location > 0 else { return nil }
        let prefixRange = NSRange(location: 0, length: location)
        let substring = string.substring(with: prefixRange)
        guard !substring.isEmpty else { return nil }

        return extractTables(from: substring).last
    }

    private func normalizeIdentifier(_ value: String) -> String {
        var identifier = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let spaceIndex = identifier.firstIndex(where: { $0.isWhitespace }) {
            identifier = String(identifier[..<spaceIndex])
        }
        identifier = identifier.trimmingCharacters(in: CharacterSet(charactersIn: ",;()"))
        let removable: Set<Character> = ["\"", "'", "[", "]", "`"]
        identifier.removeAll(where: { removable.contains($0) })
        return identifier
    }

    private static func isValidIdentifier(_ value: String) -> Bool {
        guard let first = value.unicodeScalars.first else { return false }
        let identifierBody = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard CharacterSet.letters.union(CharacterSet(charactersIn: "_")).contains(first) else { return false }
        return value.unicodeScalars.dropFirst().allSatisfy { identifierBody.contains($0) }
    }

    private func knownSourceNames() -> [String] {
        guard let context = completionContext, let structure = context.structure else { return [] }
        let selectedDatabase = context.selectedDatabase?.lowercased()
        var names: Set<String> = []

        for database in structure.databases {
            if let selectedDatabase, database.name.lowercased() != selectedDatabase { continue }
            for schema in database.schemas {
                for object in schema.objects where object.type == .table || object.type == .view || object.type == .materializedView {
                    names.insert(object.name)
                }
            }
        }

        return Array(names)
    }

    private func cleanedKeyword(_ token: String) -> String {
        let trimmed = token.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        return trimmed.uppercased()
    }

    private func lastWord(in token: String) -> String? {
        guard let range = token.range(of: #"([^.]+)$"#, options: .regularExpression) else { return nil }
        return String(token[range])
    }

    private func filteredSuggestions(from sections: [SQLAutoCompletionSection], for query: SQLAutoCompletionQuery) -> [SQLAutoCompletionSuggestion] {
        let flattened = sections.flatMap { $0.suggestions }
        return sanitizeSuggestions(flattened, for: query)
    }

    private func sanitizeSuggestions(_ suggestions: [SQLAutoCompletionSuggestion], for query: SQLAutoCompletionQuery) -> [SQLAutoCompletionSuggestion] {
        let trimmedToken = query.token.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokenLower = trimmedToken.lowercased()
        let pathLower = query.pathComponents.map { $0.lowercased() }
        var seen = Set<String>()
        var result: [SQLAutoCompletionSuggestion] = []
        result.reserveCapacity(suggestions.count)

        for suggestion in suggestions {
            let key = suggestion.insertText.lowercased()
            if !tokenLower.isEmpty {
                if key == tokenLower {
                    continue
                }
                if !pathLower.isEmpty {
                    let candidate = (pathLower + [key]).joined(separator: ".")
                    if candidate == tokenLower {
                        continue
                    }
                }
            }
            if seen.insert(key).inserted {
                result.append(suggestion)
            }
        }
        return result
    }

    private func mergeSuggestions(primary: [SQLAutoCompletionSuggestion],
                                  secondary: [SQLAutoCompletionSuggestion],
                                  query: SQLAutoCompletionQuery) -> [SQLAutoCompletionSuggestion] {
        let tokenLower = query.token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var seen = Set(primary.map { $0.insertText.lowercased() })
        var combined = primary
        combined.reserveCapacity(primary.count + secondary.count)

        for suggestion in secondary {
            let key = suggestion.insertText.lowercased()
            if !tokenLower.isEmpty && key == tokenLower { continue }
            if seen.insert(key).inserted {
                combined.append(suggestion)
            }
        }
        return combined
    }

    private func filterSuggestionsForContext(_ suggestions: [SQLAutoCompletionSuggestion],
                                             query: SQLAutoCompletionQuery) -> [SQLAutoCompletionSuggestion] {
        suggestions.filter { $0.kind != .function }
    }

    private func limitSuggestions(_ suggestions: [SQLAutoCompletionSuggestion]) -> [SQLAutoCompletionSuggestion] {
        let maximum = 60
        return suggestions.count > maximum ? Array(suggestions.prefix(maximum)) : suggestions
    }

    private func fetchSqruffSuggestions(for query: SQLAutoCompletionQuery,
                                        text: String,
                                        caretLocation: Int,
                                        context: SQLEditorCompletionContext) async -> [SQLAutoCompletionSuggestion] {
        guard caretLocation != NSNotFound else { return [] }
        let nsString = text as NSString
        let boundedLocation = max(0, min(caretLocation, nsString.length))
        let position = cursorPosition(for: boundedLocation, in: nsString)

        do {
            var suggestions = try await sqruffProvider.completions(
                forText: text,
                line: position.line,
                character: position.character,
                dialect: context.databaseType
            )
            suggestions = sanitizeSuggestions(suggestions, for: query)
            return suggestions
        } catch {
            return []
        }
    }

    private func cursorPosition(for location: Int, in string: NSString) -> (line: Int, character: Int) {
        var line = 0
        var column = 0
        var index = 0
        let length = string.length
        while index < location && index < length {
            let char = string.character(at: index)
            if char == 10 { // \n
                line += 1
                column = 0
            } else if char == 13 { // \r
                if index + 1 < location && index + 1 < length && string.character(at: index + 1) == 10 {
                    index += 1
                }
                line += 1
                column = 0
            } else {
                column += 1
            }
            index += 1
        }
        return (line, column)
    }

    private func tablesInScope(before location: Int, in string: NSString) -> [SQLAutoCompletionTableFocus] {
        guard string.length > 0 else { return [] }
        let clampedLocation = min(max(location, 0), string.length)
        guard clampedLocation > 0 else { return [] }
        let prefixRange = NSRange(location: 0, length: clampedLocation)
        let substring = string.substring(with: prefixRange)
        return extractTables(from: substring)
    }

    private func tablesInScope(after location: Int, in string: NSString) -> [SQLAutoCompletionTableFocus] {
        guard string.length > 0 else { return [] }
        let clampedLocation = min(max(location, 0), string.length)
        guard clampedLocation < string.length else { return [] }
        let suffixRange = NSRange(location: clampedLocation, length: string.length - clampedLocation)
        let substring = string.substring(with: suffixRange)
        guard !substring.isEmpty else { return [] }
        return extractTables(from: substring)
    }

    private func extractTables(from text: String) -> [SQLAutoCompletionTableFocus] {
        guard !text.isEmpty else { return [] }

        let sourceNames = knownSourceNames()
        if sourceNames.isEmpty {
            return extractTablesFallback(from: text)
        }

        let knownNames = Set(sourceNames.map { $0.uppercased() })
        let tokens = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return [] }

        var unique: Set<String> = []
        var results: [SQLAutoCompletionTableFocus] = []

        for index in tokens.indices {
            guard let rawWord = lastWord(in: tokens[index]) else { continue }
            let normalizedWord = normalizeIdentifier(rawWord)
            guard !normalizedWord.isEmpty else { continue }
            let upperWord = normalizedWord.uppercased()
            guard knownNames.contains(upperWord) else { continue }

            guard index > 0 else { continue }
            let precedingKeyword = cleanedKeyword(tokens[index - 1])
            guard SQLTextView.objectContextKeywords.contains(precedingKeyword.lowercased()) else { continue }

            var alias: String?
            if index + 1 < tokens.count {
                var potentialAliasToken = tokens[index + 1]
                if potentialAliasToken.caseInsensitiveCompare("AS") == .orderedSame, index + 2 < tokens.count {
                    potentialAliasToken = tokens[index + 2]
                }
                let normalizedAlias = normalizeIdentifier(potentialAliasToken)
                let aliasUpper = normalizedAlias.uppercased()
                if !normalizedAlias.isEmpty,
                   !SQLTextView.aliasTerminatingKeywords.contains(aliasUpper),
                   SQLTextView.isValidIdentifier(normalizedAlias) {
                    alias = normalizedAlias
                }
            }

            let normalizedFullToken = normalizeIdentifier(tokens[index])
            let components = normalizedFullToken.split(separator: ".", omittingEmptySubsequences: true).map { String($0) }
            let name = components.last ?? normalizedWord
            let schema = components.dropLast().last
            let key = "\(schema?.lowercased() ?? "")|\(name.lowercased())|\(alias?.lowercased() ?? "")"
            guard unique.insert(key).inserted else { continue }
            results.append(SQLAutoCompletionTableFocus(schema: schema, name: name, alias: alias))
        }

        if results.isEmpty {
            return extractTablesFallback(from: text)
        }

        return results
    }

    private func extractTablesFallback(from text: String) -> [SQLAutoCompletionTableFocus] {
        let pattern = #"(?i)\b(from|join|update|into)\s+([A-Za-z0-9_\.\"`\[\]]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)

        var unique: Set<String> = []
        var results: [SQLAutoCompletionTableFocus] = []

        regex.enumerateMatches(in: text, options: [], range: nsRange) { match, _, _ in
            guard let match, match.numberOfRanges >= 3 else { return }
            let range = match.range(at: 2)
            guard let swiftRange = Range(range, in: text) else { return }
            let rawIdentifier = String(text[swiftRange])
            let normalized = normalizeIdentifier(rawIdentifier)
            guard !normalized.isEmpty else { return }
            let components = normalized.split(separator: ".", omittingEmptySubsequences: true).map { String($0) }
            guard let name = components.last else { return }
            let schema = components.dropLast().last
            let key = "\(schema?.lowercased() ?? "")|\(name.lowercased())"
            guard unique.insert(key).inserted else { return }
            results.append(SQLAutoCompletionTableFocus(schema: schema, name: name, alias: nil))
        }

        return results
    }

    fileprivate func applyCompletion(_ suggestion: SQLAutoCompletionSuggestion, query: SQLAutoCompletionQuery) {
        let insertion = suggestion.insertText
        var range = query.replacementRange
        guard let textStorage else { return }
        let nsString = string as NSString

        if suggestion.kind != .column {
            var lowerBound = range.location
            while lowerBound > 0 {
                let character = nsString.character(at: lowerBound - 1)
                if !isCompletionCharacter(character) { break }
                lowerBound -= 1
            }
            let upperBound = NSMaxRange(range)
            range = NSRange(location: lowerBound, length: upperBound - lowerBound)
        }

        let maxRange = nsString.length
        var upperBound = NSMaxRange(range)
        while upperBound < maxRange {
            let character = nsString.character(at: upperBound)
            if !isCompletionCharacter(character) { break }
            upperBound += 1
        }
        range.length = upperBound - range.location

        guard shouldChangeText(in: range, replacementString: insertion) else { return }

        isApplyingCompletion = true
        defer { isApplyingCompletion = false }

        textStorage.replaceCharacters(in: range, with: insertion)
        let newLocation = range.location + (insertion as NSString).length
        setSelectedRange(NSRange(location: newLocation, length: 0))
        hideCompletions()
        didChangeText()
    }

    private enum SymbolHighlightStrength {
        case bright
        case strong
    }

    private func symbolHighlightColor(_ strength: SymbolHighlightStrength) -> NSColor {
        let selectionColor = theme.palette.selection.nsColor
        let background = backgroundOverride ?? theme.palette.background.nsColor
        let fallback = selectionColor

        let blended: NSColor
        switch strength {
        case .bright:
            blended = selectionColor.blended(withFraction: 0.35, of: background) ?? fallback
            return blended.withAlphaComponent(max(blended.alphaComponent, theme.palette.isDark ? 0.55 : 0.65))
        case .strong:
            blended = selectionColor.blended(withFraction: 0.15, of: background) ?? fallback
            return blended.withAlphaComponent(max(blended.alphaComponent, theme.palette.isDark ? 0.8 : 0.75))
        }
    }

    private func wordRange(at location: Int, in string: NSString) -> NSRange? {
        let length = string.length
        guard length > 0 else { return nil }

        var index = max(0, min(location, length))
        if index == length {
            index = max(0, index - 1)
        }

        if !isWordCharacter(string.character(at: index)) {
            if index > 0 && location > 0 && isWordCharacter(string.character(at: index - 1)) {
                index -= 1
            } else {
                return nil
            }
        }

        var start = index
        while start > 0 && isWordCharacter(string.character(at: start - 1)) {
            start -= 1
        }

        var end = index
        while end < length && isWordCharacter(string.character(at: end)) {
            end += 1
        }

        guard end > start else { return nil }
        return NSRange(location: start, length: end - start)
    }

    private func isWholeWord(range: NSRange, in string: NSString) -> Bool {
        guard range.length > 0 else { return false }
        let startBoundary = isBoundary(in: string, index: range.location - 1)
        let endBoundary = isBoundary(in: string, index: NSMaxRange(range))
        return startBoundary && endBoundary
    }

    private func isBoundary(in string: NSString, index: Int) -> Bool {
        guard index >= 0 && index < string.length else { return true }
        return !isWordCharacter(string.character(at: index))
    }

    private func isWordCharacter(_ char: unichar) -> Bool {
        guard let scalar = UnicodeScalar(char) else { return false }
        return SQLTextView.wordCharacterSet.contains(scalar)
    }

    private func scheduleHighlighting(after delay: TimeInterval = 0.05) {
        highlightWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.highlightSyntax()
        }
        highlightWorkItem = workItem
        let deadline: DispatchTime = delay <= 0 ? .now() : .now() + delay
        DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem)
    }

    private func highlightSyntax() {
        guard let textStorage = textStorage else { return }
        let nsString = string as NSString
        let length = nsString.length
        guard length > 0 else { return }
        let fullRange = NSRange(location: 0, length: length)

        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: theme.nsFont,
            .foregroundColor: theme.tokenColors.plain.nsColor,
            .paragraphStyle: paragraphStyle
        ]

        textStorage.beginEditing()
        textStorage.setAttributes(baseAttributes, range: fullRange)

        var excludedRanges: [NSRange] = []

        excludedRanges += applyRegex(SQLTextView.singleQuotedStringRegex, in: nsString, color: theme.tokenColors.string.nsColor)
        excludedRanges += applyRegex(SQLEditorRegex.doubleQuotedStringRegex, in: nsString, color: theme.tokenColors.identifier.nsColor)
        excludedRanges += applyRegex(SQLTextView.blockCommentRegex, in: nsString, color: theme.tokenColors.comment.nsColor)
        excludedRanges += applyRegex(SQLTextView.singleLineCommentRegex, in: nsString, color: theme.tokenColors.comment.nsColor)

#if os(macOS)
        let keywordFont = SQLTextView.keywordFont(from: theme.nsFont)
#else
        let keywordFont = SQLTextView.keywordFont(from: theme.uiFont)
#endif

        _ = applyRegex(SQLTextView.numberRegex, in: nsString, color: theme.tokenColors.number.nsColor, skip: excludedRanges)
        _ = applyRegex(SQLTextView.operatorRegex, in: nsString, color: theme.tokenColors.operatorSymbol.nsColor, skip: excludedRanges)
        _ = applyRegex(SQLTextView.keywordRegex, in: nsString, color: theme.tokenColors.keyword.nsColor, font: keywordFont, skip: excludedRanges)

        applyFunctionHighlights(in: nsString, skip: excludedRanges)

        textStorage.endEditing()
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
    }

    private func applyRegex(_ regex: NSRegularExpression,
                            in string: NSString,
                            color: NSColor,
                            font: PlatformFont? = nil,
                            skip: [NSRange] = []) -> [NSRange] {
        guard let textStorage = textStorage else { return [] }
        let fullRange = NSRange(location: 0, length: string.length)
        var applied: [NSRange] = []
        regex.enumerateMatches(in: string as String, options: [], range: fullRange) { match, _, _ in
            guard let match = match else { return }
            let targetRange = match.range
            guard targetRange.length > 0 else { return }
            guard !intersectsExcluded(targetRange, excluded: skip) else { return }
            var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: color]
            if let font {
                attributes[.font] = font
            }
            textStorage.addAttributes(attributes, range: targetRange)
            applied.append(targetRange)
        }
        return applied
    }

    private func applyFunctionHighlights(in string: NSString, skip: [NSRange]) {
        guard let textStorage = textStorage else { return }
        let fullRange = NSRange(location: 0, length: string.length)
        SQLTextView.functionRegex.enumerateMatches(in: string as String, options: [], range: fullRange) { match, _, _ in
            guard let match = match else { return }
            let nameRange = match.range(at: 1)
            guard nameRange.length > 0 else { return }
            guard !intersectsExcluded(nameRange, excluded: skip) else { return }
            let name = string.substring(with: nameRange).lowercased()
            guard !SQLTextView.allKeywords.contains(name) else { return }
            textStorage.addAttributes([
                .foregroundColor: self.theme.tokenColors.function.nsColor
            ], range: nameRange)
        }
    }

    private func intersectsExcluded(_ range: NSRange, excluded: [NSRange]) -> Bool {
        for ex in excluded {
            if NSIntersectionRange(ex, range).length > 0 {
                return true
            }
        }
        return false
    }

    private func selectedLines(for range: NSRange) -> ClosedRange<Int>? {
        guard range.length > 0 else { return nil }
        let nsString = string as NSString
        let startLine = nsString.lineNumber(at: range.location)
        let endLine = nsString.lineNumber(at: range.location + range.length)
        return startLine...max(startLine, endLine)
    }

    func selectedLineRange() -> IndexSet {
        let range = selectedRange()
        if range.length > 0, let lines = selectedLines(for: range) {
            return IndexSet(integersIn: lines)
        }
        guard range.location != NSNotFound else { return [] }
        let caretLine = (string as NSString).lineNumber(at: range.location)
        return IndexSet(integer: caretLine)
    }

    private func applyDisplayOptions() {
        completionEngine.updateAliasPreference(useTableAliases: displayOptions.suggestTableAliasesInCompletion)
        updateParagraphStyle()
        textContainer?.widthTracksTextView = displayOptions.wrapLines
        lineNumberRuler?.highlightedLines = selectedLineRange()
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)

        if displayOptions.highlightSelectedSymbol {
            scheduleSymbolHighlights(for: currentSelectionDescriptor(), immediate: true)
        } else {
            clearSymbolHighlights()
        }

        if displayOptions.autoCompletionEnabled {
            refreshCompletions(immediate: true)
        } else {
            hideCompletions()
        }
    }

    private func updateParagraphStyle() {
        let style = paragraphStyle(for: theme, display: displayOptions)
        paragraphStyle = style
        defaultParagraphStyle = style

        typingAttributes = [
            .font: theme.nsFont,
            .foregroundColor: theme.tokenColors.plain.nsColor,
            .paragraphStyle: style
        ]

        selectedTextAttributes = [
            .backgroundColor: theme.palette.selection.nsColor.withAlphaComponent(0.3),
            .foregroundColor: theme.tokenColors.plain.nsColor,
            .paragraphStyle: style
        ]

        if let textStorage = textStorage {
            let fullRange = NSRange(location: 0, length: textStorage.length)
            textStorage.addAttribute(.paragraphStyle, value: style, range: fullRange)
        }

    }

    override func scrollRangeToVisible(_ charRange: NSRange) {
        let length = (string as NSString).length
        let clamped = makeSafeRange(charRange, documentLength: max(length, 0))
        guard sqlRangeIsValid(clamped, upperBound: max(length, 0)) || (length == 0 && clamped.location == 0) else { return }
        super.scrollRangeToVisible(clamped)
    }

    override func setSelectedRange(_ charRange: NSRange) {
        let length = (string as NSString).length
        let clamped = makeSafeRange(charRange, documentLength: length)
        if sqlRangeIsValid(clamped, upperBound: max(length, 0)) || (length == 0 && clamped.location == 0) {
            super.setSelectedRange(clamped)
        }
    }

    private func paragraphStyle(for theme: SQLEditorTheme, display: SQLEditorDisplayOptions) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        let baseline: CGFloat
        if let layout = layoutManager {
            baseline = layout.defaultLineHeight(for: theme.nsFont)
        } else {
            baseline = theme.nsFont.ascender - theme.nsFont.descender + theme.nsFont.leading
        }
        let lineHeight = baseline * theme.lineHeightMultiplier
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
        style.lineBreakMode = display.wrapLines ? .byWordWrapping : .byClipping
        style.tabStops = []
        style.defaultTabInterval = theme.nsFont.pointSize * 1.6
        style.paragraphSpacing = 4
        let indentSpaces = display.wrapLines ? display.indentWrappedLines : 0
        style.headIndent = indentWidth(for: indentSpaces)
        style.firstLineHeadIndent = 0
        return style
    }

    private func indentWidth(for spaces: Int) -> CGFloat {
        guard spaces > 0 else { return 0 }
        let sample = String(repeating: " ", count: max(1, spaces))
        let size = (sample as NSString).size(withAttributes: [.font: theme.nsFont])
        return size.width
    }

    private func makeSafeRange(_ range: NSRange, documentLength length: Int) -> NSRange {
        guard length > 0 else { return NSRange(location: 0, length: 0) }

        if range.length == 0 {
            let location = min(max(range.location, 0), length)
            return NSRange(location: location, length: 0)
        }

        let location = min(max(range.location, 0), max(length - 1, 0))
        let available = max(0, length - location)
        let safeLength = min(max(range.length, 0), available)
        return NSRange(location: location, length: safeLength)
    }

    private func clampSelectionRange(_ range: NSRange) -> NSRange {
        let length = (string as NSString).length
        return makeSafeRange(range, documentLength: length)
    }

    private func clampRangeForScrolling(_ range: NSRange) -> NSRange {
        let length = (string as NSString).length
        if length == 0 { return NSRange(location: 0, length: 0) }
        return makeSafeRange(range, documentLength: length)
    }
}

struct AutoCompletionListView: View {
    let suggestions: [SQLAutoCompletionSuggestion]
    let selectedID: String?
    let onSelect: (SQLAutoCompletionSuggestion) -> Void
    let detailResetID: UUID

    @Environment(\.colorScheme) private var colorScheme

    @State private var isDetailVisible = false
    @State private var detailWorkItem: DispatchWorkItem?
    @State private var detailUnlocked = false

    private enum Layout {
        static let rowCornerRadius: CGFloat = 12
        static let detailWidth: CGFloat = 240
        static let containerCornerRadius: CGFloat = 18
        static let horizontalPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 10
        static let containerSpacing: CGFloat = 12
        static let detailRevealDelay: TimeInterval = 1.0
    }

    private var selectedSuggestion: SQLAutoCompletionSuggestion? {
        guard let selectedID else { return nil }
        return suggestions.first { $0.id == selectedID }
    }

    private var shouldDisplayDetail: Bool {
        guard let suggestion = selectedSuggestion, isDetailVisible else { return false }
        if let path = suggestion.displayObjectPath, !path.isEmpty { return true }
        if suggestion.kind == .column, let type = suggestion.dataType, !type.isEmpty { return true }
        if suggestion.serverDisplayName != nil { return true }
        return false
    }

    var body: some View {
        content
            .id(detailResetID)
    }

    private var content: some View {
        HStack(alignment: .top, spacing: Layout.containerSpacing) {
            listView

            if shouldDisplayDetail, let suggestion = selectedSuggestion {
                AutoCompletionDetailView(suggestion: suggestion)
                    .frame(width: Layout.detailWidth, alignment: .leading)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .id(suggestion.id)
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
        .background(backgroundMaterial)
        .overlay(borderOverlay)
        .onAppear { scheduleDetailReveal(forceReset: true) }
        .onChange(of: selectedID) { _ in scheduleDetailReveal(forceReset: false) }
        .onChange(of: suggestions) { _ in scheduleDetailReveal(forceReset: false) }
        .onDisappear { cancelDetailReveal() }
    }

    @ViewBuilder
    private var backgroundMaterial: some View {
#if os(macOS)
        Color.clear
#else
        RoundedRectangle(cornerRadius: Layout.containerCornerRadius, style: .continuous)
            .fill(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.95))
#endif
    }

#if os(macOS)
    private var containerMaterial: NSVisualEffectView.Material { .contentBackground }
#endif

    private var borderColor: Color {
#if os(macOS)
        return Color.clear
#else
        return Color.black.opacity(0.1)
#endif
    }

    @ViewBuilder
    private var borderOverlay: some View {
#if os(macOS)
        EmptyView()
#else
        RoundedRectangle(cornerRadius: Layout.containerCornerRadius, style: .continuous)
            .stroke(borderColor, lineWidth: 1)
#endif
    }

    private var listView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(suggestions) { suggestion in
                        suggestionRow(for: suggestion)
                            .id(suggestion.id)
                    }
                }
            }
            .frame(minWidth: 170)
            .onAppear { scrollToSelection(proxy) }
            .onChange(of: selectedID) { _ in scrollToSelection(proxy) }
        }
    }

    private func scrollToSelection(_ proxy: ScrollViewProxy) {
        guard let selectedID else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(selectedID, anchor: .center)
        }
    }

    @ViewBuilder
    private func suggestionRow(for suggestion: SQLAutoCompletionSuggestion) -> some View {
        let isSelected = suggestion.id == selectedID

        Button {
            onSelect(suggestion)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: suggestion.kind.iconSystemName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(iconColor(isSelected: isSelected))
                    .frame(width: 16)

                Text(suggestion.title)
                    .font(.system(size: 12))
                    .foregroundStyle(titleColor(isSelected: isSelected))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(rowBackground(isSelected: isSelected))
    }

    private func iconColor(isSelected: Bool) -> Color {
#if os(macOS)
        return isSelected ? Color(nsColor: .selectedMenuItemTextColor) : Color.secondary
#else
        return isSelected ? Color.white : Color.secondary
#endif
    }

    private func titleColor(isSelected: Bool) -> Color {
#if os(macOS)
        return isSelected ? Color(nsColor: .selectedMenuItemTextColor) : Color.primary
#else
        return isSelected ? Color.white : Color.primary
#endif
    }

    private func rowBackground(isSelected: Bool) -> some View {
        guard isSelected else {
            return RoundedRectangle(cornerRadius: Layout.rowCornerRadius, style: .continuous)
                .fill(Color.clear)
        }
#if os(macOS)
        let accent = NSColor.controlAccentColor
        return RoundedRectangle(cornerRadius: Layout.rowCornerRadius, style: .continuous)
            .fill(Color(nsColor: accent))
#else
        let opacity = colorScheme == .dark ? 0.32 : 0.22
        return RoundedRectangle(cornerRadius: Layout.rowCornerRadius, style: .continuous)
            .fill(Color.accentColor.opacity(opacity))
#endif
    }

    private func scheduleDetailReveal(forceReset: Bool) {
        detailWorkItem?.cancel()
        detailWorkItem = nil
        if forceReset {
            detailUnlocked = false
            if isDetailVisible {
                withAnimation(.easeOut(duration: 0.12)) {
                    isDetailVisible = false
                }
            } else {
                isDetailVisible = false
            }
        } else if detailUnlocked {
            isDetailVisible = selectedSuggestion != nil
            return
        }
        guard !detailUnlocked, selectedSuggestion != nil else { return }
        let workItem = DispatchWorkItem {
            detailUnlocked = true
            withAnimation(.easeOut(duration: 0.2)) {
                isDetailVisible = true
            }
        }
        detailWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Layout.detailRevealDelay, execute: workItem)
    }

    private func cancelDetailReveal() {
        detailWorkItem?.cancel()
        detailWorkItem = nil
        isDetailVisible = false
        detailUnlocked = false
    }
}

struct AutoCompletionDetailView: View {
    let suggestion: SQLAutoCompletionSuggestion

    private enum Layout {
        static let cornerRadius: CGFloat = 14
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            contentBody
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(detailBackground)
        .overlay(detailOverlay)
    }

    @ViewBuilder
    private var contentBody: some View {
        if suggestion.kind == .column {
            if let dataType = suggestion.dataType, !dataType.isEmpty {
                Text(dataType)
                    .font(.system(size: 11))
                    .italic()
                    .foregroundStyle(Color.secondary)
            }
        } else if let objectPath = suggestion.displayObjectPath {
            Text(objectPath)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.primary)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(suggestion.displayKindTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.primary)

            if suggestion.kind == .column, let table = tableBadgeText {
                badge(text: table, systemImage: "tablecells")
            } else if let server = suggestion.serverDisplayName {
                badge(text: server, systemImage: "server.rack")
            }

            Spacer(minLength: 0)
        }
    }

    private func badge(text: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Color.primary)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(serverBadgeBackground)
    }

    private var tableBadgeText: String? {
        guard let origin = suggestion.origin else { return nil }
        return origin.object?.isEmpty == false ? origin.object : nil
    }

    @ViewBuilder
    private var serverBadgeBackground: some View {
#if os(macOS)
        GlassBackground(material: .menu, blendingMode: .withinWindow, emphasized: true)
            .clipShape(Capsule(style: .continuous))
#else
        Capsule(style: .continuous)
            .fill(Color.white.opacity(0.85))
#endif
    }

#if os(macOS)
    private var detailBackground: some View { Color.clear }

    private var detailOverlay: some View { EmptyView() }
#else
    private var detailBackground: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.95))
    }

    private var detailOverlay: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            .stroke(Color.black.opacity(0.08), lineWidth: 1)
    }
#endif
}

#if os(macOS)
private struct GlassBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var emphasized: Bool = false

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = emphasized
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.isEmphasized = emphasized
        nsView.state = .active
    }
}
#endif

private final class SQLAutoCompletionController {
    weak var textView: SQLTextView?

    private let popover: NSPopover
    private var hostingController: NSHostingController<AutoCompletionListView>?
    private var flatSuggestions: [SQLAutoCompletionSuggestion] = []
    private var selectedIndex: Int = 0
    private var lastQuery: SQLAutoCompletionQuery?
    private var detailResetToken = UUID()

    private let minWidth: CGFloat = 200
    private let maxWidth: CGFloat = 420
    private let maxHeight: CGFloat = 260

    init(textView: SQLTextView) {
        self.textView = textView
        self.popover = NSPopover()
        popover.behavior = .semitransient
        popover.animates = false
        popover.appearance = textView.effectiveAppearance
    }

    deinit {
        popover.performClose(nil)
    }

    private var isVisible: Bool { popover.isShown && !flatSuggestions.isEmpty }

    var isPresenting: Bool { isVisible }

    func present(suggestions: [SQLAutoCompletionSuggestion], query: SQLAutoCompletionQuery) {
        guard let textView else {
            hide()
            return
        }

        let appearance = textView.window?.effectiveAppearance ?? textView.effectiveAppearance
        popover.appearance = appearance
        hostingController?.view.appearance = appearance

        let previousID = selectedSuggestion?.id
        flatSuggestions = suggestions
        guard !flatSuggestions.isEmpty else {
            hide()
            return
        }

        lastQuery = query

        if let previousID, let index = flatSuggestions.firstIndex(where: { $0.id == previousID }) {
            selectedIndex = index
        } else {
            selectedIndex = 0
        }

        let shouldResetDetail = !popover.isShown
        if shouldResetDetail {
            detailResetToken = UUID()
        }

        updateContent()

        guard let caretRect = caretRect(for: query) else {
            hide()
            return
        }

        popover.show(relativeTo: caretRect, of: textView, preferredEdge: .maxY)
    }

    func hide() {
        flatSuggestions.removeAll(keepingCapacity: false)
        lastQuery = nil
        selectedIndex = 0
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard isVisible else { return false }

        switch event.keyCode {
        case 125: // down arrow
            moveSelection(1)
            return true
        case 126: // up arrow
            moveSelection(-1)
            return true
        case 121: // page down
            pageSelection(1)
            return true
        case 116: // page up
            pageSelection(-1)
            return true
        case 53: // escape
            hide()
            return true
        case 36, 76: // return, enter
            acceptCurrentSuggestion()
            return true
        default:
            break
        }

        if event.charactersIgnoringModifiers == "\t" {
            if event.modifierFlags.contains(.shift) {
                moveSelection(-1)
            } else {
                acceptCurrentSuggestion()
            }
            return true
        }

        return false
    }

    private func acceptCurrentSuggestion() {
        guard let suggestion = selectedSuggestion else {
            hide()
            return
        }
        accept(suggestion)
    }

    private func ensureHostingController() -> NSHostingController<AutoCompletionListView> {
        if let hostingController { return hostingController }
        let controller = NSHostingController(
            rootView: AutoCompletionListView(
                suggestions: [],
                selectedID: nil,
                onSelect: { _ in },
                detailResetID: detailResetToken
            )
        )
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        popover.contentViewController = controller
        hostingController = controller
        return controller
    }

    private func updateContent() {
        let controller = ensureHostingController()
        controller.rootView = AutoCompletionListView(
            suggestions: flatSuggestions,
            selectedID: selectedSuggestion?.id,
            onSelect: { [weak self] suggestion in
                self?.accept(suggestion)
            },
            detailResetID: detailResetToken
        )

        controller.view.layoutSubtreeIfNeeded()
        var fittingSize = controller.view.fittingSize
        fittingSize.width = ceil(fittingSize.width)
        fittingSize.height = ceil(fittingSize.height)
        let width = min(maxWidth, max(minWidth, fittingSize.width))
        let height = min(maxHeight, max(72, fittingSize.height))
        popover.contentSize = NSSize(width: width, height: height)
    }

    private func moveSelection(_ delta: Int) {
        guard !flatSuggestions.isEmpty else { return }
        let count = flatSuggestions.count
        let newIndex = (selectedIndex + delta) % count
        selectedIndex = newIndex >= 0 ? newIndex : newIndex + count
        updateContent()
    }

    private func pageSelection(_ direction: Int) {
        guard !flatSuggestions.isEmpty else { return }
        let pageSize = 8
        moveSelection(direction > 0 ? pageSize : -pageSize)
    }

    private func accept(_ suggestion: SQLAutoCompletionSuggestion) {
        guard let textView else { return }
        let query = lastQuery ?? textView.currentCompletionQuery()
        guard let query else { hide(); return }
        textView.applyCompletion(suggestion, query: query)
    }

    private var selectedSuggestion: SQLAutoCompletionSuggestion? {
        guard selectedIndex >= 0, selectedIndex < flatSuggestions.count else { return nil }
        return flatSuggestions[selectedIndex]
    }

    private func caretRect(for query: SQLAutoCompletionQuery) -> NSRect? {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return nil }

        var queryRange = query.replacementRange
        if queryRange.length == 0 && queryRange.location > 0 {
            queryRange = NSRange(location: max(queryRange.location - 1, 0), length: 1)
        }

        var glyphRange = layoutManager.glyphRange(forCharacterRange: queryRange, actualCharacterRange: nil)
        if glyphRange.length == 0 && glyphRange.location > 0 {
            glyphRange = NSRange(location: max(glyphRange.location - 1, 0), length: 1)
        }

        var caretRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        caretRect.origin.x += textView.textContainerInset.width
        caretRect.origin.y += textView.textContainerInset.height
        caretRect.origin.y += caretRect.height
        caretRect.origin.y += 4

        caretRect.size.width = max(caretRect.width, 2)
        caretRect.size.height = max(caretRect.height, 18)
        return caretRect
    }
}

private final class LineNumberRulerView: NSRulerView {
    weak var sqlTextView: SQLTextView?
    var highlightedLines: IndexSet = []
    var theme: SQLEditorTheme {
        didSet { needsDisplay = true }
    }

    private let paragraphStyle: NSMutableParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        return style
    }()

    init(textView: SQLTextView, theme: SQLEditorTheme) {
        self.theme = theme
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.sqlTextView = textView
        self.clientView = textView
        self.ruleThickness = 40
        translatesAutoresizingMaskIntoConstraints = true
        autoresizingMask = [.height]
        setFrameSize(NSSize(width: ruleThickness, height: frame.size.height))
        setBoundsSize(NSSize(width: ruleThickness, height: bounds.size.height))

        // Observe text changes to update line numbers live
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: textView
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func textDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    // Keep the ruler from stretching over the text view when AppKit resizes it.
    override func setFrameSize(_ newSize: NSSize) {
        let width = ruleThickness > 0 ? ruleThickness : newSize.width
        super.setFrameSize(NSSize(width: width, height: newSize.height))
    }

    override func setBoundsSize(_ newSize: NSSize) {
        let width = ruleThickness > 0 ? ruleThickness : newSize.width
        super.setBoundsSize(NSSize(width: width, height: newSize.height))
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        drawHashMarksAndLabels(in: dirtyRect)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        let gutterWidth = max(0, ruleThickness)
        let gutterRect = NSRect(x: 0, y: rect.minY, width: gutterWidth, height: rect.height)

        // No background fill - transparent line numbers

        guard let textView = sqlTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: theme.palette.gutterText.nsColor,
            .paragraphStyle: paragraphStyle
        ]

        let glyphCount = layoutManager.numberOfGlyphs
        let nsString = textView.string as NSString

        if glyphCount == 0 || nsString.length == 0 {
            drawFallbackLine(with: attributes, in: gutterRect)
            return
        }

        layoutManager.ensureLayout(for: textContainer)

        var visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: textContainer)
        if visibleGlyphRange.location == NSNotFound {
            visibleGlyphRange = NSRange(location: 0, length: glyphCount)
        }

        let initialGlyph = min(visibleGlyphRange.location, max(glyphCount - 1, 0))
        let maxGlyphIndex = min(NSMaxRange(visibleGlyphRange), glyphCount)
        if maxGlyphIndex <= initialGlyph {
            drawFallbackLine(with: attributes, in: gutterRect)
            return
        }

        var glyphIndex = initialGlyph
        while glyphIndex < maxGlyphIndex {
            var lineRange = NSRange(location: 0, length: 0)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange, withoutAdditionalLayout: true)
            let yPosition = lineRect.minY + textView.textContainerInset.height - textView.visibleRect.origin.y

            let lineNumber = nsString.lineNumber(at: lineRange.location)
            let labelRect = NSRect(x: 0, y: yPosition + 2, width: gutterRect.width - 8, height: lineRect.height)
            ("\(lineNumber)" as NSString).draw(in: labelRect, withAttributes: attributes)

            glyphIndex = min(NSMaxRange(lineRange), maxGlyphIndex)
        }

        // No divider – match Tahoe preview
    }

    private func drawFallbackLine(with attributes: [NSAttributedString.Key: Any], in rect: NSRect) {
        let labelRect = NSRect(x: 0, y: rect.minY + 4, width: rect.width - 8, height: rect.height)
        ("1" as NSString).draw(in: labelRect, withAttributes: attributes)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard point.x <= ruleThickness else { return nil }
        return super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) { selectLine(event) }
    override func mouseDragged(with event: NSEvent) { selectLine(event) }

    private func selectLine(_ event: NSEvent) {
        guard let textView = sqlTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let glyphCount = layoutManager.numberOfGlyphs
        guard glyphCount > 0 else { return }

        let location = convert(event.locationInWindow, from: nil)
        let pointInTextView = convert(location, to: textView)
        var fraction: CGFloat = 0
        var glyphIndex = layoutManager.glyphIndex(for: pointInTextView, in: textContainer, fractionOfDistanceThroughGlyph: &fraction)
        glyphIndex = min(max(glyphIndex, 0), glyphCount - 1)
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let line = (textView.string as NSString).lineNumber(at: charIndex)
        textView.selectLineRange(line...line)
    }
}

private extension SQLTextView {
    func selectLineRange(_ range: ClosedRange<Int>) {
        let nsString = string as NSString
        let startLocation = nsString.locationOfLine(range.lowerBound)
        let endLocation = nsString.endLocationOfLine(range.upperBound)
        let selectionRange = NSRange(location: startLocation, length: endLocation - startLocation)
        setSelectedRange(selectionRange)
        scrollRangeToVisible(selectionRange)
    }
}

private extension NSString {
    func lineNumber(at index: Int) -> Int {
        guard length > 0 else { return 1 }
        let clamped = max(0, min(index, length))
        var line = 1
        var position = 0

        while position < clamped {
            let currentChar = character(at: position)
            if currentChar == 10 { // \n
                line += 1
            } else if currentChar == 13 { // \r
                line += 1
                if position + 1 < clamped && character(at: position + 1) == 10 {
                    position += 1
                }
            }
            position += 1
        }

        if clamped < length {
            let trailingCharacter = character(at: clamped)
            if trailingCharacter == 10 || trailingCharacter == 13 {
                line += 1
            }
        }

        return line
    }

    func locationOfLine(_ number: Int) -> Int {
        guard number > 1 else { return 0 }
        var current = 1
        var location = 0
        enumerateSubstrings(in: NSRange(location: 0, length: length), options: [.byLines, .substringNotRequired]) { _, substringRange, _, stop in
            if current == number {
                location = substringRange.location
                stop.pointee = true
            }
            current += 1
        }
        return location
    }

    func endLocationOfLine(_ number: Int) -> Int {
        guard number > 0 else { return 0 }
        var current = 1
        var location = length
        enumerateSubstrings(in: NSRange(location: 0, length: length), options: [.byLines, .substringNotRequired]) { _, substringRange, _, stop in
            if current == number {
                location = NSMaxRange(substringRange)
                stop.pointee = true
            }
            current += 1
        }
        return location
    }
}

#else
// Simplified iOS/iPadOS implementation using UITextView
private struct IOSSQLEditorRepresentable: UIViewRepresentable {
    @Binding var text: String
    var theme: SQLEditorTheme
    var display: SQLEditorDisplayOptions
    var backgroundColor: Color?
    var onTextChange: (String) -> Void
    var onSelectionChange: (SQLEditorSelection) -> Void
    var onSelectionPreviewChange: (SQLEditorSelection) -> Void
    var clipboardHistory: ClipboardHistoryStore
    var clipboardMetadata: ClipboardHistoryStore.Entry.Metadata
    var onAddBookmark: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = theme.uiFont
        textView.textColor = theme.tokenColors.plain.uiColor
        textView.backgroundColor = (backgroundColor.map(UIColor.init)) ?? theme.palette.background.uiColor
        textView.tintColor = theme.tokenColors.operatorSymbol.uiColor
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.delegate = context.coordinator
        textView.text = text
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        textView.textContainer.widthTracksTextView = display.wrapLines
        textView.textContainer.lineFragmentPadding = 12
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.font = theme.uiFont
        uiView.textColor = theme.tokenColors.plain.uiColor
        uiView.backgroundColor = (backgroundColor.map(UIColor.init)) ?? theme.palette.background.uiColor
        uiView.tintColor = theme.tokenColors.operatorSymbol.uiColor
        uiView.textContainer.widthTracksTextView = display.wrapLines
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: IOSSQLEditorRepresentable

        init(parent: IOSSQLEditorRepresentable) {
            self.parent = parent
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            let selection = textView.selectedRange
            let selected = (selection.length > 0) ? (textView.text as NSString).substring(with: selection) : ""
            let lineRange: ClosedRange<Int>? = nil
            let selectionInfo = SQLEditorSelection(selectedText: selected, range: selection, lineRange: lineRange)
            parent.onSelectionPreviewChange(selectionInfo)
            parent.onSelectionChange(selectionInfo)
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.onTextChange(textView.text)
            textViewDidChangeSelection(textView)
        }
    }
}
#endif
