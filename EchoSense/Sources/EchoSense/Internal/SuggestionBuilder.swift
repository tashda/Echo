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
    private let providers: [SQLSuggestionProvider]

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
        let identifier = SQLIdentifierContext(token: context.currentToken)
        let quoter = SQLIdentifierQuoter.forDialect(request.dialect)
        let providerContext = SQLProviderContext(sqlContext: context,
                                              request: request,
                                              catalog: catalog,
                                              identifier: identifier,
                                              dialect: dialect,
                                              keywordProvider: keywordProvider,
                                              identifierQuoter: quoter)

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
