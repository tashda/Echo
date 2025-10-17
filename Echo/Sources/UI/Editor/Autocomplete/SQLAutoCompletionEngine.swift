import Foundation

final class SQLAutoCompletionEngine {
    private let completionEngine: SQLCompletionEngineProtocol
    private struct SQLStructureMetadataProvider: SQLMetadataProvider {
        let catalogsByDatabase: [String: SQLDatabaseCatalog]
        let defaultCatalog: SQLDatabaseCatalog

        func catalog(for database: String?) -> SQLDatabaseCatalog? {
            if let database,
               let catalog = catalogsByDatabase[database.lowercased()] {
                return catalog
            }
            return defaultCatalog
        }

        static var empty: SQLStructureMetadataProvider {
            SQLStructureMetadataProvider(catalogsByDatabase: [:],
                                         defaultCatalog: SQLDatabaseCatalog(schemas: []))
        }
    }

    private final class CachingSuggestionBuilderFactory: SQLSuggestionBuilderFactory {
        private var cache: [SQLDialect: SQLSuggestionBuilder] = [:]

        func makeBuilder(for dialect: SQLDialect) -> SQLSuggestionBuilder {
            if let existing = cache[dialect] {
                return existing
            }
            let builder = DefaultSuggestionBuilder(dialect: dialect)
            cache[dialect] = builder
            return builder
        }
    }

    init(completionEngine: SQLCompletionEngineProtocol = SQLCompletionEngine(builderFactory: CachingSuggestionBuilderFactory())) {
        self.completionEngine = completionEngine
    }

    private struct ObjectEntry {
        let database: String
        let schema: String
        let object: SchemaObjectInfo
    }

    private struct Catalog {
        struct ObjectKey: Hashable {
            let database: String
            let schema: String
            let name: String
        }

        let objectsByKey: [ObjectKey: [ObjectEntry]]
        let metadataProvider: SQLStructureMetadataProvider

        init(context: SQLEditorCompletionContext, builtInFunctions: [String]) {
            guard let structure = context.structure else {
                let builtIns = Catalog.builtInSchema(functions: builtInFunctions)
                let defaultCatalog = builtIns.objects.isEmpty ? SQLDatabaseCatalog(schemas: []) : SQLDatabaseCatalog(schemas: [builtIns])
                self.objectsByKey = [:]
                self.metadataProvider = SQLStructureMetadataProvider(catalogsByDatabase: [:],
                                                                     defaultCatalog: defaultCatalog)
                return
            }

            var objectsIndex: [ObjectKey: [ObjectEntry]] = [:]
            var catalogsByDatabase: [String: SQLDatabaseCatalog] = [:]

            for database in structure.databases {
                let databaseLower = database.name.lowercased()
                var schemasForDatabase: [SQLSchema] = []

                for schema in database.schemas {
                    let schemaName = schema.name
                    let schemaLower = schemaName.lowercased()
                    var sqlObjects: [SQLObject] = []

                    for object in schema.objects {
                        guard let sqlObject = Catalog.sqlObject(from: object) else { continue }
                        sqlObjects.append(sqlObject)

                        let key = ObjectKey(database: databaseLower,
                                            schema: schemaLower,
                                            name: object.name.lowercased())
                        let entry = ObjectEntry(database: database.name,
                                                schema: schemaName,
                                                object: object)
                        objectsIndex[key, default: []].append(entry)
                    }

                    schemasForDatabase.append(SQLSchema(name: schemaName, objects: sqlObjects))
                }

                if !builtInFunctions.isEmpty {
                    schemasForDatabase.append(Catalog.builtInSchema(functions: builtInFunctions))
                }

                catalogsByDatabase[databaseLower] = SQLDatabaseCatalog(schemas: schemasForDatabase)
            }

            let defaultCatalog: SQLDatabaseCatalog
            if let selected = context.selectedDatabase?.lowercased(),
               let selectedCatalog = catalogsByDatabase[selected] {
                defaultCatalog = selectedCatalog
            } else if let first = catalogsByDatabase.values.first {
                defaultCatalog = first
            } else {
                let builtIns = Catalog.builtInSchema(functions: builtInFunctions)
                defaultCatalog = builtIns.objects.isEmpty ? SQLDatabaseCatalog(schemas: []) : SQLDatabaseCatalog(schemas: [builtIns])
            }

            self.objectsByKey = objectsIndex
            self.metadataProvider = SQLStructureMetadataProvider(catalogsByDatabase: catalogsByDatabase,
                                                                 defaultCatalog: defaultCatalog)
        }

        func object(database: String?, schema: String, name: String) -> ObjectEntry? {
            let schemaLower = schema.lowercased()
            let nameLower = name.lowercased()

            if let database {
                let key = ObjectKey(database: database.lowercased(),
                                    schema: schemaLower,
                                    name: nameLower)
                if let entries = objectsByKey[key], !entries.isEmpty {
                    return entries.first
                }
            }

            let matches: [ObjectEntry] = objectsByKey
                .filter { key, _ in key.schema == schemaLower && key.name == nameLower }
                .flatMap { $0.value }

            guard !matches.isEmpty else { return nil }

            if let database {
                let lowered = database.lowercased()
                if let match = matches.first(where: { $0.database.lowercased() == lowered }) {
                    return match
                }
            }

            return matches.first
        }

        func objects(named name: String) -> [ObjectEntry] {
            let lower = name.lowercased()
            return objectsByKey.compactMap { key, entries in
                key.name == lower ? entries : nil
            }.flatMap { $0 }
        }

        private static func sqlObject(from object: SchemaObjectInfo) -> SQLObject? {
            let type: SQLObject.ObjectType
            switch object.type {
            case .table:
                type = .table
            case .view:
                type = .view
            case .materializedView:
                type = .materializedView
            case .function:
                type = .function
            case .trigger:
                return nil
            }

            let columns = object.columns.map {
                SQLColumn(name: $0.name,
                          dataType: $0.dataType,
                          isPrimaryKey: $0.isPrimaryKey,
                          isForeignKey: $0.foreignKey != nil,
                          isNullable: $0.isNullable)
            }
            let foreignKeys = Catalog.foreignKeys(from: object.columns)

            return SQLObject(name: object.name,
                             type: type,
                             columns: columns,
                             foreignKeys: foreignKeys)
        }

        private static func foreignKeys(from columns: [ColumnInfo]) -> [SQLForeignKey] {
            var grouped: [String: (columns: [String], schema: String?, table: String, referenced: [String])] = [:]

            for column in columns {
                guard let fk = column.foreignKey else { continue }
                var entry = grouped[fk.constraintName] ?? ([], fk.referencedSchema, fk.referencedTable, [])
                entry.columns.append(column.name)
                entry.referenced.append(fk.referencedColumn)
                entry.schema = fk.referencedSchema
                entry.table = fk.referencedTable
                grouped[fk.constraintName] = entry
            }

            return grouped.map { name, payload in
                SQLForeignKey(name: name,
                              columns: payload.columns,
                              referencedSchema: payload.schema,
                              referencedTable: payload.table,
                              referencedColumns: payload.referenced)
            }
        }

        private static func builtInSchema(functions: [String]) -> SQLSchema {
            let objects = functions.map { functionName in
                SQLObject(name: functionName,
                          type: .function,
                          columns: [],
                          foreignKeys: [])
            }
            return SQLSchema(name: "Built-in", objects: objects)
        }
    }

    private var context: SQLEditorCompletionContext?
    private var catalog: Catalog?
    private var builtInFunctions: [String] = []
    private var useTableAliasShortcuts = false
    private let historyStore = SQLAutoCompletionHistoryStore.shared
    private(set) var isMetadataLimited: Bool = false
    private var metadataProvider: SQLStructureMetadataProvider = .empty
    private var suppressEmptyTokenCompletions = false
    private var includeHistorySuggestions = true
    private var preferQualifiedTableInsertions = false
    private static let emptyMetadata = SQLCompletionMetadata(clause: .unknown,
                                                             currentToken: "",
                                                             precedingKeyword: nil,
                                                             pathComponents: [],
                                                             tablesInScope: [],
                                                             focusTable: nil,
                                                             cteColumns: [:])

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
            builtInFunctions = SQLAutoCompletionEngine.builtInFunctions(for: newContext.databaseType)
            let newCatalog = Catalog(context: newContext, builtInFunctions: builtInFunctions)
            catalog = newCatalog
            metadataProvider = newCatalog.metadataProvider
            isMetadataLimited = newContext.structure == nil
        } else {
            catalog = nil
            builtInFunctions = []
            metadataProvider = .empty
            isMetadataLimited = false
        }
    }

    func updateAliasPreference(useTableAliases: Bool) {
        useTableAliasShortcuts = useTableAliases
    }

    func updateHistoryPreference(includeHistory: Bool) {
        includeHistorySuggestions = includeHistory
    }

    func updateQualifiedInsertionPreference(includeSchema: Bool) {
        preferQualifiedTableInsertions = includeSchema
    }

    func clearPostCommitSuppression() {
        suppressEmptyTokenCompletions = false
    }

    func recordSelection(_ suggestion: SQLAutoCompletionSuggestion, query: SQLAutoCompletionQuery) {
        historyStore.record(suggestion, context: context)
        suppressEmptyTokenCompletions = true
    }

    func suggestions(for query: SQLAutoCompletionQuery,
                     text: String,
                     caretLocation: Int) -> SQLAutoCompletionResult {
        guard let context else {
            return SQLAutoCompletionResult(sections: [],
                                           metadata: SQLAutoCompletionEngine.emptyMetadata)
        }

        let trimmedToken = query.token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedToken.isEmpty && query.pathComponents.isEmpty {
            if suppressEmptyTokenCompletions {
                return SQLAutoCompletionResult(sections: [],
                                               metadata: SQLAutoCompletionEngine.emptyMetadata)
            }
        } else {
            suppressEmptyTokenCompletions = false
        }

        guard shouldProvideCompletions(for: query) else {
            return SQLAutoCompletionResult(sections: [],
                                           metadata: SQLAutoCompletionEngine.emptyMetadata)
        }

        let options = SQLEngineOptions(enableAliasShortcuts: useTableAliasShortcuts,
                                       keywordCasing: .upper)

        let request = SQLCompletionRequest(text: text,
                                           caretLocation: caretLocation,
                                           dialect: context.databaseType.sqlDialect,
                                           selectedDatabase: context.selectedDatabase,
                                           defaultSchema: context.defaultSchema,
                                           metadata: metadataProvider,
                                           options: options)

        let result = completionEngine.completions(for: request)

        let mapped = mapSuggestions(result.suggestions,
                                    query: query,
                                    context: context)
        let combined = injectHistorySuggestions(base: mapped,
                                                query: query,
                                                context: context)

        let sections = [SQLAutoCompletionSection(title: "Suggestions", suggestions: combined)]
        return SQLAutoCompletionResult(sections: sections, metadata: result.metadata)
    }

    private func mapSuggestions(_ suggestions: [SQLCompletionSuggestion],
                                query: SQLAutoCompletionQuery,
                                context: SQLEditorCompletionContext) -> [SQLAutoCompletionSuggestion] {
        var results: [SQLAutoCompletionSuggestion] = []
        results.reserveCapacity(suggestions.count)

        for suggestion in suggestions {
            guard let mapped = mapSuggestion(suggestion,
                                             query: query,
                                             context: context) else { continue }
            results.append(mapped)
        }
        return results.filter { matchesQuery($0, query: query) }
    }

    private func mapSuggestion(_ suggestion: SQLCompletionSuggestion,
                               query: SQLAutoCompletionQuery,
                               context: SQLEditorCompletionContext) -> SQLAutoCompletionSuggestion? {
        guard let mappedKind = mapKind(suggestion.kind) else { return nil }

        var origin: SQLAutoCompletionSuggestion.Origin?
        var dataType: String?
        var tableColumns: [SQLAutoCompletionSuggestion.TableColumn]?

        switch suggestion.kind {
        case .table, .view, .materializedView:
            let schemaName = suggestion.subtitle ?? context.defaultSchema
            if let entry = lookupObject(schema: schemaName,
                                        name: suggestion.title,
                                        context: context) {
                origin = SQLAutoCompletionSuggestion.Origin(database: entry.database,
                                                            schema: entry.schema,
                                                            object: entry.object.name)
                tableColumns = self.tableColumns(from: entry.object)
            } else {
                origin = SQLAutoCompletionSuggestion.Origin(database: context.selectedDatabase,
                                                            schema: schemaName,
                                                            object: suggestion.title)
            }
        case .schema:
            origin = SQLAutoCompletionSuggestion.Origin(database: context.selectedDatabase,
                                                        schema: suggestion.title)
        case .column:
            let details = mapColumnSuggestion(suggestion, context: context)
            origin = details.origin
            dataType = details.dataType
        case .function, .procedure:
            origin = mapFunctionOrigin(suggestion, context: context)
        default:
            break
        }

        let insertText = makeInsertText(from: suggestion,
                                        mappedKind: mappedKind,
                                        query: query,
                                        origin: origin)

        let snippetText: String?
        if mappedKind == .snippet && !suggestion.id.hasPrefix("star|") {
            snippetText = suggestion.insertText
        } else {
            snippetText = nil
        }

        return SQLAutoCompletionSuggestion(id: suggestion.id,
                                           title: suggestion.title,
                                           subtitle: suggestion.subtitle,
                                           detail: suggestion.detail,
                                           insertText: insertText,
                                           kind: mappedKind,
                                           origin: origin,
                                           dataType: dataType,
                                           tableColumns: tableColumns,
                                           snippetText: snippetText)
    }

    private func mapKind(_ kind: SQLCompletionSuggestion.Kind) -> SQLAutoCompletionKind? {
        switch kind {
        case .schema: return .schema
        case .table: return .table
        case .view: return .view
        case .materializedView: return .materializedView
        case .column: return .column
        case .function, .procedure: return .function
        case .keyword: return .keyword
        case .snippet: return .snippet
        case .parameter: return .parameter
        case .join: return .join
        }
    }

    private func adjustedInsertText(original: String,
                                    for kind: SQLCompletionSuggestion.Kind,
                                    query: SQLAutoCompletionQuery) -> String {
        switch kind {
        case .table, .view, .materializedView, .column, .function, .procedure:
            break
        default:
            return original
        }

        guard !query.pathComponents.isEmpty else { return original }

        let originalComponents = original.split(separator: ".").map(String.init)
        var remaining = originalComponents
        let typedComponents = query.pathComponents.map { $0.lowercased() }

        var index = 0
        while index < min(typedComponents.count, remaining.count),
              remaining[index].lowercased() == typedComponents[index] {
            index += 1
        }

        if index > 0 {
            remaining = Array(remaining.dropFirst(index))
            if remaining.isEmpty, let last = originalComponents.last {
                return last
            }
            return remaining.joined(separator: ".")
        }

        return original
    }

    private func makeInsertText(from suggestion: SQLCompletionSuggestion,
                                mappedKind: SQLAutoCompletionKind,
                                query: SQLAutoCompletionQuery,
                                origin: SQLAutoCompletionSuggestion.Origin?) -> String {
        let adjusted = adjustedInsertText(original: suggestion.insertText,
                                          for: suggestion.kind,
                                          query: query)

        guard preferQualifiedTableInsertions,
              query.pathComponents.isEmpty,
              (mappedKind == .table || mappedKind == .view || mappedKind == .materializedView),
              let schema = origin?.schema?.trimmingCharacters(in: .whitespacesAndNewlines),
              !schema.isEmpty,
              !adjusted.contains(".") else {
            return adjusted
        }

        return qualifiedInsertText(schema: schema,
                                   object: adjusted)
    }

    private func qualifiedInsertText(schema: String,
                                     object: String) -> String {
        let trimmedSchema = schema.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSchema.isEmpty else { return object }

        if let delimiters = identifierDelimiters(for: object) {
            let quotedSchema = apply(delimiters: delimiters, to: trimmedSchema)
            return "\(quotedSchema).\(object)"
        }

        return "\(trimmedSchema).\(object)"
    }

    private func identifierDelimiters(for text: String) -> (start: Character, end: Character)? {
        guard let first = text.first,
              let last = text.last else { return nil }
        let pairs: [Character: Character] = [
            "\"": "\"",
            "`": "`",
            "[": "]"
        ]
        guard let expected = pairs[first], expected == last else { return nil }
        return (first, last)
    }

    private func apply(delimiters: (start: Character, end: Character),
                       to identifier: String) -> String {
        switch delimiters.start {
        case "[":
            return "[\(identifier)]"
        default:
            return "\(delimiters.start)\(identifier)\(delimiters.end)"
        }
    }

    private func matchesQuery(_ suggestion: SQLAutoCompletionSuggestion,
                              query: SQLAutoCompletionQuery) -> Bool {
        let tokenLower = query.token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let prefixLower = query.prefix.lowercased()
        let pathLower = query.pathComponents.map { $0.lowercased() }
        let insertLower = suggestion.insertText.lowercased()
        let recomposed = (pathLower + [insertLower]).joined(separator: ".")

        if !tokenLower.isEmpty && recomposed.hasPrefix(tokenLower) {
            return true
        }

        if !prefixLower.isEmpty && insertLower.hasPrefix(prefixLower) {
            return true
        }

        if tokenLower.isEmpty && prefixLower.isEmpty && !pathLower.isEmpty {
            let aliasMatch = query.tablesInScope.contains { focus in
                focus.alias?.lowercased() == pathLower.first
            }
            if aliasMatch {
                return true
            }

            if let origin = suggestion.origin {
                var originComponents: [String] = []
                if let schema = origin.schema?.lowercased() {
                    originComponents.append(schema)
                }
                if let object = origin.object?.lowercased() {
                    originComponents.append(object)
                }
                if pathLower.count == 1 {
                    return originComponents.first == pathLower.first
                }
                if pathLower.count <= originComponents.count {
                    for (lhs, rhs) in zip(pathLower, originComponents) where lhs != rhs {
                        return false
                    }
                    return true
                }
            }
            return false
        }

        if tokenLower.isEmpty && prefixLower.isEmpty && pathLower.isEmpty {
            return true
        }

        if !tokenLower.isEmpty {
            return suggestion.title.lowercased().hasPrefix(tokenLower)
        }

        return true
    }

    private func lookupObject(schema: String?,
                              name: String,
                              context: SQLEditorCompletionContext) -> ObjectEntry? {
        guard let catalog else { return nil }

        if let schema,
           let entry = catalog.object(database: context.selectedDatabase,
                                      schema: schema,
                                      name: name) {
            return entry
        }

        if let schema,
           let entry = catalog.object(database: nil,
                                      schema: schema,
                                      name: name) {
            return entry
        }

        let matches = catalog.objects(named: name)
        guard !matches.isEmpty else { return nil }

        if let schema,
           let match = matches.first(where: { $0.schema.caseInsensitiveCompare(schema) == .orderedSame }) {
            return match
        }

        if let selected = context.selectedDatabase?.lowercased(),
           let match = matches.first(where: { $0.database.lowercased() == selected }) {
            return match
        }

        return matches.first
    }

    private func tableColumns(from object: SchemaObjectInfo) -> [SQLAutoCompletionSuggestion.TableColumn]? {
        guard !object.columns.isEmpty else { return nil }
        return object.columns.map {
            SQLAutoCompletionSuggestion.TableColumn(name: $0.name,
                                                    dataType: $0.dataType,
                                                    isNullable: $0.isNullable,
                                                    isPrimaryKey: $0.isPrimaryKey)
        }
    }

    private func mapColumnSuggestion(_ suggestion: SQLCompletionSuggestion,
                                     context: SQLEditorCompletionContext) -> (origin: SQLAutoCompletionSuggestion.Origin?, dataType: String?) {
        guard let components = parseColumnIdentifier(from: suggestion.id) else {
            return (nil, nil)
        }

        if components.isCTE {
            let qualifier = components.table ?? ""
            let origin = SQLAutoCompletionSuggestion.Origin(database: context.selectedDatabase,
                                                            schema: nil,
                                                            object: qualifier,
                                                            column: components.column)
            return (origin, nil)
        }

        guard let tableName = components.table else {
            let origin = SQLAutoCompletionSuggestion.Origin(database: context.selectedDatabase,
                                                            schema: components.schema,
                                                            object: nil,
                                                            column: components.column)
            return (origin, nil)
        }

        if let entry = lookupObject(schema: components.schema,
                                    name: tableName,
                                    context: context) {
            let origin = SQLAutoCompletionSuggestion.Origin(database: entry.database,
                                                            schema: entry.schema,
                                                            object: entry.object.name,
                                                            column: components.column)
            if let columnInfo = entry.object.columns.first(where: { $0.name.caseInsensitiveCompare(components.column) == .orderedSame }) {
                return (origin, columnInfo.dataType)
            }
            return (origin, nil)
        }

        let origin = SQLAutoCompletionSuggestion.Origin(database: context.selectedDatabase,
                                                        schema: components.schema,
                                                        object: tableName,
                                                        column: components.column)
        return (origin, nil)
    }

    private func parseColumnIdentifier(from identifier: String) -> (schema: String?, table: String?, column: String, isCTE: Bool)? {
        let parts = identifier.split(separator: "|")
        guard let prefix = parts.first else { return nil }

        switch prefix {
        case "column":
            guard parts.count >= 4 else { return nil }
            let schema = parts[1].isEmpty ? nil : String(parts[1])
            let table = parts[2].isEmpty ? nil : String(parts[2])
            let column = String(parts[3])
            return (schema, table, column, false)
        case "cte":
            guard parts.count >= 3 else { return nil }
            let qualifier = String(parts[1])
            let column = String(parts[2])
            return (schema: nil, table: qualifier, column: column, isCTE: true)
        default:
            return nil
        }
    }

    private func mapFunctionOrigin(_ suggestion: SQLCompletionSuggestion,
                                   context: SQLEditorCompletionContext) -> SQLAutoCompletionSuggestion.Origin? {
        if let schemaName = suggestion.subtitle,
           let entry = lookupObject(schema: schemaName,
                                    name: suggestion.title,
                                    context: context) {
            return SQLAutoCompletionSuggestion.Origin(database: entry.database,
                                                      schema: entry.schema,
                                                      object: entry.object.name)
        }

        if suggestion.subtitle == "Built-in" {
            return SQLAutoCompletionSuggestion.Origin(database: nil,
                                                      schema: "Built-in",
                                                      object: suggestion.title)
        }

        return SQLAutoCompletionSuggestion.Origin(database: context.selectedDatabase,
                                                  schema: suggestion.subtitle,
                                                  object: suggestion.title)
    }

    private func injectHistorySuggestions(base: [SQLAutoCompletionSuggestion],
                                          query: SQLAutoCompletionQuery,
                                          context: SQLEditorCompletionContext) -> [SQLAutoCompletionSuggestion] {
        guard includeHistorySuggestions else { return base }
        let history = historyStore.suggestions(matching: query.normalizedPrefix,
                                               context: context,
                                               limit: 6)
            .filter { matchesQuery($0, query: query) }
        guard !history.isEmpty else { return base }

        var seen = Set(base.map { $0.id.lowercased() })
        var combined: [SQLAutoCompletionSuggestion] = []

        for suggestion in history {
            let key = suggestion.id.lowercased()
            if seen.insert(key).inserted {
                combined.append(suggestion)
            }
        }

        combined.append(contentsOf: base)
        combined.append(contentsOf: base)
        return combined
    }

    private func shouldProvideCompletions(for query: SQLAutoCompletionQuery) -> Bool {
        let trimmedToken = query.token.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedToken.isEmpty && query.pathComponents.isEmpty {
            if query.precedingCharacter == "*" {
                return false
            }
            if isObjectContext(query: query) {
                return true
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
        switch query.clause {
        case .from, .joinTarget, .insertColumns, .deleteWhere, .withCTE:
            return true
        default:
            break
        }
        guard let keyword = query.precedingKeyword else { return false }
        return SQLTextView.objectContextKeywords.contains(keyword)
    }

    private func isColumnContext(query: SQLAutoCompletionQuery) -> Bool {
        if query.precedingCharacter == "," { return true }
        if !query.pathComponents.isEmpty { return true }
        switch query.clause {
        case .selectList, .whereClause, .joinCondition, .groupBy, .orderBy, .having, .values, .updateSet:
            return true
        default:
            break
        }
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

}

private extension DatabaseType {
    var sqlDialect: SQLDialect {
        switch self {
        case .postgresql:
            return .postgresql
        case .mysql:
            return .mysql
        case .sqlite:
            return .sqlite
        case .microsoftSQL:
            return .microsoftSQL
        }
    }
}
