import Foundation
import PostgresKit

/// PostgreSQL implementation of the trigger editor dialect.
/// Uses postgres-wire typed metadata APIs — no raw SQL in Echo.
struct PostgresTriggerDialect: TriggerEditorDialect, Sendable {

    var supportsTruncateEvent: Bool { true }
    var supportsWhenCondition: Bool { true }
    var supportsInsteadOfTiming: Bool { true }
    var supportsForEach: Bool { true }
    var supportsFunctionReference: Bool { true }
    var supportsEnableDisable: Bool { true }
    var supportsComments: Bool { true }

    func loadMetadata(session: any DatabaseSession, schema: String, table: String, name: String) async throws -> TriggerEditorMetadata {
        guard let pg = session as? PostgresSession else {
            throw ViewEditorDialectError.unsupportedSession
        }

        var metadata = TriggerEditorMetadata(
            name: name, functionName: "", timing: .after, forEach: .row,
            onInsert: true, onUpdate: false, onDelete: false, onTruncate: false,
            whenCondition: "", isEnabled: true, description: ""
        )

        guard let details = try await pg.client.metadata.triggerDetails(schema: schema, table: table, name: name) else {
            return metadata
        }

        metadata.functionName = details.functionSchema == schema
            ? details.functionName
            : "\(details.functionSchema).\(details.functionName)"
        metadata.isEnabled = details.isEnabled
        metadata.description = details.comment ?? ""

        parseTriggerDefinition(details.definition, metadata: &metadata)

        return metadata
    }

    func generateSQL(context: TriggerEditorSQLContext) -> String {
        let qualifiedTable = "\(quoteIdentifier(context.schema)).\(quoteIdentifier(context.table))"
        let qualifiedFunc = context.functionName.contains("(") ? context.functionName : "\(context.functionName)()"

        var events: [String] = []
        if context.onInsert { events.append("INSERT") }
        if context.onUpdate { events.append("UPDATE") }
        if context.onDelete { events.append("DELETE") }
        if context.onTruncate { events.append("TRUNCATE") }

        var sql = ""
        if context.isEditing {
            sql += "DROP TRIGGER IF EXISTS \(quoteIdentifier(context.name)) ON \(qualifiedTable);\n\n"
        }

        sql += "CREATE TRIGGER \(quoteIdentifier(context.name))"
        sql += "\n    \(context.timing.rawValue) \(events.joined(separator: " OR "))"
        sql += "\n    ON \(qualifiedTable)"
        sql += "\n    FOR EACH \(context.forEach.rawValue)"

        let whenTrimmed = context.whenCondition.trimmingCharacters(in: .whitespacesAndNewlines)
        if !whenTrimmed.isEmpty { sql += "\n    WHEN (\(whenTrimmed))" }
        sql += "\n    EXECUTE FUNCTION \(qualifiedFunc);"

        if !context.isEnabled && context.isEditing {
            sql += "\n\nALTER TABLE \(qualifiedTable) DISABLE TRIGGER \(quoteIdentifier(context.name));"
        }

        if !context.description.isEmpty {
            let escaped = context.description.replacingOccurrences(of: "'", with: "''")
            sql += "\n\nCOMMENT ON TRIGGER \(quoteIdentifier(context.name)) ON \(qualifiedTable) IS '\(escaped)';"
        }

        return sql
    }

    func quoteIdentifier(_ identifier: String) -> String {
        let escaped = identifier.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func parseTriggerDefinition(_ definition: String, metadata: inout TriggerEditorMetadata) {
        let upper = definition.uppercased()
        if upper.contains("BEFORE") { metadata.timing = .before }
        else if upper.contains("INSTEAD OF") { metadata.timing = .insteadOf }
        else { metadata.timing = .after }

        metadata.onInsert = upper.contains("INSERT")
        metadata.onUpdate = upper.contains("UPDATE")
        metadata.onDelete = upper.contains("DELETE")
        metadata.onTruncate = upper.contains("TRUNCATE")

        metadata.forEach = upper.contains("FOR EACH STATEMENT") ? .statement : .row

        if let whenRange = definition.range(of: "WHEN (", options: .caseInsensitive) {
            let afterWhen = definition[whenRange.upperBound...]
            var depth = 1
            var endIndex = afterWhen.startIndex
            for i in afterWhen.indices {
                if afterWhen[i] == "(" { depth += 1 }
                else if afterWhen[i] == ")" {
                    depth -= 1
                    if depth == 0 { endIndex = i; break }
                }
            }
            metadata.whenCondition = String(afterWhen[afterWhen.startIndex..<endIndex])
        }
    }
}
