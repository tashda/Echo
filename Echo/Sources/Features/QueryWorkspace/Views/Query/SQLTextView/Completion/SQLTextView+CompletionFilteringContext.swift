#if os(macOS)
import AppKit
import EchoSense

extension SQLTextView {
    private struct UsedColumnContext {
        var byKey: [String: Set<String>]
        var unqualified: Set<String>
    }

    internal func buildUsedColumnContextForFiltering(before caretLocation: Int, query: SQLAutoCompletionQuery) -> (byKey: [String: Set<String>], unqualified: Set<String>)? {
        guard caretLocation != NSNotFound else { return nil }
        let nsString = string as NSString
        let clampedLocation = min(max(caretLocation, 0), nsString.length)

        let searchSelectRange = NSRange(location: 0, length: clampedLocation)
        let selectRange = nsString.range(of: "select", options: [.caseInsensitive, .backwards], range: searchSelectRange)
        guard selectRange.location != NSNotFound else { return nil }

        let fromSearchRange = NSRange(location: selectRange.upperBound, length: nsString.length - selectRange.upperBound)
        let fromRange = nsString.range(of: "from", options: [.caseInsensitive], range: fromSearchRange)

        let segmentEnd = fromRange.location != NSNotFound ? fromRange.location : nsString.length
        guard segmentEnd > selectRange.upperBound else { return nil }

        let segmentRange = NSRange(location: selectRange.upperBound, length: segmentEnd - selectRange.upperBound)
        let segment = nsString.substring(with: segmentRange)
        var byKey: [String: Set<String>] = [:]
        var unqualified: Set<String> = []
        let scopeTables = query.tablesInScope

        for part in segment.split(separator: ",") {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard let identifier = leadingIdentifierForFiltering(in: trimmed) else { continue }
            let loweredIdentifier = identifier.lowercased()
            let components = loweredIdentifier.split(separator: ".", omittingEmptySubsequences: true)
            guard let columnComponent = components.last else { continue }
            let columnName = String(columnComponent)

            if components.count > 1 {
                let qualifierComponent = components[components.count - 2]
                let qualifier = String(qualifierComponent)
                if let aliasKeyValue = aliasKeyForFiltering(qualifier) {
                    byKey[aliasKeyValue, default: []].insert(columnName)
                }
                if let focus = tableFocusForFiltering(forQualifier: qualifier, in: scopeTables) {
                    let key = tableKeyForFiltering(for: focus)
                    byKey[key, default: []].insert(columnName)
                    if let alias = focus.alias, let focusAliasKey = aliasKeyForFiltering(alias) {
                        byKey[focusAliasKey, default: []].insert(columnName)
                    }
                }
            } else {
                unqualified.insert(columnName)
                if scopeTables.count == 1 {
                    let focus = scopeTables[0]
                    let key = tableKeyForFiltering(for: focus)
                    byKey[key, default: []].insert(columnName)
                    if let alias = focus.alias, let focusAliasKey = aliasKeyForFiltering(alias) {
                        byKey[focusAliasKey, default: []].insert(columnName)
                    }
                }
            }
        }

        return byKey.isEmpty && unqualified.isEmpty ? nil : (byKey: byKey, unqualified: unqualified)
    }

    private func leadingIdentifierForFiltering(in expression: String) -> String? {
        var buffer = ""
        for character in expression {
            if character.isLetter || character.isNumber || character == "_" || character == "." || character == "\"" || character == "`" || character == "[" || character == "]" {
                buffer.append(character)
            } else {
                break
            }
        }
        guard !buffer.isEmpty else { return nil }
        let normalized = normalizeIdentifier(buffer)
        return normalized.isEmpty ? nil : normalized
    }

    private func tableFocusForFiltering(forQualifier qualifier: String, in tables: [SQLAutoCompletionTableFocus]) -> SQLAutoCompletionTableFocus? {
        let normalizedQualifier = normalizeIdentifier(qualifier).lowercased()
        if let aliasMatch = tables.first(where: { $0.alias?.lowercased() == normalizedQualifier }) {
            return aliasMatch
        }
        if let nameMatch = tables.first(where: { $0.name.lowercased() == normalizedQualifier }) {
            return nameMatch
        }
        return nil
    }

    private func tableKeyForFiltering(for focus: SQLAutoCompletionTableFocus) -> String {
        tableKeyForFiltering(schema: focus.schema, name: focus.name)
    }

    private func tableKeyForFiltering(schema: String?, name: String) -> String {
        let schemaComponent = schema.map { normalizeIdentifier($0).lowercased() } ?? ""
        let nameComponent = normalizeIdentifier(name).lowercased()
        return "\(schemaComponent)|\(nameComponent)"
    }

    private func aliasKeyForFiltering(_ alias: String) -> String? {
        let normalized = normalizeIdentifier(alias).lowercased()
        return normalized.isEmpty ? nil : "alias:\(normalized)"
    }

    internal func aliasKeysForFiltering(for origin: SQLAutoCompletionSuggestion.Origin, tables: [SQLAutoCompletionTableFocus]) -> [String] {
        guard let object = origin.object else { return [] }
        let objectName = normalizeIdentifier(object).lowercased()
        let schemaName = origin.schema.map { normalizeIdentifier($0).lowercased() }
        return tables.compactMap { focus in
            guard normalizeIdentifier(focus.name).lowercased() == objectName else { return nil }
            if let schemaName,
               let focusSchema = focus.schema.map({ normalizeIdentifier($0).lowercased() }),
               focusSchema != schemaName {
                return nil
            }
            guard let alias = focus.alias, let key = aliasKeyForFiltering(alias) else { return nil }
            return key
        }
    }

    internal func candidateColumnKeysForFiltering(for suggestion: SQLAutoCompletionSuggestion, query: SQLAutoCompletionQuery) -> [String] {
        var keys: Set<String> = []

        if let origin = suggestion.origin,
           let object = origin.object, !object.isEmpty {
            keys.insert(tableKeyForFiltering(schema: origin.schema, name: object))
            aliasKeysForFiltering(for: origin, tables: query.tablesInScope).forEach { keys.insert($0) }
        }

        let normalizedInsert = normalizeIdentifier(suggestion.insertText).lowercased()
        let components = normalizedInsert.split(separator: ".", omittingEmptySubsequences: true)
        if components.count > 1 {
            let qualifier = String(components[components.count - 2])
            if let qualifierKey = aliasKeyForFiltering(qualifier) {
                keys.insert(qualifierKey)
            }
            if let focus = tableFocusForFiltering(forQualifier: qualifier, in: query.tablesInScope) {
                keys.insert(tableKeyForFiltering(for: focus))
                if let alias = focus.alias, let focusAliasKey = aliasKeyForFiltering(alias) {
                    keys.insert(focusAliasKey)
                }
            }
        }

        return Array(keys)
    }

    internal func normalizedColumnNameForFiltering(for suggestion: SQLAutoCompletionSuggestion) -> String? {
        if let column = suggestion.origin?.column, !column.isEmpty {
            return normalizeIdentifier(column).lowercased()
        }
        let normalized = normalizeIdentifier(suggestion.insertText)
        let components = normalized.split(separator: ".", omittingEmptySubsequences: true)
        guard let last = components.last else { return nil }
        return String(last).lowercased()
    }
}
#endif
