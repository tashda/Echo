import Foundation
import PostgresKit

/// PostgreSQL implementation of the sequence editor dialect.
/// Uses postgres-wire typed metadata APIs — no raw SQL in Echo.
struct PostgresSequenceDialect: SequenceEditorDialect, Sendable {

    var supportsOwnership: Bool { true }
    var supportsOwnedBy: Bool { true }
    var supportsCache: Bool { true }
    var supportsComments: Bool { true }

    func loadMetadata(session: any DatabaseSession, schema: String, name: String) async throws -> SequenceEditorMetadata {
        guard let pg = session as? PostgresSession else {
            throw ViewEditorDialectError.unsupportedSession
        }

        guard let details = try await pg.client.metadata.sequenceDetails(schema: schema, name: name) else {
            return SequenceEditorMetadata(
                name: name, startWith: "1", incrementBy: "1", minValue: "", maxValue: "",
                cache: "1", cycle: false, owner: "", ownedBy: "", lastValue: "", description: ""
            )
        }

        return SequenceEditorMetadata(
            name: details.name,
            startWith: details.startValue,
            incrementBy: details.incrementBy,
            minValue: details.minValue,
            maxValue: details.maxValue,
            cache: details.cache,
            cycle: details.isCycling,
            owner: details.owner,
            ownedBy: "",
            lastValue: details.lastValue ?? "\u{2014}",
            description: details.comment ?? ""
        )
    }

    func generateSQL(context: SequenceEditorSQLContext) -> String {
        let qualifiedName = "\(quoteIdentifier(context.schema)).\(quoteIdentifier(context.name))"
        if context.isEditing {
            return generateAlterSQL(qualified: qualifiedName, context: context)
        } else {
            return generateCreateSQL(qualified: qualifiedName, context: context)
        }
    }

    func quoteIdentifier(_ identifier: String) -> String {
        let escaped = identifier.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func generateCreateSQL(qualified: String, context: SequenceEditorSQLContext) -> String {
        var parts: [String] = ["CREATE SEQUENCE \(qualified)"]
        if let start = Int(context.startWith), start != 1 { parts.append("    START WITH \(start)") }
        if let inc = Int(context.incrementBy), inc != 1 { parts.append("    INCREMENT BY \(inc)") }
        if let min = Int(context.minValue) { parts.append("    MINVALUE \(min)") }
        if let max = Int(context.maxValue) { parts.append("    MAXVALUE \(max)") }
        if let c = Int(context.cache), c != 1 { parts.append("    CACHE \(c)") }
        if context.cycle { parts.append("    CYCLE") }
        var sql = parts.joined(separator: "\n") + ";"
        if !context.description.isEmpty {
            let escaped = context.description.replacingOccurrences(of: "'", with: "''")
            sql += "\n\nCOMMENT ON SEQUENCE \(qualified) IS '\(escaped)';"
        }
        return sql
    }

    private func generateAlterSQL(qualified: String, context: SequenceEditorSQLContext) -> String {
        var alterParts: [String] = []
        if let inc = Int(context.incrementBy) { alterParts.append("INCREMENT BY \(inc)") }
        if let min = Int(context.minValue) { alterParts.append("MINVALUE \(min)") } else { alterParts.append("NO MINVALUE") }
        if let max = Int(context.maxValue) { alterParts.append("MAXVALUE \(max)") } else { alterParts.append("NO MAXVALUE") }
        if let start = Int(context.startWith) { alterParts.append("START WITH \(start)") }
        if let c = Int(context.cache), c != 1 { alterParts.append("CACHE \(c)") }
        alterParts.append(context.cycle ? "CYCLE" : "NO CYCLE")
        var sql = "ALTER SEQUENCE \(qualified)\n    " + alterParts.joined(separator: "\n    ") + ";"
        if !context.owner.isEmpty {
            sql += "\n\nALTER SEQUENCE \(qualified) OWNER TO \(quoteIdentifier(context.owner));"
        }
        if !context.description.isEmpty {
            let escaped = context.description.replacingOccurrences(of: "'", with: "''")
            sql += "\n\nCOMMENT ON SEQUENCE \(qualified) IS '\(escaped)';"
        }
        return sql
    }
}
