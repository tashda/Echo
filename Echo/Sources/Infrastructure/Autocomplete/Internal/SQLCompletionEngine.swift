import Foundation

final class SQLCompletionEngine: SQLCompletionEngineProtocol {
    private let builderFactory: SQLSuggestionBuilderFactory

    init(builderFactory: SQLSuggestionBuilderFactory = DefaultSuggestionBuilderFactory()) {
        self.builderFactory = builderFactory
    }

    func completions(for request: SQLCompletionRequest) -> SQLCompletionResult {
        guard request.caretLocation >= 0, request.caretLocation <= request.text.count else {
            return SQLCompletionResult(suggestions: [])
        }

        guard let catalog = request.metadata.catalog(for: request.selectedDatabase) else {
            return SQLCompletionResult(suggestions: [])
        }

        let parser = SQLContextParser(text: request.text,
                                      caretLocation: request.caretLocation,
                                      dialect: request.dialect,
                                      catalog: catalog)
        let context = parser.parse()

        let builder = builderFactory.makeBuilder(for: request.dialect)
        let suggestions = builder.buildSuggestions(context: context,
                                                   request: request,
                                                   catalog: catalog)
            .sorted { lhs, rhs in
                if lhs.priority == rhs.priority {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.priority > rhs.priority
            }

        return SQLCompletionResult(suggestions: suggestions)
    }
}
