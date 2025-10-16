import Foundation

final class SQLCompletionEngine: SQLCompletionEngineProtocol {
    private let builderFactory: SQLSuggestionBuilderFactory

    init(builderFactory: SQLSuggestionBuilderFactory = DefaultSuggestionBuilderFactory()) {
        self.builderFactory = builderFactory
    }

    func completions(for request: SQLCompletionRequest) -> SQLCompletionResult {
        guard request.caretLocation >= 0, request.caretLocation <= request.text.count else {
            return SQLCompletionResult(suggestions: [], metadata: .init(clause: .unknown,
                                                                        currentToken: "",
                                                                        precedingKeyword: nil,
                                                                        pathComponents: [],
                                                                        tablesInScope: [],
                                                                        focusTable: nil,
                                                                        cteColumns: [:]))
        }

        guard let catalog = request.metadata.catalog(for: request.selectedDatabase) else {
            return SQLCompletionResult(suggestions: [], metadata: .init(clause: .unknown,
                                                                        currentToken: "",
                                                                        precedingKeyword: nil,
                                                                        pathComponents: [],
                                                                        tablesInScope: [],
                                                                        focusTable: nil,
                                                                        cteColumns: [:]))
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

        let metadata = SQLCompletionMetadata(
            clause: context.clause,
            currentToken: context.currentToken,
            precedingKeyword: context.precedingKeyword,
            pathComponents: context.pathComponents,
            tablesInScope: context.tablesInScope.map { ref in
                SQLCompletionMetadata.TableReference(schema: ref.schema,
                                                     name: ref.name,
                                                     alias: ref.alias)
            },
            focusTable: context.focusTable.map { ref in
                SQLCompletionMetadata.TableReference(schema: ref.schema,
                                                     name: ref.name,
                                                     alias: ref.alias)
            },
            cteColumns: context.cteColumns
        )

        return SQLCompletionResult(suggestions: suggestions, metadata: metadata)
    }
}
