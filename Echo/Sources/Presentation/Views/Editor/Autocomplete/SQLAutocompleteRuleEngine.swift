import Foundation
import SwiftUI
import EchoSense

struct SQLAutocompleteRuleEngine {
    struct Environment {
        var completionContext: SQLEditorCompletionContext?
    }

    struct SuppressionRequest {
        let query: SQLAutoCompletionQuery
        let selection: NSRange
        let caretLocation: Int
        let suggestions: [SQLAutoCompletionSuggestion]
        let tokenRange: NSRange
        let tokenText: String
        let clause: SQLClause
        let objectContextKeywords: Set<String>
        let columnContextKeywords: Set<String>
    }

    struct Suppression {
        var tokenRange: NSRange
        var canonicalText: String
        var hasFollowUps: Bool
    }

    struct SuppressionDiagnostics {
        var normalizedToken: String
        var components: [String]
        var matchedSuggestion: SQLAutoCompletionSuggestion?
        var matchedFromStructure: Bool
        var hasAlternativeObjects: Bool
        var hasColumnFollowUps: Bool
    }

    struct SuppressionResult {
        var suppression: Suppression
        var diagnostics: SuppressionDiagnostics
    }

    func buildSuppressionIfNeeded(request: SuppressionRequest,
                                  environment: Environment,
                                  trace: inout SQLAutocompleteTrace?) -> SuppressionResult? {
        func fail(_ reason: String) -> SuppressionResult? {
            trace?.addStep(title: "Suppression Aborted", details: [reason])
            trace?.setOutcome(.skipped(reason: reason))
            return nil
        }

        trace?.addStep(
            title: "Begin Suppression Evaluation",
            details: [
                "Token: \(request.tokenText)",
                "Caret: \(request.caretLocation)",
                "Selection length: \(request.selection.length)"
            ]
        )

        guard request.selection.length == 0 else {
            return fail("Selection is not collapsed")
        }
        guard request.caretLocation != NSNotFound else {
            return fail("Caret location is unknown")
        }
        guard request.tokenRange.length > 0 else {
            return fail("Token range is empty")
        }

        let trimmedToken = request.tokenText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            return fail("Token only contains whitespace")
        }
        trace?.setMetadataValue(trimmedToken, forKey: "trimmedToken")

        guard !trimmedToken.hasSuffix(".") else {
            return fail("Token ends with '.' so path is incomplete")
        }

        let rawComponents = trimmedToken
            .split(separator: ".", omittingEmptySubsequences: false)
            .map { SQLAutocompleteIdentifierTools.normalize(String($0)) }
        let components = rawComponents.map { $0.lowercased() }.filter { !$0.isEmpty }
        guard !components.isEmpty else {
            return fail("No identifier components after normalization")
        }
        trace?.addStep(title: "Identifier Components", details: components)

        guard let parts = SQLAutocompleteIdentifierTools.decompose(components) else {
            return fail("Unable to decompose identifier into database/schema/object")
        }

        let (typedDatabase, typedSchema, typedObject) = parts
        trace?.setMetadataValue(typedObject, forKey: "object")
        if let typedSchema {
            trace?.setMetadataValue(typedSchema, forKey: "schema")
        }
        if let typedDatabase {
            trace?.setMetadataValue(typedDatabase, forKey: "database")
        }

        var cachedStructureMatch: StructureObjectMatch?
        let objectKinds: Set<SQLAutoCompletionKind> = [.table, .view, .materializedView]

        let matchingSuggestion = request.suggestions.first { suggestion in
            guard objectKinds.contains(suggestion.kind) else { return false }
            let suggestionObject = (suggestion.origin?.object ?? suggestion.title).lowercased()
            guard suggestionObject == typedObject else { return false }

            if let typedSchema {
                guard let suggestionSchema = suggestion.origin?.schema?.lowercased(),
                      suggestionSchema == typedSchema else {
                    return false
                }
            }

            if let typedDatabase {
                guard let suggestionDatabase = suggestion.origin?.database?.lowercased(),
                      suggestionDatabase == typedDatabase else {
                    return false
                }
            }

            return true
        }

        let keyword = request.query.precedingKeyword?.lowercased()
        let clause = request.clause
        let clauseIsObjectContext: Bool = {
            switch clause {
            case .from, .joinTarget, .insertColumns, .deleteWhere, .withCTE:
                return true
            default:
                return false
            }
        }()
        let clauseIsColumnContext: Bool = {
            switch clause {
            case .selectList, .whereClause, .joinCondition, .having, .groupBy, .orderBy, .values, .updateSet:
                return true
            default:
                return false
            }
        }()
        let isObjectContext = clauseIsObjectContext || (keyword.map { request.objectContextKeywords.contains($0) } ?? false)
        let isColumnContext = clauseIsColumnContext || (keyword.map { request.columnContextKeywords.contains($0) } ?? false)

        let treatJoinHelpersAsAlternatives = clause == .joinTarget || keyword == "join"
        let hasJoinHelpers = treatJoinHelpersAsAlternatives && request.suggestions.contains { $0.kind == .join }

        if let match = matchingSuggestion {
            trace?.addStep(title: "Matching Suggestion Found", details: [match.title])
        } else {
            trace?.addStep(title: "No Engine Suggestion Match", details: ["Consulting structure metadata"])
            if !hasJoinHelpers {
                cachedStructureMatch = findStructureObject(
                    database: typedDatabase,
                    schema: typedSchema,
                    object: typedObject,
                    environment: environment
                )
                guard cachedStructureMatch != nil else {
                    return fail("Structure metadata did not contain the typed object")
                }
            }
        }

        let baseAlternativeObjects = request.suggestions.contains { candidate in
            guard matchingSuggestion != nil else { return false }
            guard objectKinds.contains(candidate.kind) else { return false }
            return !candidateMatchesObject(
                candidate,
                database: typedDatabase,
                schema: typedSchema,
                object: typedObject
            )
        }

        let hasAlternativeObjects = baseAlternativeObjects || hasJoinHelpers

        if hasAlternativeObjects {
            trace?.addStep(title: "Alternative Objects Available", details: ["Glow should consider additional tables/views"])
        }

        var hasColumns = false

        if let matchingSuggestion,
           isColumnContext || (!isObjectContext && keyword == nil) {
            hasColumns = hasColumnFollowUps(
                for: matchingSuggestion,
                in: request.suggestions,
                environment: environment
            )
        } else if isColumnContext || (!isObjectContext && keyword == nil) {
            if cachedStructureMatch == nil {
                cachedStructureMatch = findStructureObject(
                    database: typedDatabase,
                    schema: typedSchema,
                    object: typedObject,
                    environment: environment
                )
            }
            if let match = cachedStructureMatch {
                trace?.addStep(title: "Structure Column Inspection", details: ["Found \(match.object.columns.count) columns"])
                hasColumns = !match.object.columns.isEmpty
            }
        }

        var hasFollowUps: Bool
        if isColumnContext {
            hasFollowUps = hasColumns
        } else if isObjectContext {
            hasFollowUps = hasAlternativeObjects
        } else {
            hasFollowUps = hasColumns || hasAlternativeObjects
        }

        if !hasFollowUps {
            if isColumnContext {
                if cachedStructureMatch == nil {
                    cachedStructureMatch = findStructureObject(
                        database: typedDatabase,
                        schema: typedSchema,
                        object: typedObject,
                        environment: environment
                    )
                }
                if let structureMatch = cachedStructureMatch {
                    hasColumns = !structureMatch.object.columns.isEmpty
                    hasFollowUps = hasColumns
                }
            } else if !isObjectContext {
                if cachedStructureMatch == nil {
                    cachedStructureMatch = findStructureObject(
                        database: typedDatabase,
                        schema: typedSchema,
                        object: typedObject,
                        environment: environment
                    )
                }
                if let structureMatch = cachedStructureMatch,
                   !structureMatch.object.columns.isEmpty {
                    hasColumns = true
                    hasFollowUps = true
                }
            }
        }

        if !hasFollowUps && !hasAlternativeObjects && !hasColumns {
            return fail("No follow-up suggestions, columns, or alternative objects")
        }

        if matchingSuggestion == nil && cachedStructureMatch == nil && !hasJoinHelpers {
            return fail("Unable to resolve typed object from suggestions or structure metadata")
        }

        trace?.addStep(
            title: "Suppression Ready",
            details: [
                "hasFollowUps: \(hasFollowUps)",
                "hasColumns: \(hasColumns)",
                "hasAlternativeObjects: \(hasAlternativeObjects)"
            ]
        )

        let suppression = Suppression(
            tokenRange: request.tokenRange,
            canonicalText: request.tokenText,
            hasFollowUps: hasFollowUps
        )

        let diagnostics = SuppressionDiagnostics(
            normalizedToken: trimmedToken,
            components: components,
            matchedSuggestion: matchingSuggestion,
            matchedFromStructure: matchingSuggestion == nil,
            hasAlternativeObjects: hasAlternativeObjects,
            hasColumnFollowUps: hasColumns
        )

        let result = SuppressionResult(suppression: suppression, diagnostics: diagnostics)
        trace?.setOutcome(.produced(.init(from: result)))
        return result
    }

    func hasColumnFollowUps(for suggestion: SQLAutoCompletionSuggestion,
                            in suggestions: [SQLAutoCompletionSuggestion],
                            environment: Environment) -> Bool {
        if let tableColumns = suggestion.tableColumns, !tableColumns.isEmpty {
            return true
        }

        guard let components = objectComponents(for: suggestion) else {
            return false
        }
        let (databaseName, schemaName, objectName) = components

        if hasStructureFollowUps(database: databaseName,
                                 schema: schemaName,
                                 object: objectName,
                                 environment: environment) {
            return true
        }

        return suggestions.contains { candidate in
            guard candidate.kind == .column else { return false }
            guard let origin = candidate.origin else { return false }
            guard let originObject = origin.object?.lowercased(), originObject == objectName else { return false }
            if let schemaName {
                guard let originSchema = origin.schema?.lowercased(), originSchema == schemaName else { return false }
            }
            return true
        }
    }

    func fallbackSuggestions(for suppression: Suppression,
                             environment: Environment) -> [SQLAutoCompletionSuggestion]? {
        let canonical = suppression.canonicalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !canonical.isEmpty else { return nil }

        let rawComponents = canonical.split(separator: ".").map { SQLAutocompleteIdentifierTools.normalize(String($0)) }
        let components = rawComponents.map { $0.lowercased() }.filter { !$0.isEmpty }
        guard !components.isEmpty else { return nil }

        guard let (database, schema, object) = SQLAutocompleteIdentifierTools.decompose(components) else { return nil }
        guard let match = findStructureObject(database: database, schema: schema, object: object, environment: environment) else { return nil }
        guard let kind = sqlKind(for: match.object.type) else { return nil }

        var results: [SQLAutoCompletionSuggestion] = []
        let subtitleParts: [String] = {
            var values: [String] = []
            if !match.schema.name.isEmpty {
                values.append(match.schema.name)
            }
            if let db = match.database,
               let contextDB = environment.completionContext?.selectedDatabase,
               db.caseInsensitiveCompare(contextDB) != .orderedSame {
                values.append(db)
            }
            return values
        }()
        let subtitle = subtitleParts.isEmpty ? nil : subtitleParts.joined(separator: " • ")

        let tableColumns = match.object.columns.map {
            SQLAutoCompletionSuggestion.TableColumn(
                name: $0.name,
                dataType: $0.dataType,
                isNullable: $0.isNullable,
                isPrimaryKey: $0.isPrimaryKey
            )
        }

        let tableSuggestion = SQLAutoCompletionSuggestion(
            id: "suppressed:\(match.schema.name.lowercased()).\(match.object.name.lowercased())",
            title: match.object.name,
            subtitle: subtitle,
            detail: nil,
            insertText: canonical,
            kind: kind,
            origin: .init(database: match.database,
                          schema: match.schema.name,
                          object: match.object.name),
            dataType: nil,
            tableColumns: tableColumns.isEmpty ? nil : tableColumns,
            source: .fallback
        )
        results.append(tableSuggestion)

        for column in match.object.columns {
            let columnSuggestion = SQLAutoCompletionSuggestion(
                id: "suppressed-column:\(match.schema.name.lowercased()).\(match.object.name.lowercased()).\(column.name.lowercased())",
                title: column.name,
                subtitle: column.dataType.isEmpty ? nil : column.dataType,
                detail: nil,
                insertText: column.name,
                kind: .column,
                origin: .init(database: match.database,
                              schema: match.schema.name,
                              object: match.object.name,
                              column: column.name),
                dataType: column.dataType,
                source: .fallback
            )
            results.append(columnSuggestion)
        }

        return results
    }
}

// MARK: - EchoSense metadata bridging

extension EchoSenseDatabaseType {
    init(_ type: DatabaseType) {
        switch type {
        case .postgresql:
            self = .postgresql
        case .mysql:
            self = .mysql
        case .sqlite:
            self = .sqlite
        case .microsoftSQL:
            self = .microsoftSQL
        }
    }
}

extension DatabaseType {
    init(_ type: EchoSenseDatabaseType) {
        switch type {
        case .postgresql:
            self = .postgresql
        case .mysql:
            self = .mysql
        case .sqlite:
            self = .sqlite
        case .microsoftSQL:
            self = .microsoftSQL
        }
    }
}

extension EchoSenseSchemaObjectInfo.ObjectType {
    init(_ type: SchemaObjectInfo.ObjectType) {
        switch type {
        case .table:
            self = .table
        case .view:
            self = .view
        case .materializedView:
            self = .materializedView
        case .function, .procedure:
            self = .function
        case .trigger:
            self = .trigger
        case .procedure:
            self = .procedure
        }
    }
}

// MARK: - Trace Support

struct SQLAutocompleteTrace: Identifiable {
    enum Topic {
        case suppression
    }

    struct Step: Identifiable {
        let id = UUID()
        let title: String
        let details: [String]
    }

    struct SuppressionSummary {
        let canonicalText: String
        let hasFollowUps: Bool
        let diagnostics: [String: String]

        init(from result: SQLAutocompleteRuleEngine.SuppressionResult) {
            canonicalText = result.suppression.canonicalText
            hasFollowUps = result.suppression.hasFollowUps
            diagnostics = [
                "Normalized Token": result.diagnostics.normalizedToken,
                "Components": result.diagnostics.components.joined(separator: "."),
                "Matched Source": result.diagnostics.matchedFromStructure ? "Structure" : "Suggestion",
                "Alternative Objects": result.diagnostics.hasAlternativeObjects ? "Yes" : "No",
                "Column Follow-Ups": result.diagnostics.hasColumnFollowUps ? "Yes" : "No"
            ]
        }
    }

    enum Outcome {
        case produced(SuppressionSummary)
        case skipped(reason: String)
    }

    let id = UUID()
    let topic: Topic
    private(set) var metadata: [String: String]
    private(set) var steps: [Step] = []
    private(set) var outcome: Outcome?

    init(topic: Topic, metadata: [String: String] = [:]) {
        self.topic = topic
        self.metadata = metadata
    }

    mutating func addStep(title: String, details: [String] = []) {
        steps.append(Step(title: title, details: details))
    }

    mutating func setMetadataValue(_ value: String, forKey key: String) {
        metadata[key] = value
    }

    mutating func setOutcome(_ outcome: Outcome) {
        self.outcome = outcome
    }

    var metadataItems: [(String, String)] {
        metadata.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }

    var stepItems: [Step] { steps }
}

extension SQLAutocompleteTrace {
    static func suppression(request: SQLAutocompleteRuleEngine.SuppressionRequest) -> SQLAutocompleteTrace {
        var metadata: [String: String] = [
            "Token": request.tokenText,
            "Caret": "\(request.caretLocation)",
            "Selection": "loc=\(request.selection.location) len=\(request.selection.length)"
        ]
        if request.tokenRange.location != NSNotFound {
            metadata["Token Range"] = "loc=\(request.tokenRange.location) len=\(request.tokenRange.length)"
        }
        return SQLAutocompleteTrace(topic: .suppression, metadata: metadata)
    }
}

// MARK: - Identifier Helpers

enum SQLAutocompleteIdentifierTools {
    static func normalize(_ value: String) -> String {
        var identifier = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let spaceIndex = identifier.firstIndex(where: { $0.isWhitespace }) {
            identifier = String(identifier[..<spaceIndex])
        }
        identifier = identifier.trimmingCharacters(in: CharacterSet(charactersIn: ",;()"))
        let removable: Set<Character> = ["\"", "'", "[", "]", "`"]
        identifier.removeAll(where: { removable.contains($0) })
        return identifier
    }

    static func decompose(_ components: [String]) -> (database: String?, schema: String?, object: String)? {
        guard let object = components.last, !object.isEmpty else { return nil }
        let schema = components.dropLast().last.flatMap { $0.isEmpty ? nil : $0 }
        let database = components.dropLast(2).last.flatMap { $0.isEmpty ? nil : $0 }
        return (database, schema, object)
    }
}

// MARK: - Private Helpers

private extension SQLAutocompleteRuleEngine {
    struct StructureObjectMatch {
        let database: String?
        let schema: EchoSenseSchemaInfo
        let object: EchoSenseSchemaObjectInfo
    }

    func candidateMatchesObject(_ candidate: SQLAutoCompletionSuggestion,
                                database typedDatabase: String?,
                                schema typedSchema: String?,
                                object typedObject: String) -> Bool {
        let candidateObject = (candidate.origin?.object ?? candidate.title).lowercased()
        guard candidateObject == typedObject else { return false }

        if let typedSchema {
            let candidateSchema = candidate.origin?.schema?.lowercased()
            if candidateSchema != typedSchema {
                return false
            }
        }

        if let typedDatabase {
            let candidateDatabase = candidate.origin?.database?.lowercased()
            if candidateDatabase != typedDatabase {
                return false
            }
        }

        return true
    }

    func objectComponents(for suggestion: SQLAutoCompletionSuggestion) -> (database: String?, schema: String?, object: String)? {
        let rawObject = (suggestion.origin?.object ?? suggestion.title).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawObject.isEmpty else { return nil }
        let object = rawObject.lowercased()

        let schema = suggestion.origin?.schema?.trimmingCharacters(in: .whitespacesAndNewlines)
        let database = suggestion.origin?.database?.trimmingCharacters(in: .whitespacesAndNewlines)

        return (database?.isEmpty == true ? nil : database?.lowercased(),
                schema?.isEmpty == true ? nil : schema?.lowercased(),
                object)
    }

    func hasStructureFollowUps(database: String?,
                               schema: String?,
                               object: String,
                               environment: Environment) -> Bool {
        guard let match = findStructureObject(database: database,
                                              schema: schema,
                                              object: object,
                                              environment: environment) else {
            return false
        }
        return !match.object.columns.isEmpty
    }

    func findStructureObject(database: String?,
                             schema: String?,
                             object: String,
                             environment: Environment) -> StructureObjectMatch? {
        guard let context = environment.completionContext,
              let structure = context.structure else { return nil }

        let requestedDatabase = database ?? context.selectedDatabase?.lowercased()
        let preferredSchema = schema ?? context.defaultSchema?.lowercased()

        var fallbackMatch: StructureObjectMatch?

        for databaseInfo in structure.databases {
            if let requestedDatabase,
               databaseInfo.name.lowercased() != requestedDatabase { continue }

            for schemaInfo in databaseInfo.schemas {
                let schemaLower = schemaInfo.name.lowercased()
                if let schema, schemaLower != schema { continue }

                if let match = schemaInfo.objects.first(where: { $0.name.lowercased() == object }) {
                    if let schema, schemaLower == schema {
                        return StructureObjectMatch(database: databaseInfo.name,
                                                     schema: schemaInfo,
                                                     object: match)
                    }
                    if let preferredSchema, schemaLower == preferredSchema {
                        return StructureObjectMatch(database: databaseInfo.name,
                                                     schema: schemaInfo,
                                                     object: match)
                    }
                    if fallbackMatch == nil {
                        fallbackMatch = StructureObjectMatch(database: databaseInfo.name,
                                                             schema: schemaInfo,
                                                             object: match)
                    }
                }
            }
        }

        return fallbackMatch
    }

    func sqlKind(for type: EchoSenseSchemaObjectInfo.ObjectType) -> SQLAutoCompletionKind? {
        switch type {
        case .table: return .table
        case .view: return .view
        case .materializedView: return .materializedView
        case .function, .trigger, .procedure:
            return nil
        }
    }
}

struct SQLAutocompleteRuleTraceConfiguration {
    var isEnabled: Bool
    var onTrace: (SQLAutocompleteTrace) -> Void

    init(isEnabled: Bool = true, onTrace: @escaping (SQLAutocompleteTrace) -> Void) {
        self.isEnabled = isEnabled
        self.onTrace = onTrace
    }
}
