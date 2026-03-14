import Foundation
import EchoSense

struct SQLAutocompleteRuleEngine {
    struct StructureObjectMatch {
        let database: String?
        let schema: EchoSenseSchemaInfo
        let object: EchoSenseSchemaObjectInfo
    }

    func fallbackSuggestions(
        for suppression: SQLAutocompleteRuleModels.Suppression,
        environment: SQLAutocompleteRuleModels.Environment
    ) -> [SQLAutoCompletionSuggestion]? {
        let canonical = suppression.canonicalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !canonical.isEmpty else { return nil }

        let components = canonical.split(separator: ".").map { SQLAutocompleteIdentifierTools.normalize(String($0)).lowercased() }.filter { !$0.isEmpty }
        guard !components.isEmpty else { return nil }

        guard let (database, schema, object) = SQLAutocompleteIdentifierTools.decompose(components) else { return nil }
        guard let match = findStructureObject(database: database, schema: schema, object: object, environment: environment) else { return nil }
        guard let kind = sqlKind(for: match.object.type) else { return nil }

        var results: [SQLAutoCompletionSuggestion] = []
        let subtitleParts: [String] = {
            var values: [String] = []
            if !match.schema.name.isEmpty { values.append(match.schema.name) }
            if let db = match.database, let contextDB = environment.completionContext?.selectedDatabase, db.caseInsensitiveCompare(contextDB) != .orderedSame {
                values.append(db)
            }
            return values
        }()
        let subtitle = subtitleParts.isEmpty ? nil : subtitleParts.joined(separator: " • ")

        let tableColumns = match.object.columns.map {
            SQLAutoCompletionSuggestion.TableColumn(name: $0.name, dataType: $0.dataType, isNullable: $0.isNullable, isPrimaryKey: $0.isPrimaryKey)
        }

        results.append(SQLAutoCompletionSuggestion(
            id: "suppressed:\(match.schema.name.lowercased()).\(match.object.name.lowercased())",
            title: match.object.name, subtitle: subtitle, insertText: canonical, kind: kind,
            origin: .init(database: match.database, schema: match.schema.name, object: match.object.name),
            tableColumns: tableColumns.isEmpty ? nil : tableColumns, source: .fallback
        ))

        for column in match.object.columns {
            results.append(SQLAutoCompletionSuggestion(
                id: "suppressed-column:\(match.schema.name.lowercased()).\(match.object.name.lowercased()).\(column.name.lowercased())",
                title: column.name, subtitle: column.dataType.isEmpty ? nil : column.dataType, insertText: column.name, kind: .column,
                origin: .init(database: match.database, schema: match.schema.name, object: match.object.name, column: column.name),
                dataType: column.dataType, source: .fallback
            ))
        }

        return results
    }

    private func sqlKind(for type: EchoSenseSchemaObjectInfo.ObjectType) -> SQLAutoCompletionKind? {
        switch type {
        case .table: return .table
        case .view: return .view
        case .materializedView: return .materializedView
        default: return nil
        }
    }
}

// MARK: - EchoSense metadata bridging

extension EchoSenseDatabaseType {
    init(_ type: DatabaseType) {
        switch type {
        case .postgresql: self = .postgresql
        case .mysql: self = .mysql
        case .sqlite: self = .sqlite
        case .microsoftSQL: self = .microsoftSQL
        }
    }
}

extension DatabaseType {
    init(_ type: EchoSenseDatabaseType) {
        switch type {
        case .postgresql: self = .postgresql
        case .mysql: self = .mysql
        case .sqlite: self = .sqlite
        case .microsoftSQL: self = .microsoftSQL
        }
    }
}

extension EchoSenseSchemaObjectInfo.ObjectType {
    init(_ type: SchemaObjectInfo.ObjectType) {
        switch type {
        case .table: self = .table
        case .view: self = .view
        case .materializedView: self = .materializedView
        case .function: self = .function
        case .trigger: self = .trigger
        case .procedure: self = .procedure
        case .extension: self = .function
        }
    }
}
