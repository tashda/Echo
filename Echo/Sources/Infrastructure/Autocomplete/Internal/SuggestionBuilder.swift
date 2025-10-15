import Foundation

protocol SQLSuggestionBuilderFactory {
    func makeBuilder(for dialect: SQLDialect) -> SQLSuggestionBuilder
}

protocol SQLSuggestionBuilder {
    func buildSuggestions(context: SQLContext,
                          request: SQLCompletionRequest,
                          catalog: SQLDatabaseCatalog) -> [SQLCompletionSuggestion]
}

struct DefaultSuggestionBuilderFactory: SQLSuggestionBuilderFactory {
    func makeBuilder(for dialect: SQLDialect) -> SQLSuggestionBuilder {
        return DefaultSuggestionBuilder(dialect: dialect)
    }
}

final class DefaultSuggestionBuilder: SQLSuggestionBuilder {
    private let dialect: SQLDialect
    private let keywordProvider: SQLKeywordProvider

    init(dialect: SQLDialect, keywordProvider: SQLKeywordProvider = DefaultKeywordProvider()) {
        self.dialect = dialect
        self.keywordProvider = keywordProvider
    }

    func buildSuggestions(context: SQLContext,
                          request: SQLCompletionRequest,
                          catalog: SQLDatabaseCatalog) -> [SQLCompletionSuggestion] {
        var suggestions: [SQLCompletionSuggestion] = []
        let keywordSuggestions = makeKeywordSuggestions(context: context, options: request.options)
        suggestions.append(contentsOf: keywordSuggestions)

        let schemaSuggestions = makeSchemaSuggestions(context: context,
                                                      catalog: catalog,
                                                      selectedDatabase: request.selectedDatabase)
        suggestions.append(contentsOf: schemaSuggestions)

        let tableSuggestions = makeTableLikeSuggestions(context: context,
                                                        catalog: catalog,
                                                        options: request.options,
                                                        defaultSchema: request.defaultSchema)
        suggestions.append(contentsOf: tableSuggestions)

        let columnSuggestions = makeColumnSuggestions(context: context,
                                                      catalog: catalog,
                                                      options: request.options)
        suggestions.append(contentsOf: columnSuggestions)

        let functionSuggestions = makeFunctionSuggestions(context: context,
                                                          catalog: catalog,
                                                          options: request.options)
        suggestions.append(contentsOf: functionSuggestions)

        return suggestions
    }

    private func makeKeywordSuggestions(context: SQLContext,
                                         options: SQLEngineOptions) -> [SQLCompletionSuggestion] {
        var keywords = keywordProvider.keywords(for: dialect, context: context)

        switch options.keywordCasing {
        case .upper:
            keywords = keywords.map { $0.uppercased() }
        case .lower:
            keywords = keywords.map { $0.lowercased() }
        case .preserve:
            break
        }

        return keywords.map {
            SQLCompletionSuggestion(title: $0,
                                    subtitle: nil,
                                    detail: nil,
                                    insertText: $0,
                                    kind: .keyword,
                                    priority: 800)
        }
    }

    private func makeSchemaSuggestions(context: SQLContext,
                                       catalog: SQLDatabaseCatalog,
                                       selectedDatabase: String?) -> [SQLCompletionSuggestion] {
        guard context.pathComponents.isEmpty else { return [] }
        return catalog.schemas.map { schema in
            SQLCompletionSuggestion(title: schema.name,
                                    subtitle: selectedDatabase,
                                    detail: selectedDatabase != nil ? "\(selectedDatabase!).\(schema.name)" : nil,
                                    insertText: "\(schema.name).",
                                    kind: .schema,
                                    priority: 1000)
        }
    }

    private func makeTableLikeSuggestions(context: SQLContext,
                                          catalog: SQLDatabaseCatalog,
                                          options: SQLEngineOptions,
                                          defaultSchema: String?) -> [SQLCompletionSuggestion] {
        guard context.pathComponents.count <= 1 else { return [] }
        guard context.precedingKeyword.map({ SQLContextParser.objectContextKeywords.contains($0) }) ?? true else {
            return []
        }

        var suggestions: [SQLCompletionSuggestion] = []

        for schema in catalog.schemas {
            let schemaMatchesDefault = defaultSchema.map { schema.name.caseInsensitiveCompare($0) == .orderedSame } ?? true
            guard schemaMatchesDefault else { continue }

            for object in schema.objects {
                guard object.type == .table || object.type == .view || object.type == .materializedView else { continue }

                var insertText = object.name
                if context.pathComponents.isEmpty {
                    insertText = schema.name.caseInsensitiveCompare(defaultSchema ?? "") == .orderedSame ? object.name : "\(schema.name).\(object.name)"
                }

                if options.enableAliasShortcuts,
                   let alias = AliasGenerator.shortcut(for: object.name) {
                    insertText += " \(alias)"
                }

                let suggestionKind: SQLCompletionSuggestion.Kind = {
                    switch object.type {
                    case .table: return .table
                    case .view: return .view
                    case .materializedView: return .materializedView
                    default: return .table
                    }
                }()

                let tableColumns = object.columns.map {
                    SQLCompletionSuggestion.TableColumn(
                        name: $0.name,
                        dataType: $0.dataType,
                        isNullable: false,
                        isPrimaryKey: false
                    )
                }

                suggestions.append(SQLCompletionSuggestion(title: object.name,
                                                            subtitle: schema.name,
                                                            detail: "\(schema.name).\(object.name)",
                                                            insertText: insertText,
                                                            kind: suggestionKind,
                                                            priority: 1000,
                                                            origin: .init(schema: schema.name, object: object.name),
                                                            tableColumns: tableColumns.isEmpty ? nil : tableColumns))
            }
        }

        return suggestions
    }

    private func makeColumnSuggestions(context: SQLContext,
                                       catalog: SQLDatabaseCatalog,
                                       options: SQLEngineOptions) -> [SQLCompletionSuggestion] {
        guard !context.tablesInScope.isEmpty else { return [] }

        var suggestions: [SQLCompletionSuggestion] = []
        var seen: Set<String> = []

        for tableRef in context.tablesInScope {
            var resolvedSchema: SQLSchema?
            var resolvedObject: SQLObject?

            if let schemaName = tableRef.schema {
                if let schema = catalog.schemas.first(where: { $0.name.caseInsensitiveCompare(schemaName) == .orderedSame }) {
                    if let object = schema.objects.first(where: { $0.name.caseInsensitiveCompare(tableRef.name) == .orderedSame }) {
                        resolvedSchema = schema
                        resolvedObject = object
                    }
                }
            } else {
                outer: for schema in catalog.schemas {
                    for object in schema.objects where object.name.caseInsensitiveCompare(tableRef.name) == .orderedSame {
                        resolvedSchema = schema
                        resolvedObject = object
                        break outer
                    }
                }
            }

            guard let schema = resolvedSchema, let object = resolvedObject else { continue }

            for column in object.columns {
                let baseID = "column|\(schema.name.lowercased())|\(object.name.lowercased())|\(column.name.lowercased())"
                if let alias = tableRef.alias, !alias.isEmpty {
                    let aliasKey = baseID + "|alias=" + alias.lowercased()
                    if seen.insert(aliasKey).inserted {
                        let title = "\(alias).\(column.name)"
                        suggestions.append(SQLCompletionSuggestion(id: aliasKey,
                                                                   title: title,
                                                                   subtitle: "\(object.name) • \(schema.name)",
                                                                   detail: "Column \(schema.name).\(object.name).\(column.name)",
                                                                   insertText: title,
                                                                   kind: .column,
                                                                   priority: 1200,
                                                                   origin: .init(schema: schema.name, object: object.name, column: column.name),
                                                                   dataType: column.dataType))
                    }
                } else {
                    if seen.insert(baseID).inserted {
                        suggestions.append(SQLCompletionSuggestion(id: baseID,
                                                                   title: column.name,
                                                                   subtitle: "\(object.name) • \(schema.name)",
                                                                   detail: "Column \(schema.name).\(object.name).\(column.name)",
                                                                   insertText: column.name,
                                                                   kind: .column,
                                                                   priority: 1100,
                                                                   origin: .init(schema: schema.name, object: object.name, column: column.name),
                                                                   dataType: column.dataType))
                    }
                }
            }
        }

        return suggestions
    }

    private func makeFunctionSuggestions(context: SQLContext,
                                         catalog: SQLDatabaseCatalog,
                                         options: SQLEngineOptions) -> [SQLCompletionSuggestion] {
        guard SQLContextParser.columnContextKeywords.contains(context.precedingKeyword ?? "select") else { return [] }

        var suggestions: [SQLCompletionSuggestion] = []
        var seen: Set<String> = []

        for schema in catalog.schemas {
            for object in schema.objects {
                guard object.type == .function else { continue }
                let id = "function|\(schema.name.lowercased())|\(object.name.lowercased())"
                guard seen.insert(id).inserted else { continue }
                var insertText = object.name + "("
                switch options.keywordCasing {
                case .upper:
                    insertText = insertText.uppercased()
                case .lower:
                    insertText = insertText.lowercased()
                case .preserve:
                    break
                }
                suggestions.append(SQLCompletionSuggestion(id: id,
                                                           title: object.name,
                                                           subtitle: schema.name,
                                                           detail: "Function \(schema.name).\(object.name)",
                                                           insertText: insertText,
                                                           kind: .function,
                                                           priority: 900))
            }
        }

        return suggestions
    }
}

protocol SQLKeywordProvider {
    func keywords(for dialect: SQLDialect, context: SQLContext) -> [String]
}

struct DefaultKeywordProvider: SQLKeywordProvider {
    func keywords(for dialect: SQLDialect, context: SQLContext) -> [String] {
        return Self.commonKeywords
    }

    private static let commonKeywords: [String] = [
        "select", "where", "update", "delete", "group", "order", "from", "by",
        "create", "table", "drop", "alter", "view", "execute", "procedure",
        "distinct", "insert", "join", "left", "right", "inner", "outer",
        "having", "limit", "offset", "values", "set", "into"
    ]
}

enum AliasGenerator {
    static func shortcut(for name: String) -> String? {
        let components = name.split { !$0.isLetter && !$0.isNumber }
        var result: [Character] = []
        for component in components where !component.isEmpty {
            if let first = component.first {
                result.append(Character(first.lowercased()))
            }
            for scalar in component.unicodeScalars.dropFirst() {
                if CharacterSet.uppercaseLetters.contains(scalar) {
                    result.append(Character(String(scalar).lowercased()))
                }
            }
        }

        if !result.isEmpty {
            return String(result)
        }

        let trimmed = name.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard !trimmed.isEmpty else { return nil }
        let fallback = trimmed.prefix(3).map { Character(String($0).lowercased()) }
        return fallback.isEmpty ? nil : String(fallback)
    }
}
