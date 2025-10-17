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
    private let providers: [SuggestionProvider]

    init(dialect: SQLDialect, keywordProvider: SQLKeywordProvider = DefaultKeywordProvider()) {
        self.dialect = dialect
        self.keywordProvider = keywordProvider
        self.providers = [
            JoinSuggestionProvider(),
            StarExpansionProvider(),
            ColumnSuggestionProvider(),
            TableSuggestionProvider(),
            SchemaSuggestionProvider(),
            FunctionSuggestionProvider(),
            ParameterSuggestionProvider(),
            SnippetSuggestionProvider(),
            KeywordSuggestionProvider()
        ]
    }

    func buildSuggestions(context: SQLContext,
                          request: SQLCompletionRequest,
                          catalog: SQLDatabaseCatalog) -> [SQLCompletionSuggestion] {
        let identifier = IdentifierContext(token: context.currentToken)
        let providerContext = ProviderContext(sqlContext: context,
                                              request: request,
                                              catalog: catalog,
                                              identifier: identifier,
                                              dialect: dialect,
                                              keywordProvider: keywordProvider)

        var collected: [SQLCompletionSuggestion] = []
        for provider in providers {
            collected.append(contentsOf: provider.suggestions(in: providerContext))
        }
        return deduplicatedAndSorted(collected)
    }

    private func deduplicatedAndSorted(_ suggestions: [SQLCompletionSuggestion]) -> [SQLCompletionSuggestion] {
        var seen = Set<String>()
        var unique: [SQLCompletionSuggestion] = []
        for suggestion in suggestions {
            if seen.insert(suggestion.id).inserted {
                unique.append(suggestion)
            }
        }

        return unique.sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.priority > rhs.priority
        }
    }
}

private struct ProviderContext {
    let sqlContext: SQLContext
    let request: SQLCompletionRequest
    let catalog: SQLDatabaseCatalog
    let identifier: IdentifierContext
    let dialect: SQLDialect
    let keywordProvider: SQLKeywordProvider

    var defaultSchemaLowercased: String? {
        request.defaultSchema?.lowercased()
    }

    var hasObjectKeywordContext: Bool {
        sqlContext.precedingKeyword.map { SQLContextParser.objectContextKeywords.contains($0) } ?? false
    }

    var hasColumnKeywordContext: Bool {
        sqlContext.precedingKeyword.map { SQLContextParser.columnContextKeywords.contains($0) } ?? false
    }

    func resolve(_ reference: SQLContext.TableReference) -> TableResolution? {
        if let schemaName = reference.schema {
            if let schema = catalog.schemas.first(where: { $0.name.caseInsensitiveCompare(schemaName) == .orderedSame }),
               let object = schema.objects.first(where: { $0.name.caseInsensitiveCompare(reference.name) == .orderedSame }) {
                return TableResolution(schema: schema, object: object)
            }
        } else {
            for schema in catalog.schemas {
                if let object = schema.objects.first(where: { $0.name.caseInsensitiveCompare(reference.name) == .orderedSame }) {
                    return TableResolution(schema: schema, object: object)
                }
            }
        }
        return nil
    }

    func cteColumns(for reference: SQLContext.TableReference) -> [String]? {
        let lowerAlias = reference.alias?.lowercased()
        let lowerName = reference.name.lowercased()
        if let alias = lowerAlias, let columns = sqlContext.cteColumns[alias] {
            return columns
        }
        if let columns = sqlContext.cteColumns[lowerName] {
            return columns
        }
        return nil
    }

    func cteColumns(for name: String) -> [String]? {
        sqlContext.cteColumns[name.lowercased()]
    }
}

private struct IdentifierContext {
    let rawToken: String
    let trimmedToken: String
    let prefix: String
    let lowercasePrefix: String
    let precedingSegments: [String]
    let precedingLowercased: [String]
    let isTrailingDot: Bool

    init(token: String) {
        rawToken = token
        trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmedToken.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        if let last = components.last {
            prefix = last
        } else {
            prefix = ""
        }
        lowercasePrefix = prefix.lowercased()
        isTrailingDot = trimmedToken.last == "."
        let preceding = components.isEmpty ? [] : Array(components.dropLast())
        precedingSegments = preceding
        precedingLowercased = preceding.map { $0.lowercased() }
    }

    func matchesPrefix(of candidate: String) -> Bool {
        guard !lowercasePrefix.isEmpty else { return true }
        return candidate.lowercased().hasPrefix(lowercasePrefix)
    }
}

private struct TableResolution {
    let schema: SQLSchema
    let object: SQLObject
}

private protocol SuggestionProvider {
    func suggestions(in context: ProviderContext) -> [SQLCompletionSuggestion]
}

private struct KeywordSuggestionProvider: SuggestionProvider {
    func suggestions(in context: ProviderContext) -> [SQLCompletionSuggestion] {
        let keywords = context.keywordProvider.keywords(for: context.dialect,
                                                        context: context.sqlContext)
        let prefix = context.identifier.lowercasePrefix

        var seen = Set<String>()
        var results: [SQLCompletionSuggestion] = []

        for keyword in keywords {
            let lower = keyword.lowercased()
            guard seen.insert(lower).inserted else { continue }
            if !prefix.isEmpty && !lower.hasPrefix(prefix) {
                continue
            }

            let (display, insert) = KeywordSuggestionProvider.casedKeyword(keyword,
                                                                           option: context.request.options.keywordCasing)
            let priority = KeywordSuggestionProvider.priority(for: context.sqlContext.clause)

            results.append(SQLCompletionSuggestion(id: "keyword|\(lower)",
                                                   title: display,
                                                   subtitle: nil,
                                                   detail: nil,
                                                   insertText: insert,
                                                   kind: .keyword,
                                                   priority: priority))
        }

        return results
    }

    private static func casedKeyword(_ keyword: String,
                                     option: SQLEngineOptions.KeywordCasing) -> (display: String, insert: String) {
        switch option {
        case .upper:
            let upper = keyword.uppercased()
            return (upper, upper)
        case .lower:
            let lower = keyword.lowercased()
            return (lower, lower)
        case .preserve:
            return (keyword.uppercased(), keyword)
        }
    }

    private static func priority(for clause: SQLClause) -> Int {
        switch clause {
        case .selectList, .whereClause, .having, .groupBy, .orderBy, .joinCondition:
            return 750
        case .from, .joinTarget, .deleteWhere:
            return 700
        default:
            return 650
        }
    }
}

private struct SchemaSuggestionProvider: SuggestionProvider {
    func suggestions(in context: ProviderContext) -> [SQLCompletionSuggestion] {
        let clause = context.sqlContext.clause
        let isObjectClause = Self.supportedClauses.contains(clause) || context.hasObjectKeywordContext
        guard isObjectClause else { return [] }

        let identifier = context.identifier
        if identifier.isTrailingDot,
           let last = identifier.precedingLowercased.last,
           context.catalog.schemas.contains(where: { $0.name.lowercased() == last }) {
            return []
        }
        if !identifier.precedingSegments.isEmpty && !identifier.lowercasePrefix.isEmpty {
            return []
        }

        let prefix = identifier.lowercasePrefix
        let selectedDatabase = context.request.selectedDatabase
        var results: [SQLCompletionSuggestion] = []

        for schema in context.catalog.schemas {
            if !prefix.isEmpty && !schema.name.lowercased().hasPrefix(prefix) {
                continue
            }

            var components = identifier.precedingSegments
            if let last = components.last,
               schema.name.lowercased().hasPrefix(last.lowercased()) {
                components.removeLast()
            }
            components.append(schema.name)

            let insertText = components.joined(separator: ".") + "."
            let detail = selectedDatabase.map { "\($0).\(schema.name)" }

            results.append(SQLCompletionSuggestion(id: "schema|\(schema.name.lowercased())",
                                                   title: schema.name,
                                                   subtitle: selectedDatabase,
                                                   detail: detail,
                                                   insertText: insertText,
                                                   kind: .schema,
                                                   priority: 950))
        }

        return results
    }

    private static let supportedClauses: Set<SQLClause> = [
        .from, .joinTarget, .withCTE, .unknown
    ]
}

private struct TableSuggestionProvider: SuggestionProvider {
    func suggestions(in context: ProviderContext) -> [SQLCompletionSuggestion] {
        let clause = context.sqlContext.clause
        let isObjectClause = Self.supportedClauses.contains(clause) || context.hasObjectKeywordContext
        guard isObjectClause else { return [] }

        let identifier = context.identifier
        let prefix = identifier.lowercasePrefix

        let schemaFilterLower = identifier.precedingLowercased.last
        let exactSchema = schemaFilterLower.flatMap { filter in
            context.catalog.schemas.first(where: { $0.name.lowercased() == filter })
        }

        var candidateSchemas: [SQLSchema]
        if let exactSchema {
            candidateSchemas = [exactSchema]
        } else {
            candidateSchemas = context.catalog.schemas
        }

        var results: [SQLCompletionSuggestion] = []
        for schema in candidateSchemas {
            if exactSchema == nil,
               let filter = schemaFilterLower,
               !filter.isEmpty,
               !schema.name.lowercased().hasPrefix(filter) {
                continue
            }

            for object in schema.objects where Self.supportedObjectTypes.contains(object.type) {
                let objectLower = object.name.lowercased()
                if !prefix.isEmpty && !objectLower.hasPrefix(prefix) {
                    continue
                }

                var components = identifier.precedingSegments
                if components.isEmpty {
                    if let defaultSchema = context.defaultSchemaLowercased,
                       schema.name.lowercased() == defaultSchema {
                        components = []
                    } else {
                        components = [schema.name]
                    }
                } else if let lastIndex = components.indices.last,
                          schema.name.lowercased().hasPrefix(components[lastIndex].lowercased()) {
                    components[lastIndex] = schema.name
                }

                components.append(object.name)
                var insertText = components.joined(separator: ".")

                if context.request.options.enableAliasShortcuts,
                   let alias = AliasGenerator.shortcut(for: object.name) {
                    insertText += " \(alias)"
                }

                let id = "object|\(schema.name.lowercased())|\(objectLower)"
                let priority = Self.priority(for: clause,
                                             schema: schema,
                                             defaultSchemaLower: context.defaultSchemaLowercased)

                results.append(SQLCompletionSuggestion(id: id,
                                                       title: object.name,
                                                       subtitle: schema.name,
                                                       detail: "\(schema.name).\(object.name)",
                                                       insertText: insertText,
                                                       kind: Self.kind(for: object.type),
                                                       priority: priority))
            }
        }

        return results
    }

    private static func priority(for clause: SQLClause,
                                 schema: SQLSchema,
                                 defaultSchemaLower: String?) -> Int {
        var base: Int
        switch clause {
        case .from, .joinTarget:
            base = 1300
        case .deleteWhere:
            base = 1200
        case .withCTE:
            base = 1100
        default:
            base = 1000
        }
        if let defaultSchemaLower,
           schema.name.lowercased() == defaultSchemaLower {
            base += 25
        }
        return base
    }

    private static func kind(for objectType: SQLObject.ObjectType) -> SQLCompletionSuggestion.Kind {
        switch objectType {
        case .table: return .table
        case .view: return .view
        case .materializedView: return .materializedView
        case .procedure: return .procedure
        case .function: return .function
        }
    }

    private static let supportedClauses: Set<SQLClause> = [
        .from, .joinTarget, .deleteWhere, .withCTE, .unknown
    ]

    private static let supportedObjectTypes: Set<SQLObject.ObjectType> = [
        .table, .view, .materializedView
    ]
}

private struct JoinSuggestionProvider: SuggestionProvider {
    func suggestions(in context: ProviderContext) -> [SQLCompletionSuggestion] {
        guard context.sqlContext.clause == .joinCondition else { return [] }
        let references = context.sqlContext.tablesInScope
        guard references.count >= 2 else { return [] }

        let identifierToken = context.identifier.trimmedToken.lowercased()

        var resolved: [(ref: SQLContext.TableReference, res: TableResolution?)] = []
        resolved.reserveCapacity(references.count)
        for ref in references {
            resolved.append((ref, context.resolve(ref)))
        }

        var results: [SQLCompletionSuggestion] = []
        var seen = Set<String>()

        for (sourceRef, sourceResolution) in resolved {
            guard let sourceResolution else { continue }
            for fk in sourceResolution.object.foreignKeys {
                for target in resolved {
                    guard let targetRes = target.res else { continue }
                    if target.ref.isEquivalent(to: sourceRef) {
                        continue
                    }
                    guard JoinSuggestionProvider.matches(foreignKey: fk,
                                                         target: targetRes) else { continue }

                    let expression = JoinSuggestionProvider.joinExpression(source: sourceRef,
                                                                           target: target.ref,
                                                                           foreignKey: fk)
                    guard !expression.isEmpty else { continue }

                    if !identifierToken.isEmpty && !expression.lowercased().hasPrefix(identifierToken) {
                        continue
                    }

                    let id = "join|\(sourceResolution.schema.name.lowercased())|\(sourceResolution.object.name.lowercased())|\(fk.columns.joined(separator: ","))|\(target.ref.alias?.lowercased() ?? target.ref.name.lowercased())"
                    guard seen.insert(id).inserted else { continue }

                    let detail: String
                    if let name = fk.name {
                        detail = "FK \(name)"
                    } else {
                        detail = "\(sourceResolution.schema.name).\(sourceResolution.object.name)"
                    }

                    results.append(SQLCompletionSuggestion(id: id,
                                                           title: expression,
                                                           subtitle: "Join",
                                                           detail: detail,
                                                           insertText: expression,
                                                           kind: .join,
                                                           priority: 1700))
                }
            }
        }

        return results
    }

    private static func matches(foreignKey: SQLForeignKey,
                                target: TableResolution) -> Bool {
        let referencedSchema = foreignKey.referencedSchema?.lowercased()
        let targetSchema = target.schema.name.lowercased()
        if let referencedSchema, referencedSchema != targetSchema {
            return false
        }
        return foreignKey.referencedTable.lowercased() == target.object.name.lowercased()
    }

    private static func joinExpression(source: SQLContext.TableReference,
                                       target: SQLContext.TableReference,
                                       foreignKey: SQLForeignKey) -> String {
        guard foreignKey.columns.count == foreignKey.referencedColumns.count else { return "" }
        let leftQualifier = source.alias ?? source.name
        let rightQualifier = target.alias ?? target.name

        let pairs = zip(foreignKey.columns, foreignKey.referencedColumns)
        let segments = pairs.map { lhs, rhs in
            "\(leftQualifier).\(lhs) = \(rightQualifier).\(rhs)"
        }
        return segments.joined(separator: " AND ")
    }
}

private struct StarExpansionProvider: SuggestionProvider {
    func suggestions(in context: ProviderContext) -> [SQLCompletionSuggestion] {
        guard context.sqlContext.clause == .selectList else { return [] }
        let token = context.identifier.trimmedToken
        guard token == "*" || token.hasSuffix(".*") else { return [] }

        let aliasFilter = context.identifier.precedingLowercased.last
        let references = context.sqlContext.tablesInScope.filter { reference in
            guard let aliasFilter else { return true }
            if let alias = reference.alias?.lowercased(), alias == aliasFilter {
                return true
            }
            return reference.name.lowercased() == aliasFilter
        }

        let targets = references.isEmpty ? context.sqlContext.tablesInScope : references
        guard !targets.isEmpty else { return [] }

        var columnIdentifiers: [String] = []
        for reference in targets {
            if let resolution = context.resolve(reference) {
                let qualifier = qualifierFor(reference: reference,
                                             forceQualifier: aliasFilter != nil,
                                             totalTargets: targets.count)
                for column in resolution.object.columns {
                    if let qualifier {
                        columnIdentifiers.append("\(qualifier).\(column.name)")
                    } else {
                        columnIdentifiers.append(column.name)
                    }
                }
            } else if let cteColumns = context.cteColumns(for: reference) {
                let qualifier = qualifierFor(reference: reference,
                                             forceQualifier: aliasFilter != nil,
                                             totalTargets: targets.count)
                for column in cteColumns {
                    if let qualifier {
                        columnIdentifiers.append("\(qualifier).\(column)")
                    } else {
                        columnIdentifiers.append(column)
                    }
                }
            }
        }

        guard !columnIdentifiers.isEmpty else { return [] }

        let insertText = columnIdentifiers.joined(separator: ", ")
        let detailPreviewCount = min(4, columnIdentifiers.count)
        let preview = columnIdentifiers.prefix(detailPreviewCount).joined(separator: ", ")
        let detail = columnIdentifiers.count > detailPreviewCount ? preview + ", …" : preview

        let identifier = columnIdentifiers.joined(separator: "|").lowercased()
        return [
            SQLCompletionSuggestion(id: "star|\(identifier)",
                                    title: "Expand * to columns",
                                    subtitle: "Star Expansion",
                                    detail: detail,
                                    insertText: insertText,
                                    kind: .snippet,
                                    priority: 1600)
        ]
    }

    private func qualifierFor(reference: SQLContext.TableReference,
                              forceQualifier: Bool,
                              totalTargets: Int) -> String? {
        if forceQualifier {
            return reference.alias ?? reference.name
        }
        if totalTargets > 1 {
            return reference.alias ?? reference.name
        }
        return reference.alias
    }
}

private struct ColumnSuggestionProvider: SuggestionProvider {
    func suggestions(in context: ProviderContext) -> [SQLCompletionSuggestion] {
        guard !context.sqlContext.tablesInScope.isEmpty else { return [] }

        let clause = context.sqlContext.clause
        let isColumnClause = Self.supportedClauses.contains(clause) || context.hasColumnKeywordContext
        guard isColumnClause else { return [] }

        let identifier = context.identifier
        let prefix = identifier.lowercasePrefix
        let segments = identifier.precedingLowercased

        var results: [SQLCompletionSuggestion] = []
        var seen = Set<String>()

        let forceQualifier = context.sqlContext.tablesInScope.count > 1

        for tableRef in context.sqlContext.tablesInScope {
            let match = Self.matchKind(for: tableRef, segments: segments)
            guard match != .none else { continue }

            if let resolved = context.resolve(tableRef) {
                appendColumns(from: resolved,
                              tableRef: tableRef,
                              match: match,
                              prefix: prefix,
                              clause: clause,
                              forceQualifier: forceQualifier,
                              results: &results,
                              seen: &seen)
            } else if let cteColumns = context.cteColumns(for: tableRef) {
                appendCTEColumns(cteColumns,
                                 tableRef: tableRef,
                                 match: match,
                                 prefix: prefix,
                                 clause: clause,
                                 forceQualifier: forceQualifier,
                                 results: &results,
                                 seen: &seen)
            }
        }

        return results
    }

    private static func matchKind(for reference: SQLContext.TableReference,
                                  segments: [String]) -> ColumnPathMatch {
        guard !segments.isEmpty else { return .any }

        let last = segments.last!
        if let alias = reference.alias?.lowercased(),
           last == alias {
            return .alias
        }

        if last == reference.name.lowercased() {
            if segments.count == 1 {
                return .table
            }
            let beforeLast = segments[segments.count - 2]
            if let schema = reference.schema?.lowercased(),
               schema == beforeLast {
                return .table
            }
        }

        if segments.count >= 2,
           let alias = reference.alias?.lowercased(),
           segments[segments.count - 2] == alias,
           last == reference.name.lowercased() {
            return .alias
        }

        return .none
    }

    private static func priority(for clause: SQLClause) -> Int {
        switch clause {
        case .selectList:
            return 1500
        case .whereClause, .having, .joinCondition:
            return 1450
        case .groupBy, .orderBy:
            return 1400
        case .values, .updateSet:
            return 1350
        default:
            return 1250
        }
    }

    private enum ColumnPathMatch {
        case any
        case alias
        case table
        case none
    }

    private static let supportedClauses: Set<SQLClause> = [
        .selectList, .whereClause, .having, .joinCondition, .groupBy, .orderBy, .values, .updateSet
    ]

    private func appendColumns(from resolution: TableResolution,
                               tableRef: SQLContext.TableReference,
                               match: ColumnPathMatch,
                               prefix: String,
                               clause: SQLClause,
                               forceQualifier: Bool,
                               results: inout [SQLCompletionSuggestion],
                               seen: inout Set<String>) {
        let includeAlias = match != .table ? tableRef.alias != nil : (tableRef.alias != nil)
        let includeUnqualified = match != .alias

        for column in resolution.object.columns {
            let lower = column.name.lowercased()
            if !prefix.isEmpty && !lower.hasPrefix(prefix) {
                continue
            }

            let baseID = "column|\(resolution.schema.name.lowercased())|\(resolution.object.name.lowercased())|\(lower)"
            let priority = Self.priority(for: clause) + ColumnSuggestionProvider.priorityBoost(for: column)

            if includeAlias, let alias = tableRef.alias {
                let aliasKey = baseID + "|alias=" + alias.lowercased()
                if seen.insert(aliasKey).inserted {
                    let title = "\(alias).\(column.name)"
                    results.append(SQLCompletionSuggestion(id: aliasKey,
                                                           title: title,
                                                           subtitle: "\(resolution.object.name) • \(resolution.schema.name)",
                                                           detail: "Column \(resolution.schema.name).\(resolution.object.name).\(column.name)",
                                                           insertText: title,
                                                           kind: .column,
                                                           priority: priority + 10))
                }
            }

            if includeUnqualified, seen.insert(baseID).inserted {
                let needsQualifier = qualifierNeeded(match: match, forceQualifier: forceQualifier)
                let chosenQualifier = tableRef.alias ?? tableRef.name
                let insert = needsQualifier ? "\(chosenQualifier).\(column.name)" : column.name
                let title = needsQualifier ? insert : column.name
                results.append(SQLCompletionSuggestion(id: baseID,
                                                       title: title,
                                                       subtitle: "\(resolution.object.name) • \(resolution.schema.name)",
                                                       detail: "Column \(resolution.schema.name).\(resolution.object.name).\(column.name)",
                                                       insertText: insert,
                                                       kind: .column,
                                                       priority: priority))
            }
        }
    }

    private func appendCTEColumns(_ columns: [String],
                                  tableRef: SQLContext.TableReference,
                                  match: ColumnPathMatch,
                                  prefix: String,
                                  clause: SQLClause,
                                  forceQualifier: Bool,
                                  results: inout [SQLCompletionSuggestion],
                                  seen: inout Set<String>) {
        let includeAlias = match != .table ? tableRef.alias != nil : (tableRef.alias != nil)
        let includeUnqualified = match != .alias
        let qualifier = tableRef.alias ?? tableRef.name

        for column in columns {
            let lower = column.lowercased()
            if !prefix.isEmpty && !lower.hasPrefix(prefix) {
                continue
            }

            let baseID = "cte|\(qualifier.lowercased())|\(lower)"
            let priority = Self.priority(for: clause)

            if includeAlias, let alias = tableRef.alias {
                let aliasKey = baseID + "|alias=" + alias.lowercased()
                if seen.insert(aliasKey).inserted {
                    let title = "\(alias).\(column)"
                    results.append(SQLCompletionSuggestion(id: aliasKey,
                                                           title: title,
                                                           subtitle: qualifier,
                                                           detail: "CTE Column \(qualifier).\(column)",
                                                           insertText: title,
                                                           kind: .column,
                                                           priority: priority + 5))
                }
            }

            if includeUnqualified, seen.insert(baseID).inserted {
                let needsQualifier = qualifierNeeded(match: match, forceQualifier: forceQualifier)
                let chosenQualifier = tableRef.alias ?? tableRef.name
                let insert = needsQualifier ? "\(chosenQualifier).\(column)" : column
                let title = needsQualifier ? insert : column
                results.append(SQLCompletionSuggestion(id: baseID,
                                                       title: title,
                                                       subtitle: qualifier,
                                                       detail: "CTE Column \(qualifier).\(column)",
                                                       insertText: insert,
                                                       kind: .column,
                                                       priority: priority))
            }
        }
    }

    private static func priorityBoost(for column: SQLColumn) -> Int {
        if column.isPrimaryKey {
            return 40
        }
        if column.isForeignKey {
            return 20
        }
        return 0
    }

    private func qualifierNeeded(match: ColumnPathMatch, forceQualifier: Bool) -> Bool {
        switch match {
        case .alias:
            return true
        case .table:
            return forceQualifier
        case .any:
            return forceQualifier
        case .none:
            return false
        }
    }
}

private struct FunctionSuggestionProvider: SuggestionProvider {
    func suggestions(in context: ProviderContext) -> [SQLCompletionSuggestion] {
        let clause = context.sqlContext.clause
        let isColumnClause = Self.supportedClauses.contains(clause) || context.hasColumnKeywordContext
        guard isColumnClause else { return [] }

        let prefix = context.identifier.lowercasePrefix
        var results: [SQLCompletionSuggestion] = []
        var seen = Set<String>()

        for schema in context.catalog.schemas {
            for object in schema.objects where object.type == .function {
                let lower = object.name.lowercased()
                if !prefix.isEmpty && !lower.hasPrefix(prefix) {
                    continue
                }
                let id = "function|\(schema.name.lowercased())|\(lower)"
                guard seen.insert(id).inserted else { continue }

                let priority = Self.priority(for: clause)
                results.append(SQLCompletionSuggestion(id: id,
                                                       title: object.name,
                                                       subtitle: schema.name,
                                                       detail: "Function \(schema.name).\(object.name)",
                                                       insertText: object.name + "(",
                                                       kind: .function,
                                                       priority: priority))
            }
        }

        return results
    }

    private static func priority(for clause: SQLClause) -> Int {
        switch clause {
        case .selectList:
            return 1200
        case .whereClause, .having, .joinCondition:
            return 1150
        default:
            return 1100
        }
    }

    private static let supportedClauses: Set<SQLClause> = [
        .selectList, .whereClause, .having, .groupBy, .orderBy, .joinCondition, .values, .updateSet
    ]
}

private struct ParameterSuggestionProvider: SuggestionProvider {
    func suggestions(in context: ProviderContext) -> [SQLCompletionSuggestion] {
        guard Self.supportedClauses.contains(context.sqlContext.clause) else { return [] }

        let prefix = context.identifier.lowercasePrefix
        let candidates = SQLParameterSuggester.parameterSuggestions(for: context.request.text,
                                                                    dialect: context.dialect)
        var results: [SQLCompletionSuggestion] = []

        for candidate in candidates {
            let lower = candidate.lowercased()
            if !prefix.isEmpty && !lower.hasPrefix(prefix) {
                continue
            }
            results.append(SQLCompletionSuggestion(id: "parameter|\(lower)",
                                                   title: candidate,
                                                   subtitle: "Parameter",
                                                   detail: nil,
                                                   insertText: candidate,
                                                   kind: .parameter,
                                                   priority: 1300))
        }

        return results
    }

    private static let supportedClauses: Set<SQLClause> = [
        .whereClause, .having, .joinCondition, .values, .updateSet, .selectList
    ]
}

private struct SnippetSuggestionProvider: SuggestionProvider {
    func suggestions(in context: ProviderContext) -> [SQLCompletionSuggestion] {
        let allowedGroups = Self.allowedGroups(for: context.sqlContext.clause)
        guard !allowedGroups.isEmpty else { return [] }

        let prefix = context.identifier.lowercasePrefix
        let snippets = SQLSnippetCatalog.snippets(for: context.dialect)

        var results: [SQLCompletionSuggestion] = []
        for snippet in snippets where allowedGroups.contains(snippet.group) {
            let lowerTitle = snippet.title.lowercased()
            if !prefix.isEmpty && !lowerTitle.hasPrefix(prefix) {
                continue
            }
            results.append(SQLCompletionSuggestion(id: "snippet|\(snippet.id)",
                                                   title: snippet.title,
                                                   subtitle: "Snippet",
                                                   detail: snippet.detail,
                                                   insertText: snippet.insertText,
                                                   kind: .snippet,
                                                   priority: snippet.priority))
        }

        return results
    }

    private static func allowedGroups(for clause: SQLClause) -> Set<SQLSnippet.Group> {
        switch clause {
        case .selectList:
            return [.select, .json, .general]
        case .whereClause, .having, .joinCondition:
            return [.filter, .json, .general]
        case .from, .joinTarget:
            return [.join, .general]
        case .values, .updateSet:
            return [.modification, .general]
        default:
            return [.general]
        }
    }
}

protocol SQLKeywordProvider {
    func keywords(for dialect: SQLDialect, context: SQLContext) -> [String]
}

struct DefaultKeywordProvider: SQLKeywordProvider {
    func keywords(for dialect: SQLDialect, context: SQLContext) -> [String] {
        var ordered: [String] = []

        switch context.clause {
        case .selectList:
            ordered.append(contentsOf: Self.selectKeywords)
        case .from, .joinTarget, .withCTE, .deleteWhere:
            ordered.append(contentsOf: Self.fromKeywords)
        case .whereClause, .joinCondition, .having:
            ordered.append(contentsOf: Self.filterKeywords)
        case .groupBy:
            ordered.append(contentsOf: Self.groupKeywords)
        case .orderBy:
            ordered.append(contentsOf: Self.orderKeywords)
        case .values:
            ordered.append(contentsOf: Self.valuesKeywords)
        case .updateSet:
            ordered.append(contentsOf: Self.updateKeywords)
        default:
            break
        }

        ordered.append(contentsOf: Self.commonKeywords)
        return DefaultKeywordProvider.unique(ordered)
    }

    private static let commonKeywords: [String] = [
        "select", "where", "update", "delete", "group", "order", "from", "by",
        "create", "table", "drop", "alter", "view", "execute", "procedure",
        "distinct", "insert", "join", "left", "right", "inner", "outer",
        "having", "limit", "offset", "values", "set", "into"
    ]

    private static let selectKeywords: [String] = [
        "select", "distinct", "case", "when", "then", "else", "end", "from", "where",
        "group", "order", "limit", "offset", "having", "union", "intersect", "except"
    ]

    private static let fromKeywords: [String] = [
        "from", "join", "inner", "left", "right", "full", "outer", "cross",
        "on", "using", "where", "group", "partition", "lateral"
    ]

    private static let filterKeywords: [String] = [
        "where", "and", "or", "not", "exists", "in", "between", "like", "ilike",
        "is", "null", "coalesce"
    ]

    private static let groupKeywords: [String] = [
        "group", "by", "rollup", "cube", "grouping", "sets", "having"
    ]

    private static let orderKeywords: [String] = [
        "order", "by", "asc", "desc", "nulls", "first", "last"
    ]

    private static let valuesKeywords: [String] = [
        "values", "returning", "default"
    ]

    private static let updateKeywords: [String] = [
        "set", "from", "where", "returning"
    ]

    private static func unique(_ keywords: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for keyword in keywords {
            let lower = keyword.lowercased()
            if seen.insert(lower).inserted {
                result.append(lower)
            }
        }
        return result
    }
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
