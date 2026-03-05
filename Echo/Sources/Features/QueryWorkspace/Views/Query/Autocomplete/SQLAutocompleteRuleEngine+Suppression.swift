import Foundation
import EchoSense

extension SQLAutocompleteRuleEngine {
    func buildSuppressionIfNeeded(
        request: SQLAutocompleteRuleModels.SuppressionRequest,
        environment: SQLAutocompleteRuleModels.Environment,
        trace: inout SQLAutocompleteTrace?
    ) -> SQLAutocompleteRuleModels.SuppressionResult? {
        func fail(_ reason: String) -> SQLAutocompleteRuleModels.SuppressionResult? {
            trace?.addStep(title: "Suppression Aborted", details: [reason])
            trace?.setOutcome(.skipped(reason: reason))
            return nil
        }

        trace?.addStep(
            title: "Begin Suppression Evaluation",
            details: ["Token: \(request.tokenText)", "Caret: \(request.caretLocation)", "Selection length: \(request.selection.length)"]
        )

        guard request.selection.length == 0, request.caretLocation != NSNotFound, request.tokenRange.length > 0 else {
            return fail("Invalid selection or token range")
        }

        let trimmedToken = request.tokenText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty, !trimmedToken.hasSuffix(".") else {
            return fail("Invalid token suffix or empty")
        }

        let components = trimmedToken.split(separator: ".", omittingEmptySubsequences: false)
            .map { SQLAutocompleteIdentifierTools.normalize(String($0)).lowercased() }
            .filter { !$0.isEmpty }
        
        guard let parts = SQLAutocompleteIdentifierTools.decompose(components) else {
            return fail("Unable to decompose identifier")
        }

        let (typedDatabase, typedSchema, typedObject) = parts
        var cachedStructureMatch: StructureObjectMatch?
        let objectKinds: Set<SQLAutoCompletionKind> = [.table, .view, .materializedView]

        let matchingSuggestion = request.suggestions.first { suggestion in
            guard objectKinds.contains(suggestion.kind) else { return false }
            let suggestionObject = (suggestion.origin?.object ?? suggestion.title).lowercased()
            guard suggestionObject == typedObject else { return false }
            if let typedSchema {
                guard let suggestionSchema = suggestion.origin?.schema?.lowercased(), suggestionSchema == typedSchema else { return false }
            }
            if let typedDatabase {
                guard let suggestionDatabase = suggestion.origin?.database?.lowercased(), suggestionDatabase == typedDatabase else { return false }
            }
            return true
        }

        let keyword = request.query.precedingKeyword?.lowercased()
        let isObjectContext = isObjectContext(clause: request.clause, keyword: keyword, keywords: request.objectContextKeywords)
        let isColumnContext = isColumnContext(clause: request.clause, keyword: keyword, keywords: request.columnContextKeywords)

        let hasJoinHelpers = (request.clause == .joinTarget || keyword == "join") && request.suggestions.contains { $0.kind == .join }

        if matchingSuggestion == nil && !hasJoinHelpers {
            cachedStructureMatch = findStructureObject(database: typedDatabase, schema: typedSchema, object: typedObject, environment: environment)
            guard cachedStructureMatch != nil else { return fail("No structure match") }
        }

        let hasAlternativeObjects = hasJoinHelpers || request.suggestions.contains { candidate in
            guard matchingSuggestion != nil, objectKinds.contains(candidate.kind) else { return false }
            return !candidateMatchesObject(candidate, database: typedDatabase, schema: typedSchema, object: typedObject)
        }

        var hasColumns = false
        if let matchingSuggestion, isColumnContext || (!isObjectContext && keyword == nil) {
            hasColumns = hasColumnFollowUps(for: matchingSuggestion, in: request.suggestions, environment: environment)
        } else if isColumnContext || (!isObjectContext && keyword == nil) {
            if cachedStructureMatch == nil { cachedStructureMatch = findStructureObject(database: typedDatabase, schema: typedSchema, object: typedObject, environment: environment) }
            if let match = cachedStructureMatch { hasColumns = !match.object.columns.isEmpty }
        }

        let hasFollowUps = isColumnContext ? hasColumns : (isObjectContext ? hasAlternativeObjects : (hasColumns || hasAlternativeObjects))
        
        if !hasFollowUps && matchingSuggestion == nil && cachedStructureMatch == nil && !hasJoinHelpers {
            return fail("No resolution path found")
        }

        let result = SQLAutocompleteRuleModels.SuppressionResult(
            suppression: .init(tokenRange: request.tokenRange, canonicalText: request.tokenText, hasFollowUps: hasFollowUps),
            diagnostics: .init(normalizedToken: trimmedToken, components: components, matchedSuggestion: matchingSuggestion, matchedFromStructure: matchingSuggestion == nil, hasAlternativeObjects: hasAlternativeObjects, hasColumnFollowUps: hasColumns)
        )
        trace?.setOutcome(.produced(.init(from: result)))
        return result
    }

    private func isObjectContext(clause: SQLClause, keyword: String?, keywords: Set<String>) -> Bool {
        switch clause {
        case .from, .joinTarget, .insertColumns, .deleteWhere, .withCTE: return true
        default: return keyword.map { keywords.contains($0) } ?? false
        }
    }

    private func isColumnContext(clause: SQLClause, keyword: String?, keywords: Set<String>) -> Bool {
        switch clause {
        case .selectList, .whereClause, .joinCondition, .having, .groupBy, .orderBy, .values, .updateSet: return true
        default: return keyword.map { keywords.contains($0) } ?? false
        }
    }

    func candidateMatchesObject(_ candidate: SQLAutoCompletionSuggestion, database typedDatabase: String?, schema typedSchema: String?, object typedObject: String) -> Bool {
        let candidateObject = (candidate.origin?.object ?? candidate.title).lowercased()
        guard candidateObject == typedObject else { return false }
        if let typedSchema, candidate.origin?.schema?.lowercased() != typedSchema { return false }
        if let typedDatabase, candidate.origin?.database?.lowercased() != typedDatabase { return false }
        return true
    }

    func findStructureObject(database: String?, schema: String?, object: String, environment: SQLAutocompleteRuleModels.Environment) -> StructureObjectMatch? {
        guard let context = environment.completionContext, let structure = context.structure else { return nil }
        let requestedDatabase = database ?? context.selectedDatabase?.lowercased()
        let preferredSchema = schema ?? context.defaultSchema?.lowercased()
        var fallback: StructureObjectMatch?
        for db in structure.databases {
            if let requestedDatabase, db.name.lowercased() != requestedDatabase { continue }
            for sch in db.schemas {
                let schLower = sch.name.lowercased()
                if let schema, schLower != schema { continue }
                if let match = sch.objects.first(where: { $0.name.lowercased() == object }) {
                    let res = StructureObjectMatch(database: db.name, schema: sch, object: match)
                    if let schema, schLower == schema { return res }
                    if let preferredSchema, schLower == preferredSchema { return res }
                    if fallback == nil { fallback = res }
                }
            }
        }
        return fallback
    }

    func hasColumnFollowUps(for suggestion: SQLAutoCompletionSuggestion, in suggestions: [SQLAutoCompletionSuggestion], environment: SQLAutocompleteRuleModels.Environment) -> Bool {
        if let cols = suggestion.tableColumns, !cols.isEmpty { return true }
        guard let comp = objectComponents(for: suggestion) else { return false }
        if hasStructureFollowUps(database: comp.database, schema: comp.schema, object: comp.object, environment: environment) { return true }
        return suggestions.contains { $0.kind == .column && $0.origin?.object?.lowercased() == comp.object && (comp.schema == nil || $0.origin?.schema?.lowercased() == comp.schema) }
    }

    func objectComponents(for suggestion: SQLAutoCompletionSuggestion) -> (database: String?, schema: String?, object: String)? {
        let raw = (suggestion.origin?.object ?? suggestion.title).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        return (suggestion.origin?.database?.lowercased(), suggestion.origin?.schema?.lowercased(), raw.lowercased())
    }

    func hasStructureFollowUps(database: String?, schema: String?, object: String, environment: SQLAutocompleteRuleModels.Environment) -> Bool {
        findStructureObject(database: database, schema: schema, object: object, environment: environment).map { !$0.object.columns.isEmpty } ?? false
    }
}

enum SQLAutocompleteIdentifierTools {
    static func normalize(_ value: String) -> String {
        var id = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let space = id.firstIndex(where: { $0.isWhitespace }) { id = String(id[..<space]) }
        id = id.trimmingCharacters(in: CharacterSet(charactersIn: ",;()"))
        id.removeAll(where: { ("\"'[]`").contains($0) })
        return id
    }
    static func decompose(_ components: [String]) -> (database: String?, schema: String?, object: String)? {
        guard let object = components.last, !object.isEmpty else { return nil }
        return (components.dropLast(2).last, components.dropLast().last, object)
    }
}
