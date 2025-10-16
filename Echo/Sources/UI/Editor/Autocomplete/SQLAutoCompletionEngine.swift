import Foundation

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
            let tableColumns: [SQLAutoCompletionSuggestion.TableColumn]? = {
                guard kind == .table || kind == .view || kind == .materializedView else { return nil }
                let mapped = entry.object.columns.map {
                    SQLAutoCompletionSuggestion.TableColumn(
                        name: $0.name,
                        dataType: $0.dataType,
                        isNullable: $0.isNullable,
                        isPrimaryKey: $0.isPrimaryKey
                    )
                }
                return mapped.isEmpty ? nil : mapped
            }()
            return SQLAutoCompletionSuggestion(
                id: "object:\(kind.rawValue):\(entry.database).\(entry.schema).\(entry.object.name)".lowercased(),
                title: entry.object.name,
                subtitle: subtitle,
                detail: enrichedDetail,
                insertText: insertText,
                kind: kind,
                origin: .init(database: entry.database, schema: entry.schema, object: entry.object.name),
                tableColumns: tableColumns
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
            guard let rawCandidate = components.last else {
                return (context.selectedDatabase?.lowercased(), nil, nil)
            }
            let candidate = rawCandidate.lowercased()
            if let resolved = resolveTable(for: candidate, in: query.tablesInScope) {
                return (
                    context.selectedDatabase?.lowercased(),
                    resolved.schema?.lowercased(),
                    resolved.name.lowercased()
                )
            }
            let matchesSchema = query.tablesInScope.contains { table in
                table.schema?.lowercased() == candidate
            }
            return (context.selectedDatabase?.lowercased(), matchesSchema ? candidate : nil, nil)
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

    private func resolveTable(for qualifier: String, in scope: [SQLAutoCompletionTableFocus]) -> SQLAutoCompletionTableFocus? {
        let lowered = qualifier.lowercased()
        if let aliasMatch = scope.first(where: { $0.alias?.lowercased() == lowered }) {
            return aliasMatch
        }
        if let nameMatch = scope.first(where: { $0.name.lowercased() == lowered }) {
            return nameMatch
        }
        return nil
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
