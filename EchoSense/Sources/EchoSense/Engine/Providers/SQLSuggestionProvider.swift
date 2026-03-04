import Foundation

protocol SQLSuggestionProvider: Sendable {
    func suggestions(in context: SQLProviderContext) -> [SQLCompletionSuggestion]
}

struct SQLProviderContext {
    let sqlContext: SQLContext
    let request: SQLCompletionRequest
    let catalog: SQLDatabaseCatalog
    let identifier: SQLIdentifierContext
    let dialect: SQLDialect
    let keywordProvider: SQLKeywordProvider
    let identifierQuoter: SQLIdentifierQuoter

    var defaultSchemaLowercased: String? {
        request.defaultSchema?.lowercased()
    }

    var hasObjectKeywordContext: Bool {
        sqlContext.precedingKeyword.map { SQLContextParser.objectContextKeywords.contains($0) } ?? false
    }

    var hasColumnKeywordContext: Bool {
        sqlContext.precedingKeyword.map { SQLContextParser.columnContextKeywords.contains($0) } ?? false
    }

    func resolve(_ reference: SQLContext.TableReference) -> SQLTableResolution? {
        if let schemaName = reference.schema {
            if let schema = catalog.schemas.first(where: { $0.name.caseInsensitiveCompare(schemaName) == .orderedSame }),
               let object = schema.objects.first(where: { $0.name.caseInsensitiveCompare(reference.name) == .orderedSame }) {
                return SQLTableResolution(schema: schema, object: object)
            }
        } else {
            for schema in catalog.schemas {
                if let object = schema.objects.first(where: { $0.name.caseInsensitiveCompare(reference.name) == .orderedSame }) {
                    return SQLTableResolution(schema: schema, object: object)
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

    func qualify(_ components: [String]) -> String {
        identifierQuoter.qualify(components)
    }

    func qualifier(for reference: SQLContext.TableReference) -> String {
        if let alias = reference.alias {
            return alias
        }
        return identifierQuoter.quoteIfNeeded(reference.name)
    }

    func qualifier(for reference: SQLContext.TableReference, candidate: String) -> String {
        if let alias = reference.alias,
           alias.caseInsensitiveCompare(candidate) == .orderedSame {
            return alias
        }
        return identifierQuoter.quoteIfNeeded(candidate)
    }

    func quotedColumn(_ name: String) -> String {
        identifierQuoter.quoteIfNeeded(name)
    }
}

struct SQLTableResolution {
    let schema: SQLSchema
    let object: SQLObject
}

struct SQLIdentifierContext {
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
