import Foundation

struct StarExpansionProvider: SQLSuggestionProvider {
    func suggestions(in context: SQLProviderContext) -> [SQLCompletionSuggestion] {
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
                        let qualifierText = context.qualifier(for: reference, candidate: qualifier)
                        let columnName = context.quotedColumn(column)
                        columnIdentifiers.append("\(qualifierText).\(columnName)")
                    } else {
                        columnIdentifiers.append(context.quotedColumn(column))
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
